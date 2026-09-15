module Webhooks
  module Efi
    class PixController < ApplicationController
      skip_before_action :verify_authenticity_token

      def callback
        signature = request.headers["X-Signature"]
        payload = request.raw_post

        validator = WebhookValidator.new(
          provider: :pix_efi,
          payload: payload,
          signature: signature
        )

        unless validator.valid?
          Rails.logger.warn("[Webhooks::Efi::PixController] Invalid EFI signature")
          return head :unauthorized
        end

        data = JSON.parse(payload)
        txid = data.dig("txid")
        amount = data.dig("valor")&.to_d

        return head :bad_request if txid.blank? || amount.nil?

        frete = Frete.find_by(external_reference: txid)
        return head :ok unless frete

        update_result = SafePaymentUpdater.call(
          frete: frete,
          external_id: txid,
          amount: amount,
          provider: "efi_pix"
        )

        return head :ok if update_result[:success]

        Rails.logger.error("[Webhooks::Efi::PixController] Payment update failed: #{update_result[:error]}")
        head :unprocessable_entity
      end
    end
  end
end
