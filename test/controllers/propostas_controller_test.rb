require "test_helper"

class PropostasControllerTest < ActionDispatch::IntegrationTest
  include RetiredRoutes

  test "retired nova URL is not exposed" do
    assert_retired_route :get, "/propostas/nova"
  end

  test "retired create URL does not create proposals through GET" do
    assert_retired_route :get, "/propostas/create"
  end
end
