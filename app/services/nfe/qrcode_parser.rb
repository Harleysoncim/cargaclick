# frozen_string_literal: true

require "uri"

module Nfe
  class QrcodeParser
    Result = Data.define(:success?, :access_key, :url, :error)
    ACCESS_KEY = /(?<!\d)(\d{44})(?!\d)/
    OFFICIAL_HOST = /\A(?:[a-z0-9-]+\.)*(?:sefaz|fazenda|nfe|nfce)[a-z0-9-]*\.[a-z0-9.-]*gov\.br\z/i

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s.strip
    end

    def call
      return failure("Informe a chave ou o endereço da nota fiscal") if @text.blank?
      return success(access_key: @text) if @text.match?(/\A\d{44}\z/)

      uri = URI.parse(@text)
      return failure("O endereço da nota deve usar HTTPS") unless uri.is_a?(URI::HTTPS)
      return failure("Domínio de consulta fiscal não permitido") unless allowed_host?(uri.host)

      success(access_key: extract_key(uri), url: uri.to_s)
    rescue URI::InvalidURIError
      failure("Chave ou endereço da nota fiscal inválido")
    end

    private

    def allowed_host?(host)
      configured = ENV.fetch("NFE_QRCODE_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:blank?)
      configured.include?(host.to_s.downcase) || host.to_s.match?(OFFICIAL_HOST)
    end

    def extract_key(uri)
      URI.decode_www_form(uri.query.to_s).each do |key, value|
        candidate = [key, value].join("=").match(ACCESS_KEY)&.[](1)
        return candidate if candidate
      end
      uri.path.match(ACCESS_KEY)&.[](1)
    rescue ArgumentError
      nil
    end

    def success(access_key:, url: nil)
      Result.new(success?: true, access_key:, url:, error: nil)
    end

    def failure(error)
      Result.new(success?: false, access_key: nil, url: nil, error:)
    end
  end
end
