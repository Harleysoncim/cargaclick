require "test_helper"

class FretesControllerTest < ActionDispatch::IntegrationTest
  test "simulation form exposes editable decimal fields" do
    get simular_frete_path

    assert_response :success
    assert_select "input#peso[type=text][required][inputmode=decimal][pattern]"
    assert_select "input#volume[type=text][required][inputmode=decimal][pattern]"
    assert_select "input#peso:not([disabled]):not([readonly])"
    assert_select "input#volume:not([disabled]):not([readonly])"
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
  end
end
