require "test_helper"

class PropostaControllerTest < ActionDispatch::IntegrationTest
  include RetiredRoutes

  setup do
    frete = create_test_frete
    @record = Proposta.create!(frete: frete, cliente_id: frete.cliente_id,
                               transportador: frete.transportador, valor: 100, descricao: "Teste")
  end

  test "retired index is not exposed" do
    assert_retired_route :get, "/proposta", record: @record
  end

  test "retired new form is not exposed" do
    assert_retired_route :get, "/proposta/new", record: @record
  end

  test "retired create cannot insert a proposal" do
    assert_retired_route :post, "/proposta", params: { propostum: { valor_proposto: 200 } }, record: @record
  end

  test "retired show does not expose an existing proposal" do
    assert_retired_route :get, "/proposta/#{@record.id}", record: @record
  end

  test "retired edit form is not exposed" do
    assert_retired_route :get, "/proposta/#{@record.id}/edit", record: @record
  end

  test "retired update leaves the proposal unchanged" do
    assert_retired_route :patch, "/proposta/#{@record.id}", params: { propostum: { valor_proposto: 200 } }, record: @record
  end

  test "retired destroy preserves the proposal" do
    assert_retired_route :delete, "/proposta/#{@record.id}", record: @record
  end
end
