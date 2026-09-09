require "test_helper"

class BolsaoControllerTest < ActionDispatch::IntegrationTest
  include RetiredRoutes

  test "retired bolsao index is not exposed" do
    assert_retired_route :get, "/bolsao/index"
  end
end
