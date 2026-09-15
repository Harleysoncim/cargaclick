class WebhookValidator
  # NOTE: Signature validation for MercadoPago and EFI is OUT OF SCOPE.
  # The integrations are currently incomplete stubs that don't provide
  # real webhook payloads or signature schemes.
  #
  # FUTURE WORK: When integrations become production-ready, implement
  # signature validation per official provider documentation:
  # - MercadoPago: https://www.mercadopago.com.ar/developers/es/docs/checkout-api/webhooks
  # - EFI: https://api.efipay.com.br/public/api/v1/notification/
  #
  # For now, we accept all webhooks but protect via idempotency
  # (WebhookIdempotencyRecord) and amount validation against Cotacao.

  attr_reader :provider, :payload

  def initialize(provider:, payload:, signature: nil)
    @provider = provider
    @payload = payload
    # signature parameter kept for API compatibility, but not used
  end

  def valid?
    # Currently we only validate that payload is present.
    # Signature validation will be added when provider integrations are complete.
    payload.present? && payload.is_a?(Hash)
  end
end
