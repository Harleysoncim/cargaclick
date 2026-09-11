# app/services/calcular_frete.rb
# Serviço de simulação de frete – produção ready

require "net/http"
require "json"
require "uri"
require "bigdecimal"

class CalcularFrete
  class ServicoDeRotasIndisponivel < StandardError
    attr_reader :reason

    def initialize(reason = :unknown)
      @reason = reason
      super()
    end
  end
  ORS_TIMEOUT_SECONDS = 10

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
    @volume       = normalizar_numero(params[:volume])
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
      peso: @peso,
      volume: @volume,
      distancia_km: distancia_km.round(2),
      tempo_estimado: estimar_tempo(distancia_km),
      valor_total: breakdown[:valor_final],
      breakdown: breakdown
    )
  rescue ServicoDeRotasIndisponivel => e
    resposta_erro(mensagem_rota_indisponivel(e.reason))
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
    texto = valor.to_s.strip
    return nil if texto.empty?
    return nil unless texto.match?(/\A(?:\d+(?:[\.,]\d+)?|[\.,]\d+)\z/)

    BigDecimal(texto.tr(",", "."))
  rescue ArgumentError
    nil
  end

  # ==================================================
  # VALIDAÇÃO
  # ==================================================
  def validar_parametros
    erros = []
    erros << "Origem inválida"  if @origem.blank?
    erros << "Destino inválido" if @destino.blank?
    erros << "Peso deve ser um número positivo (use ponto ou vírgula para decimais)" unless @peso&.positive?
    erros << "Volume deve ser um número positivo (use ponto ou vírgula para decimais)" unless @volume&.positive?
    erros
  end

  # ==================================================
  # DISTÂNCIA (OPENROUTESERVICE; sem valor fictício)
  # ==================================================
  def calcular_distancia
    if ENV["OPENROUTESERVICE_API_KEY"].blank?
      raise ServicoDeRotasIndisponivel, :missing_key
    end

    coords_origem  = geocodificar(@origem)
    coords_destino = geocodificar(@destino)

    raise ServicoDeRotasIndisponivel, :invalid_coordinates if coords_origem.nil? || coords_destino.nil?

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
      text: endereco,
      size: 1
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = ORS_TIMEOUT_SECONDS
    http.read_timeout = ORS_TIMEOUT_SECONDS
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = ENV["OPENROUTESERVICE_API_KEY"]
    res = http.request(req)
    return nil unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    coordinates = body.dig("features", 0, "geometry", "coordinates")
    coordinates if coordinates.is_a?(Array) && coordinates.length == 2 && coordinates.all? { |value| value.is_a?(Numeric) }
  end

  def distancia_ors(origem, destino)
    uri = URI("https://api.openrouteservice.org/v2/directions/driving-car")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = ORS_TIMEOUT_SECONDS
    http.read_timeout = ORS_TIMEOUT_SECONDS

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = ENV["OPENROUTESERVICE_API_KEY"]
    req["Content-Type"]  = "application/json"

    req.body = { coordinates: [origem, destino] }.to_json

    res = http.request(req)
    unless res.is_a?(Net::HTTPSuccess)
      reason = case res.code.to_i
               when 401, 403 then :unauthorized
               when 429 then :rate_limited
               when 500..599 then :provider_error
               else :provider_error
               end
      Rails.logger.warn("[CalcularFrete][ORS] status=#{res.code} reason=#{reason}")
      raise ServicoDeRotasIndisponivel, reason
    end

    body = JSON.parse(res.body)
    metros = body.dig("routes", 0, "summary", "distance")
    raise ServicoDeRotasIndisponivel, :invalid_response unless metros.is_a?(Numeric) && metros.positive?

    metros.to_f / 1000.0
  rescue JSON::ParserError
    raise ServicoDeRotasIndisponivel, :invalid_response
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise ServicoDeRotasIndisponivel, :timeout
  rescue SocketError, Errno::ECONNREFUSED
    raise ServicoDeRotasIndisponivel, :network
  end

  def mensagem_rota_indisponivel(reason)
    {
      missing_key: "O serviço de rotas não está configurado. Tente novamente mais tarde.",
      unauthorized: "O serviço de rotas recusou a autenticação. Tente novamente mais tarde.",
      rate_limited: "O serviço de rotas atingiu o limite temporário. Tente novamente mais tarde.",
      timeout: "O serviço de rotas demorou para responder. Tente novamente mais tarde.",
      invalid_coordinates: "Não foi possível localizar origem ou destino.",
      invalid_response: "O serviço de rotas retornou uma resposta inválida. Tente novamente mais tarde.",
      network: "Não foi possível conectar ao serviço de rotas. Tente novamente mais tarde.",
      provider_error: "O serviço de rotas está indisponível. Tente novamente mais tarde.",
      unknown: "Serviço de rotas indisponível. Tente novamente mais tarde."
    }.fetch(reason, "Serviço de rotas indisponível. Tente novamente mais tarde.")
  end

  # ==================================================
  # CÁLCULO / BREAKDOWN (AUDITÁVEL)
  # ==================================================
  def calcular_breakdown(distancia_km)
    valor_por_km = BigDecimal(distancia_km.to_s) * BigDecimal(PRECO_BASE_KM.to_s)
    valor_base   = [valor_por_km, TAXA_MINIMA].max

    {
      preco_base_km: BigDecimal(PRECO_BASE_KM.to_s),
      distancia_km: distancia_km.round(2),
      subtotal_km: valor_por_km.round(2),
      taxa_minima: TAXA_MINIMA,
      peso: @peso,
      volume: @volume,
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
