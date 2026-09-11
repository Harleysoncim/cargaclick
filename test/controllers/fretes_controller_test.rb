require "test_helper"
require "minitest/mock"

class FretesControllerTest < ActionDispatch::IntegrationTest
  test "simulation form exposes editable decimal fields" do
    get simular_frete_path

    assert_response :success
    assert_select "input#peso[type=text][required][inputmode=decimal][pattern]"
    assert_select "input#volume[type=text][required][inputmode=decimal][pattern]"
    assert_select "input#peso:not([disabled]):not([readonly])"
    assert_select "input#volume:not([disabled]):not([readonly])"
    assert_select "label[for=peso]", /Peso \(kg\)/
    assert_select "label[for=volume]", /Volume \(m³\)/
  end

  test "simulation validates decimal input and preserves route data" do
    CalcularFrete.stub(:call, {
      sucesso: true,
      origem: "São Paulo",
      destino: "Santos",
      peso: BigDecimal("10.5"),
      volume: BigDecimal("1.25"),
      valor_total: BigDecimal("250.00")
    }) do
      post simular_frete_post_path, params: {
        origem: "São Paulo", destino: "Santos", peso: "10,5", volume: "1,25"
      }
    end

    assert_response :success
    assert_select "body", /São Paulo/
    assert_select "body", /Santos/
    assert_select "[data-testid=simulation-breakdown]", /10,5/
    assert_select "[data-testid=simulation-breakdown]", /1,25/
    assert_select "body", /250,00/
  end

  test "successful simulation renders the real route map payload" do
    CalcularFrete.stub(:call, {
      sucesso: true,
      origem: "São Paulo",
      destino: "Santos",
      peso: BigDecimal("10.5"),
      volume: BigDecimal("1.25"),
      distancia_km: 75.57,
      duracao_minutos: 75.0,
      valor_total: BigDecimal("188.93"),
      rota_geojson: { "type" => "LineString", "coordinates" => [[-46.63, -23.55], [-46.32, -23.96]] },
      origem_coords: [-46.63, -23.55],
      destino_coords: [-46.32, -23.96],
      breakdown: { peso: BigDecimal("10.5"), volume: BigDecimal("1.25"), subtotal_km: BigDecimal("188.93") }
    }) do
      post simular_frete_post_path, params: { origem: "São Paulo", destino: "Santos", peso: "10.5", volume: "1.25" }
    end

    assert_response :success
    assert_select "[data-route-map-modal][role=dialog]"
    assert_select "[data-route-map-canvas]"
    assert_select "[data-route-map-close]"
    assert_select "[data-route-map-data]", /LineString/
    assert_select "body", /75,57/
    assert_select "body", /75,0 min/
    assert_select "body", /R\$ 188,93/
  end
end
