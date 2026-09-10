# frozen_string_literal: true

require "test_helper"

class OptionalCredentialsTest < ActiveSupport::TestCase
  test "Devise falls back to secret_key_base without credentials" do
    assert_equal Rails.application.secret_key_base, Devise.secret_key
  end

  test "Mercado Pago is disabled without an access token" do
    assert_nil Rails.configuration.x.mercadopago_sdk
  end

  test "OpenAI provider remains callable without credentials" do
    provider = GptService::PROVIDERS.fetch("openai")
    original_key = ENV.delete("OPENAI_API_KEY")

    assert_nothing_raised do
      provider.fetch(:key).call
    end
  ensure
    ENV["OPENAI_API_KEY"] = original_key if original_key
  end
end