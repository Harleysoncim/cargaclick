require "test_helper"

class ModalsControllerTest < ActionDispatch::IntegrationTest
  include RetiredRoutes

  setup do
    @record = Modal.create!(nome: "Rodoviário Teste")
  end

  test "retired index is not exposed" do
    assert_retired_route :get, "/modals", record: @record
  end

  test "retired new form is not exposed" do
    assert_retired_route :get, "/modals/new", record: @record
  end

  test "retired create cannot insert a modal" do
    assert_retired_route :post, "/modals", params: { modal: { nome: "Indevido" } }, record: @record
  end

  test "retired show does not expose an existing modal" do
    assert_retired_route :get, "/modals/#{@record.id}", record: @record
  end

  test "retired edit form is not exposed" do
    assert_retired_route :get, "/modals/#{@record.id}/edit", record: @record
  end

  test "retired update leaves the modal unchanged" do
    assert_retired_route :patch, "/modals/#{@record.id}", params: { modal: { nome: "Indevido" } }, record: @record
  end

  test "retired destroy preserves the modal" do
    assert_retired_route :delete, "/modals/#{@record.id}", record: @record
  end
end
