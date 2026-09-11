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
end
