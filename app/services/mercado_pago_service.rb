# frozen_string_literal: true

class MercadoPagoService
  def initialize
    @sdk = Rails.configuration.x.mercadopago_sdk
  end

  # Cria uma preferência de pagamento no MP
  def criar_preferencia(pagamento)
    return nil unless @sdk

    preference_data = {
      items: [
        {
          title: "Frete ##{pagamento.frete_id}",
          quantity: 1,
          currency_id: "BRL",
          unit_price: pagamento.valor_total.to_f
        }
      ],
      payer: {
        email: pagamento.cliente&.email || "anonimo@cargaclick.com"
      },
      back_urls: {
        success: callback_url("success"),
        failure: callback_url("failure"),
        pending: callback_url("pending")
      },
      auto_return: "approved"
    }

    result = @sdk.preference.create(preference_data)

    if result["status"] == "201"
      # URL do botão de pagamento
      result["response"]["init_point"]
    else
      Rails.logger.error("[mercado_pago] Erro ao criar preferência: #{result.inspect}")
      nil
    end
  end

  # Consulta status de pagamento
  def consultar_pagamento(mp_payment_id)
    return nil unless @sdk

    result = @sdk.payment.get(mp_payment_id)
    result["response"] if result["status"] == "200"
  end

  private

  def callback_url(status)
    Rails.application.routes.url_helpers.callback_pagamentos_url(
      status: status,
      host: Rails.application.routes.default_url_options[:host]
    )
  end
end
