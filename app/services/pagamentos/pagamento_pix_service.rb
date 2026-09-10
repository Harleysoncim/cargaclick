# frozen_string_literal: true

module Pagamentos
  class PagamentoPixService
    class Error < StandardError; end

    def initialize(valor:, descricao:, email:, nome:, cpf:, external_reference:)
      @valor              = valor.to_f
      @descricao          = descricao
      @email              = email
      @nome               = nome
      @cpf                = cpf
      @external_reference = external_reference
    end

    def call
      validate!

      token = ENV["MP_ACCESS_TOKEN"].presence || ENV["MERCADO_PAGO_ACCESS_TOKEN"].presence
      raise Error, "Mercado Pago indisponível: MP_ACCESS_TOKEN ausente" if token.blank?

      sdk = MercadoPago::SDK.new(token)
      payment = sdk.payment

      response = payment.create(payload)

      unless response["status"] == "pending"
        raise Error, "Falha ao criar PIX: #{response}"
      end

      normalize_response(response)
    rescue StandardError => e
      Rails.logger.error("[PIX] Erro: #{e.message}")
      raise
    end

    private

    def validate!
      raise Error, "Valor inválido" if @valor <= 0
      raise Error, "CPF obrigatório" if @cpf.blank?
      raise Error, "Email obrigatório" if @email.blank?
    end

    def payload
      {
        transaction_amount: @valor,
        description: @descricao,
        payment_method_id: "pix",
        payer: {
          email: @email,
          first_name: @nome,
          identification: {
            type: "CPF",
            number: @cpf
          }
        },
        external_reference: @external_reference,
        notification_url: webhook_url
      }
    end

    def webhook_url
      ENV.fetch("MERCADO_PAGO_WEBHOOK_URL", nil)
    end

    def normalize_response(response)
      {
        pagamento_id: response["id"],
        status: response["status"],
        qr_code: response.dig("point_of_interaction", "transaction_data", "qr_code"),
        qr_code_base64: response.dig("point_of_interaction", "transaction_data", "qr_code_base64"),
        valor: response["transaction_amount"]
      }
    end
  end
end
