# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalcularFrete do
  subject(:resultado) { described_class.call(parametros) }

  let(:parametros) do
    {
      origem: "São Paulo",
      destino: "Santos",
      peso: peso,
      volume: volume
    }
  end
  let(:peso) { "10" }
  let(:volume) { "1" }

  before do
    allow_any_instance_of(described_class).to receive(:calcular_distancia).and_return(100.0)
  end

  it "accepts integer values and preserves origin and destination" do
    expect(resultado).to include(sucesso: true, origem: "São Paulo", destino: "Santos")
    expect(resultado).to include(peso: BigDecimal("10"), volume: BigDecimal("1"))
  end

  it "accepts decimal values with a point" do
    allow_any_instance_of(described_class).to receive(:calcular_distancia).and_return(100.0)
    resultado = described_class.call(parametros.merge(peso: "10.5", volume: "1.25"))

    expect(resultado).to include(sucesso: true, peso: BigDecimal("10.5"), volume: BigDecimal("1.25"))
  end

  it "accepts decimal values with a comma" do
    resultado = described_class.call(parametros.merge(peso: "10,5", volume: "1,25"))

    expect(resultado).to include(sucesso: true, peso: BigDecimal("10.5"), volume: BigDecimal("1.25"))
  end

  it "uses peso and volume in the calculation breakdown" do
    expect(resultado[:breakdown]).to include(peso: BigDecimal("10"), volume: BigDecimal("1"))
  end

  [nil, "", "0", "-1", "abc", "NaN", "Infinity", "1,2.3"].each do |invalid|
    it "rejects invalid numeric input #{invalid.inspect}" do
      result = described_class.call(parametros.merge(peso: invalid))

      expect(result).to include(sucesso: false)
      expect(result[:detalhes].join(" ")).to include("Peso")
    end
  end

  [nil, "", "0", "-1", "abc", "NaN", "Infinity", "1,2.3"].each do |invalid|
    it "rejects invalid volume input #{invalid.inspect}" do
      result = described_class.call(parametros.merge(volume: invalid))

      expect(result).to include(sucesso: false)
      expect(result[:detalhes].join(" ")).to include("Volume")
    end
  end
end