# frozen_string_literal: true

require "rails_helper"

RSpec.describe FreightPricingService do
  let(:fallback) do
    {
      valor_final: BigDecimal("188.93"),
      subtotal_km: BigDecimal("188.93"),
      taxa_minima: BigDecimal("30")
    }
  end
  let(:route) { { distancia_km: 75.57, duracao_minutos: 75.0 } }
  let(:params) { { peso: BigDecimal("10.5"), volume: BigDecimal("1.25"), tipo_carga: "geral" } }

  around do |example|
    previous = ENV["NATIONAL_FREIGHT_PRICING_ENABLED"]
    ENV.delete("NATIONAL_FREIGHT_PRICING_ENABLED")
    example.run
  ensure
    ENV["NATIONAL_FREIGHT_PRICING_ENABLED"] = previous
  end

  it "keeps the current calculation as an explicitly labeled fallback" do
    result = described_class.call(params:, route:, fallback:)

    expect(result).to include(status: "fallback", label: described_class::FALLBACK_LABEL)
    expect(result[:suggested_value]).to eq(BigDecimal("188.93"))
    expect(result[:source]).not_to match(/média nacional/i)
    expect(result[:breakdown]).to include(
      distancia_km: 75.57,
      duracao_minutos: 75.0,
      peso_real: BigDecimal("10.5"),
      peso_cubado: nil,
      peso_tarifavel: nil,
      pedagio: nil,
      retorno: nil,
      urgencia: nil
    )
  end

  it "does not activate an empty commercial table" do
    ENV["NATIONAL_FREIGHT_PRICING_ENABLED"] = "true"

    result = described_class.call(params:, route:, fallback:)

    expect(result).to include(status: "insufficient_sample", label: "Amostra insuficiente")
    expect(result[:suggested_value]).to be_nil
  end

  it "has no commercial coefficients in the phase one configuration" do
    config = YAML.safe_load(File.read(Rails.root.join("config/freight_rates.yml")))

    expect(config.fetch("vehicles")).to be_empty
    expect(config.fetch("distance_bands")).to be_empty
    expect(config.fetch("parameters").fetch("operational_floor")).to be_nil
    expect(config.fetch("sample_size")).to eq(0)
  end
end