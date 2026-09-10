# frozen_string_literal: true
return unless defined?(Devise)

Devise.setup do |config|
  # 1) tenta ENV (recomendado na Render)
  key = ENV["DEVISE_SECRET_KEY"]

  # 2) só tenta credentials se existir e for válido
  if key.blank?
    begin
      key = Rails.application.credentials.dig(:devise, :secret_key)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::EncryptedFile::MissingContentError, ArgumentError
      key = nil
    end
  end

  # 3) fallback para secret_key_base se ainda estiver vazio
  key ||= Rails.application.secret_key_base

  config.secret_key = key if key.present?
end
