module Webhooks
  class PixController < ApplicationController
    skip_before_action :verify_authenticity_token

    def mercado_pago
      payload = JSON.parse(request.raw_post)
      signature = request.headers["X-Signature"]

      validator = WebhookValidator.new(
        provider: :mercado_pago,
        payload: request.raw_post,
        signature: signature
      )

      unless validator.valid?
        Rails.logger.warn("[Webhooks::PixController] Invalid MercadoPago signature")
        return head :unauthorized
      end

      payment_id = payload.dig("data", "id")
      return head :ok unless payment_id

      result = MercadoPagoPixService.fetch(payment_id)
      return head :ok unless result[:approved]

      frete = Frete.find_by(external_payment_id: payment_id)
      return head :ok unless frete

      update_result = SafePaymentUpdater.call(
        frete: frete,
        external_id: payment_id,
        amount: result[:amount],
        provider: "mercado_pago"
      )

      return head :ok if update_result[:success]

      Rails.logger.error("[Webhooks::PixController] Payment update failed: #{update_result[:error]}")
      head :unprocessable_entity
    end
  end
end
