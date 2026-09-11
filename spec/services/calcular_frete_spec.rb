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

  it "uses the OpenRouteService route distance response" do
    service = described_class.new(parametros)
    response = instance_double(Net::HTTPResponse, is_a?: true, body: {
      "routes" => [{
        "summary" => { "distance" => 12_500, "duration" => 3_600 },
        "geometry" => { "type" => "LineString", "coordinates" => [[-46.63, -23.55], [-46.32, -23.96]] }
      }]
    }.to_json)

    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:new).and_return(http)

    route = service.send(:distancia_ors, [ -46.63, -23.55 ], [ -46.32, -23.96 ])

    expect(route).to include(distancia_km: 12.5, duracao_minutos: 60.0)
    expect(route[:geojson]["type"]).to eq("LineString")
  end

  it "returns a safe message when the route service has no key" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTESERVICE_API_KEY").and_return(nil)

    result = described_class.call(parametros)

    expect(result).to include(sucesso: false)
    expect(result[:mensagem]).to include("não está configurado")
  end

  it "returns a safe message when the route service times out" do
    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)
    allow(Net::HTTP).to receive(:new).and_return(http)

    expect {
      described_class.new(parametros).send(:distancia_ors, [ -46.63, -23.55 ], [ -46.32, -23.96 ])
    }.to raise_error(CalcularFrete::ServicoDeRotasIndisponivel) { |error|
      expect(error.reason).to eq(:timeout)
    }
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