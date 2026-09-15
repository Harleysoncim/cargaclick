module Webhooks
  module Efi
    class PixController < ApplicationController
      skip_before_action :verify_authenticity_token

      def callback
        data = JSON.parse(request.raw_post)
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
      rescue JSON::ParserError => e
        Rails.logger.warn("[Webhooks::Efi::PixController] Invalid JSON: #{e.message}")
        head :bad_request
      rescue StandardError => e
        Rails.logger.error("[Webhooks::Efi::PixController] Unexpected error: #{e.message}")
        head :internal_server_error
      end
    end
  end
end
