# app/services/calcular_frete.rb
# Serviço de simulação de frete – produção ready

require "net/http"
require "json"
require "uri"

class CalcularFrete
  class ServicoDeRotasIndisponivel < StandardError; end

  # ==================================================
  # CONSTANTES DE NEGÓCIO
  # ==================================================
  PRECO_BASE_KM = 2.50   # R$/km
  TAXA_MINIMA   = 30.00  # R$

  # ==================================================
  # INTERFACE PÚBLICA (CONTRATO ESTÁVEL)
  # ==================================================
  def self.call(params)
    new(params).call
  end

  # ==================================================
  # INICIALIZAÇÃO DEFENSIVA
  # ==================================================
  def initialize(params)
    params ||= {}

    @origem       = normalizar_texto(params[:origem])
    @destino      = normalizar_texto(params[:destino])
    @peso         = normalizar_numero(params[:peso])
    @tipo_veiculo = normalizar_texto(params[:tipo_veiculo]).presence || "carro"
    @tipo_carga   = normalizar_texto(params[:tipo_carga]).presence   || "Não informado"
  end

  # ==================================================
  # EXECUÇÃO PRINCIPAL
  # ==================================================
  def call
    erros = validar_parametros
    return resposta_erro("Parâmetros inválidos", erros) if erros.any?

    distancia_km = calcular_distancia
    breakdown    = calcular_breakdown(distancia_km)

    resposta_sucesso(
      origem: @origem,
      destino: @destino,
      tipo_veiculo: @tipo_veiculo.capitalize,
      tipo_carga: @tipo_carga,
      distancia_km: distancia_km.round(2),
      tempo_estimado: estimar_tempo(distancia_km),
      valor_total: breakdown[:valor_final],
      breakdown: breakdown
    )
  rescue ServicoDeRotasIndisponivel
    resposta_erro("Serviço de rotas indisponível. Tente novamente mais tarde.")
  rescue StandardError => e
    log_erro_fatal(e)
    resposta_erro("Erro interno ao simular o frete")
  end

  private

  # ==================================================
  # NORMALIZAÇÃO
  # ==================================================
  def normalizar_texto(valor)
    valor.to_s.strip
  end

  def normalizar_numero(valor)
    Float(valor)
  rescue
    0.0
  end

  # ==================================================
  # VALIDAÇÃO
  # ==================================================
  def validar_parametros
    erros = []
    erros << "Origem inválida"  if @origem.blank?
    erros << "Destino inválido" if @destino.blank?
    erros << "Peso inválido"    if @peso <= 0
    erros
  end

  # ==================================================
  # DISTÂNCIA (OPENROUTESERVICE; sem valor fictício)
  # ==================================================
  def calcular_distancia
    if ENV["OPENROUTESERVICE_API_KEY"].blank?
      raise ServicoDeRotasIndisponivel
    end

    coords_origem  = geocodificar(@origem)
    coords_destino = geocodificar(@destino)

    raise ServicoDeRotasIndisponivel if coords_origem.nil? || coords_destino.nil?

    distancia_ors(coords_origem, coords_destino)
  rescue ServicoDeRotasIndisponivel
    raise
  rescue StandardError => e
    Rails.logger.warn("[CalcularFrete][ORS] falha=#{e.class}")
    raise ServicoDeRotasIndisponivel
  end

  def geocodificar(endereco)
    uri = URI("https://api.openrouteservice.org/geocode/search")
    uri.query = URI.encode_www_form(
      api_key: ENV["OPENROUTESERVICE_API_KEY"],
      text: endereco,
      size: 1
    )

    res = Net::HTTP.get_response(uri)
    return nil unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    body.dig("features", 0, "geometry", "coordinates")
  end

  def distancia_ors(origem, destino)
    uri = URI("https://api.openrouteservice.org/v2/directions/driving-car")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = ENV["OPENROUTESERVICE_API_KEY"]
    req["Content-Type"]  = "application/json"

    req.body = { coordinates: [origem, destino] }.to_json

    res = http.request(req)
    raise ServicoDeRotasIndisponivel unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    metros = body.dig("features", 0, "properties", "segments", 0, "distance")
    raise ServicoDeRotasIndisponivel unless metros

    metros.to_f / 1000.0
  end

  # ==================================================
  # CÁLCULO / BREAKDOWN (AUDITÁVEL)
  # ==================================================
  def calcular_breakdown(distancia_km)
    valor_por_km = distancia_km * PRECO_BASE_KM
    valor_base   = [valor_por_km, TAXA_MINIMA].max

    {
      preco_base_km: PRECO_BASE_KM,
      distancia_km: distancia_km.round(2),
      subtotal_km: valor_por_km.round(2),
      taxa_minima: TAXA_MINIMA,
      ajuste_fidelidade: 0.0,
      comissao_plataforma: 0.0,
      valor_final: valor_base.round(2)
    }
  end

  def estimar_tempo(distancia_km)
    horas = (distancia_km / 60.0).round(1)
    "#{horas}h"
  end

  # ==================================================
  # RESPOSTAS PADRÃO
  # ==================================================
  def resposta_sucesso(payload = {})
    { sucesso: true, mensagem: "Simulação realizada com sucesso", **payload }
  end

  def resposta_erro(mensagem, detalhes = nil)
    { sucesso: false, mensagem: mensagem, detalhes: detalhes }
  end

  # ==================================================
  # LOG
  # ==================================================
  def log_erro_fatal(exception)
    Rails.logger.error(
      "[CalcularFrete][FATAL] #{exception.class}\n" \
      "#{exception.backtrace&.first(5)&.join("\n")}"
    )
  end
end
