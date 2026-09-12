# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalcularFrete, "OpenRouteService JSON responses" do
  let(:http) { instance_double(Net::HTTP) }
  let(:params) { { origem: "São Paulo, SP", destino: "Santos, SP", peso: "10,5", volume: "1,25" } }
  let(:route_body) do
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "geometry" => { "type" => "LineString", "coordinates" => [[-46.63, -23.55], [-46.32, -23.96]] },
        "properties" => { "summary" => { "distance" => 75_572.6, "duration" => 4_500 } }
      }]
    }
  end
  let(:response) { Net::HTTPOK.new("1.1", "200", "OK") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTESERVICE_API_KEY").and_return("test-only-route-key")
    allow(Net::HTTP).to receive(:new).with("api.openrouteservice.org", 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    geocode_origin = Net::HTTPOK.new("1.1", "200", "OK")
    geocode_destination = Net::HTTPOK.new("1.1", "200", "OK")
    allow(geocode_origin).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-46.63, -23.55] } }] }.to_json)
    allow(geocode_destination).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-46.32, -23.96] } }] }.to_json)
    allow(http).to receive(:request).and_return(geocode_origin, geocode_destination, response)
    allow(response).to receive(:body).and_return(route_body.to_json)
  end

  it "uses the JSON route distance in kilometres, total and decimal cargo breakdown" do
    result = described_class.call(params)

    expect(result).to include(sucesso: true, distancia_km: 75.57, valor_total: BigDecimal("188.93"), duracao_minutos: 75.0)
    expect(result[:rota_geojson]["type"]).to eq("LineString")
    expect(result[:origem_coords]).to eq([-46.63, -23.55])
    expect(result[:destino_coords]).to eq([-46.32, -23.96])
    expect(result[:breakdown]).to include(peso: BigDecimal("10.5"), volume: BigDecimal("1.25"), subtotal_km: BigDecimal("188.93"))
    expect(http).to have_received(:request).with(satisfy { |request|
      request.path == "/v2/directions/driving-car/geojson" && request["Authorization"] == "test-only-route-key"
    })
  end

  context "when the API returns no routes" do
    let(:route_body) { { "type" => "FeatureCollection", "features" => [] } }

    it "reports an invalid route response without inventing a distance or fare" do
      expect(described_class.call(params)).to include(sucesso: false, mensagem: /resposta inválida/)
    end
  end

  context "when the API rejects the request" do
    let(:response) { Net::HTTPForbidden.new("1.1", "403", "Forbidden") }

    it "reports rejected authentication safely" do
      expect(described_class.call(params)).to include(sucesso: false, mensagem: /recusou a autenticação/)
    end
  end

  context "when the directions API finds no route between the geocoded points" do
    let(:response) { Net::HTTPNotFound.new("1.1", "404", "Not Found") }

    it "reports a route-not-found error distinct from a generic outage" do
      resultado = described_class.call(params)

      expect(resultado).to include(sucesso: false, mensagem: /Não foi possível encontrar uma rota/)
      expect(resultado[:mensagem]).not_to match(/indisponível/)
    end
  end

  context "when pricing fails after a successful route calculation" do
    it "reports an internal error instead of blaming the route service" do
      allow(FreightPricingService).to receive(:call).and_raise(StandardError, "boom")

      resultado = described_class.call(params)

      expect(resultado).to include(sucesso: false, mensagem: "Erro interno ao simular o frete")
    end
  end
end

RSpec.describe CalcularFrete, "resolução de CEP brasileiro antes da geocodificação" do
  let(:http) { instance_double(Net::HTTP) }
  let(:params) { { origem: "18086-270", destino: "18090-300", peso: "66", volume: "6" } }
  let(:viacep_origem) do
    Net::HTTPOK.new("1.1", "200", "OK").tap do |res|
      allow(res).to receive(:body).and_return({
        logradouro: "Rua Luiz Silveira", bairro: "Jardim Ibiti do Paço", localidade: "Sorocaba", uf: "SP"
      }.to_json)
    end
  end
  let(:viacep_destino) do
    Net::HTTPOK.new("1.1", "200", "OK").tap do |res|
      allow(res).to receive(:body).and_return({
        logradouro: "Rua Antônio D'Angelis", bairro: "Vila Progresso", localidade: "Sorocaba", uf: "SP"
      }.to_json)
    end
  end
  let(:geocode_origin) do
    Net::HTTPOK.new("1.1", "200", "OK").tap do |res|
      allow(res).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-47.4452, -23.4654] } }] }.to_json)
    end
  end
  let(:geocode_destination) do
    Net::HTTPOK.new("1.1", "200", "OK").tap do |res|
      allow(res).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-47.4447, -23.4822] } }] }.to_json)
    end
  end
  let(:route_body) do
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "geometry" => { "type" => "LineString", "coordinates" => [[-47.4452, -23.4654], [-47.4447, -23.4822]] },
        "properties" => { "summary" => { "distance" => 3374.3, "duration" => 392.9 } }
      }]
    }
  end
  let(:route_response) { Net::HTTPOK.new("1.1", "200", "OK").tap { |res| allow(res).to receive(:body).and_return(route_body.to_json) } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTESERVICE_API_KEY").and_return("test-only-route-key")

    viacep_http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with("viacep.com.br", 443).and_return(viacep_http)
    allow(viacep_http).to receive(:use_ssl=).with(true)
    allow(viacep_http).to receive(:open_timeout=)
    allow(viacep_http).to receive(:read_timeout=)
    allow(viacep_http).to receive(:request).and_return(viacep_origem, viacep_destino)

    allow(Net::HTTP).to receive(:new).with("api.openrouteservice.org", 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(geocode_origin, geocode_destination, route_response)
  end

  it "enriches a bare CEP with the ViaCEP address before geocoding, instead of sending the raw digits" do
    resultado = described_class.call(params)

    expect(resultado).to include(sucesso: true, distancia_km: 3.37)
    expect(http).to have_received(:request).with(satisfy { |request|
      request.path.include?("Rua+Luiz+Silveira") && request.path.include?("boundary.country=BR")
    }).once
    expect(http).to have_received(:request).with(satisfy { |request|
      request.path.include?("Rua+Ant%C3%B4nio") && request.path.include?("boundary.country=BR")
    }).once
  end
end
