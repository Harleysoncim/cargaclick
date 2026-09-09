# frozen_string_literal: true

# The scaffold endpoints are absent from config/routes.rb. Protect that boundary
# with real requests and persisted records instead of reintroducing old routes.
module RetiredRoutes
  def create_test_frete
    cliente = Cliente.create!(nome: "Cliente Teste", email: "cliente.routes@example.com", password: "test-password")
    transportador = Transportador.create!(email: "driver.routes@example.com", password: "test-password")
    Frete.create!(origem: "Origem Teste", destino: "Destino Teste", cliente: cliente, transportador: transportador)
  end

  def assert_retired_route(method, path, params: {}, record: nil)
    original_attributes = record&.attributes
    assert_no_difference(["Proposta.count", "Cotacao.count", "Modal.count", "Frete.count"]) do
      public_send(method, path, params: params)
    end
    assert_response :not_found
    assert_equal "Página não encontrada", response.body
    assert_equal original_attributes, record.reload.attributes if record
  end
end
