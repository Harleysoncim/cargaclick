# frozen_string_literal: true

require "rails_helper"

RSpec.describe Nfe::QrcodeParser do
  let(:key) { "1" * 44 }

  it "accepts an access key with 44 digits" do
    result = described_class.call(key)
    expect(result).to be_success
    expect(result.access_key).to eq(key)
  end

  it "rejects an invalid key" do
    expect(described_class.call("123")).not_to be_success
  end

  it "rejects a non-HTTPS URL" do
    expect(described_class.call("http://nfe.fazenda.gov.br/?p=#{key}").error).to match(/HTTPS/)
  end

  it "rejects an arbitrary domain" do
    expect(described_class.call("https://example.com/?p=#{key}").error).to match(/não permitido/)
  end

  it "extracts a key from an official HTTPS URL" do
    result = described_class.call("https://nfe.fazenda.gov.br/consulta?p=#{key}|2|1")
    expect(result).to be_success
    expect(result.access_key).to eq(key)
  end
end
