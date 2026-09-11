# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalcularFrete, "OpenRouteService JSON responses" do
  let(:http) { instance_double(Net::HTTP) }
  let(:params) { { origem: "São Paulo, SP", destino: "Santos, SP", peso: "10,5", volume: "1,25" } }
  let(:route_body) do
        geocode_origin = Net::HTTPOK.new("1.1", "200", "OK")
        geocode_destination = Net::HTTPOK.new("1.1", "200", "OK")
        allow(geocode_origin).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-46.63, -23.55] } }] }.to_json)
        allow(geocode_destination).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-46.32, -23.96] } }] }.to_json)
        allow(http).to receive(:request).and_return(geocode_origin, geocode_destination, response)
  end
  let(:response) { Net::HTTPOK.new("1.1", "200", "OK") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTESERVICE_API_KEY").and_return("test-only-route-key")
    allow(Net::HTTP).to receive(:new).with("api.openrouteservice.org", 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
        expect(result[:destino_coords]).to eq([-46.32, -23.96])
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(
      Net::HTTPOK.new("1.1", "200", "OK").tap do |geocode|
        allow(geocode).to receive(:body).and_return({ features: [{ geometry: { coordinates: [-46.63, -23.55] } }] }.to_json)
      end,
      response
    )
    allow(response).to receive(:body).and_return(route_body.to_json)
  end

  it "uses the JSON route distance in kilometres, total and decimal cargo breakdown" do
    result = described_class.call(params)

    expect(result).to include(sucesso: true, distancia_km: 75.57, valor_total: BigDecimal("188.93"), duracao_minutos: 75.0)
    expect(result[:rota_geojson]["type"]).to eq("LineString")
    expect(result[:origem_coords]).to eq([-46.63, -23.55])
    expect(result[:destino_coords]).to eq([-46.63, -23.55])
    expect(result[:breakdown]).to include(peso: BigDecimal("10.5"), volume: BigDecimal("1.25"), subtotal_km: BigDecimal("188.93"))
    expect(http).to have_received(:request) do |request|
      expect(request.path).to eq("/v2/directions/driving-car")
      expect(request["Authorization"]).to eq("test-only-route-key")
    end
  end

  context "when the API returns no routes" do
    let(:route_body) { { "routes" => [] } }

    it "reports unavailable routes without inventing a distance or fare" do
      expect(described_class.call(params)).to include(sucesso: false, mensagem: /Serviço de rotas indisponível/)
    end
  end

  context "when the API rejects the request" do
    let(:response) { Net::HTTPForbidden.new("1.1", "403", "Forbidden") }

    it "reports unavailable routes" do
      expect(described_class.call(params)).to include(sucesso: false, mensagem: /Serviço de rotas indisponível/)
    end
  end
end
