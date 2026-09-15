class WebhookIdempotencyRecord < ApplicationRecord
  validates :provider, presence: true
  validates :external_id, presence: true
  validates :webhook_hash, presence: true
  validates :external_id, uniqueness: { scope: :provider }
  validates :webhook_hash, uniqueness: true

  scope :processed, -> { where(processed: true) }
  scope :pending, -> { where(processed: false) }

  def mark_processed!
    update!(processed: true, processed_at: Time.current)
  end

  def processed?
    processed == true
  end
end
