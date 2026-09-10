# frozen_string_literal: true

require "mercadopago"

module MercadoPagoConfig
  def self.sdk
    token =
      ENV["MP_ACCESS_TOKEN"].presence ||
      begin
        Rails.application.credentials.dig(:mercadopago, :access_token)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage,
             ActiveSupport::EncryptedFile::MissingContentError,
             ArgumentError
        nil
      end

    if token.present?
      Rails.logger.info("[mercado_pago] SDK oficial inicializado com token válido")
      Mercadopago::SDK.new(token) # <-- nome certo da constante
    else
      Rails.logger.warn("[mercado_pago] MP_ACCESS_TOKEN ausente — SDK não inicializado")
      nil
    end
  end
end

Rails.configuration.x.mercadopago_sdk = MercadoPagoConfig.sdk



