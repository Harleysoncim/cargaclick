# frozen_string_literal: true

require "rails_helper"

RSpec.describe FreightPricingStatisticsService do
  let(:records) do
    [
      { "tipo_veiculo" => "truck", "tipo_carga" => "geral", "valor_aceito" => "100" },
      { "tipo_veiculo" => "truck", "tipo_carga" => "geral", "valor_aceito" => "200" },
      { "tipo_veiculo" => "truck", "tipo_carga" => "geral", "valor_aceito" => "300" },
      { "tipo_veiculo" => "van", "tipo_carga" => "geral", "valor_aceito" => "999" }
    ]
  end

  it "selects comparable records and calculates P25, median and P75" do
    result = described_class.call(scope: records, filters: { tipo_veiculo: "truck", tipo_carga: "geral" })

    expect(result.sample_size).to eq(3)
    expect(result.p25).to eq(BigDecimal("150"))
    expect(result.median).to eq(BigDecimal("200"))
    expect(result.p75).to eq(BigDecimal("250"))
    expect(result.criteria).to eq(tipo_veiculo: "truck", tipo_carga: "geral")
  end

  it "falls back to valor when valor_aceito is absent" do
    result = described_class.call(scope: [{ "valor" => "120" }])

    expect(result.sample_size).to eq(1)
    expect(result.median).to eq(BigDecimal("120"))
  end

  it "does not invent a minimum sample size" do
    result = described_class.call(scope: records)

    expect(result.sample_status).to eq("insufficient")
  end
end
