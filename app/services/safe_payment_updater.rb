class SafePaymentUpdater
  attr_reader :frete, :external_id, :amount, :provider

  def initialize(frete:, external_id:, amount:, provider:)
    @frete = frete
    @external_id = external_id
    @amount = amount
    @provider = provider
  end

  def call
    validate_prerequisites!
    idempotent_update
  end

  private

  def validate_prerequisites!
    raise ArgumentError, "frete not found" if frete.nil?
    raise ArgumentError, "invalid amount" unless amount.is_a?(Numeric) && amount.positive?
    raise ArgumentError, "external_id missing" if external_id.blank?
  end

  def idempotent_update
    webhook_record = find_or_create_webhook_idempotency_record

    return { success: true, idempotent: true } if webhook_record.processed?

    validate_payment_consistency!

    Frete.transaction do
      frete.with_lock do
        result = update_payment_status
        webhook_record.mark_processed! if result
        result
      end
    end
  rescue StandardError => e
    Rails.logger.error("[SafePaymentUpdater] Failed: #{e.message}")
    { success: false, error: e.message }
  end

  def find_or_create_webhook_idempotency_record
    hash = compute_webhook_hash
    WebhookIdempotencyRecord.find_or_create_by!(
      provider: provider,
      external_id: external_id,
      webhook_hash: hash
    )
  end

  def compute_webhook_hash
    require "digest"
    Digest::SHA256.hexdigest("#{provider}:#{external_id}:#{amount}")
  end

  def validate_payment_consistency!
    cotacao = frete.cotacao
    raise ArgumentError, "Frete not linked to quotation" if cotacao.nil?
    raise ArgumentError, "Quotation has no value" if cotacao.valor.blank?
    raise ArgumentError, "Quotation has expired" if cotacao.expired?

    expected_amount = cotacao.valor.to_d

    unless amounts_match?(amount.to_d, expected_amount)
      raise ArgumentError,
            "Amount mismatch: expected #{expected_amount}, got #{amount}"
    end

    if frete.status_pagamento == "pago"
      raise ArgumentError, "Frete already paid"
    end
  end

  def amounts_match?(received, expected)
    (received - expected).abs < BigDecimal("0.01")
  end

  def update_payment_status
    frete.update!(
      status_pagamento: :pago,
      external_payment_id: external_id,
      updated_at: Time.current
    )
    { success: true, idempotent: false }
  end
end
