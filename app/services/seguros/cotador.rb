# frozen_string_literal: true

require "timeout"

module Seguros
  class Cotador
    Result = Data.define(:success?, :status, :error)

    def initialize(frete, provider: Providers::Disabled.new)
      @frete = frete
      @provider = provider
    end

    def call
      return failure("Informe um valor de carga maior que zero") unless @frete.seguro_valor_carga.to_d.positive?
      return failure("Autorize o envio dos dados para análise") unless @frete.seguro_consentimento?
      missing = payload.slice(:mercadoria, :origem, :destino, :peso, :tipo_veiculo).select { |_key, value| value.blank? }.keys
      return failure("Complete os dados da carga: #{missing.join(', ')}") if missing.any?

      response = @provider.quote(payload, timeout: 8)
      status = response.fetch(:status, "aguardando_cotacao")
      status = "aguardando_cotacao" unless Frete::SEGURO_STATUSES.include?(status)
      @frete.update!(seguro_carga: true, seguro_status: status)
      Result.new(success?: true, status:, error: nil)
    rescue Providers::Base::Unavailable, Timeout::Error
      @frete.update_column(:seguro_status, "erro")
      failure("Serviço de cotação indisponível. Tente novamente mais tarde.")
    end

    private

    def payload
      {
        frete_id: @frete.id,
        valor_carga: @frete.seguro_valor_carga,
        mercadoria: @frete.seguro_descricao_mercadoria,
        origem: @frete.seguro_origem.presence || @frete.origem,
        destino: @frete.seguro_destino.presence || @frete.destino,
        peso: @frete.seguro_peso.presence || @frete.peso.presence || @frete.peso_aproximado,
        tipo_veiculo: @frete.seguro_tipo_veiculo.presence || @frete.transportador&.tipo_veiculo,
        emitente_documento: @frete.nfe_emitente_documento,
        riscos: {
          perigosa: @frete.seguro_carga_perigosa,
          perecivel: @frete.seguro_carga_perecivel,
          alto_valor: @frete.seguro_carga_alto_valor
        }
      }
    end

    def failure(message)
      Result.new(success?: false, status: @frete.seguro_status, error: message)
    end
  end
end
