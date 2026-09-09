require "test_helper"

class CotacaosControllerTest < ActionDispatch::IntegrationTest
  include RetiredRoutes

  setup do
    frete = create_test_frete
    @record = Cotacao.create!(frete: frete, transportador: frete.transportador, valor: 100)
  end

  test "retired index is not exposed" do
    assert_retired_route :get, "/cotacaos", record: @record
  end

  test "retired new form is not exposed" do
    assert_retired_route :get, "/cotacaos/new", record: @record
  end

  test "retired create cannot insert a quote" do
    assert_retired_route :post, "/cotacaos", params: { cotacao: { valor: 200 } }, record: @record
  end

  test "retired show does not expose an existing quote" do
    assert_retired_route :get, "/cotacaos/#{@record.id}", record: @record
  end

  test "retired edit form is not exposed" do
    assert_retired_route :get, "/cotacaos/#{@record.id}/edit", record: @record
  end

  test "retired update leaves the quote unchanged" do
    assert_retired_route :patch, "/cotacaos/#{@record.id}", params: { cotacao: { valor: 200 } }, record: @record
  end

  test "retired destroy preserves the quote" do
    assert_retired_route :delete, "/cotacaos/#{@record.id}", record: @record
  end
end
