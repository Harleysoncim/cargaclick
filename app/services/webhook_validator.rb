class WebhookValidator
  attr_reader :provider, :payload, :signature

  def initialize(provider:, payload:, signature: nil)
    @provider = provider
    @payload = payload
    @signature = signature
  end

  def valid?
    validate_signature && validate_payload
  end

  private

  def validate_signature
    case provider
    when :pix_efi
      validate_efi_signature
    when :mercado_pago
      validate_mercado_pago_signature
    else
      false
    end
  end

  def validate_efi_signature
    return false if signature.blank?

    api_key = ENV.fetch("EFI_PIX_API_KEY", "")
    return false if api_key.blank?

    expected_signature = compute_efi_signature(payload, api_key)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  rescue StandardError => e
    Rails.logger.warn("[WebhookValidator] EFI signature validation failed: #{e.message}")
    false
  end

  def compute_efi_signature(body, api_key)
    require "openssl"
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      api_key,
      body
    )
  end

  def validate_mercado_pago_signature
    return false if signature.blank?

    webhook_secret = ENV.fetch("MERCADO_PAGO_WEBHOOK_SECRET", "")
    return false if webhook_secret.blank?

    expected_signature = compute_mercado_pago_signature(payload, webhook_secret)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  rescue StandardError => e
    Rails.logger.warn("[WebhookValidator] MercadoPago signature validation failed: #{e.message}")
    false
  end

  def compute_mercado_pago_signature(body, secret)
    require "openssl"
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      secret,
      body
    )
  end

  def validate_payload
    payload.present? && payload.is_a?(Hash)
  end
end
