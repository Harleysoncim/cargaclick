require "test_helper"

class NavegacaoPublicaTest < ActionDispatch::IntegrationTest

  test "rota raiz responde" do
    get root_path
    assert_response :success
  end

  test "rota simular frete responde" do
    get simular_frete_path
    assert_response :success
  end

  test "home exibe saudacao do CargaClick" do
    get root_path
    assert_response :success
    assert_select "[role='img'][aria-label*='bem-vindo ao CargaClick']", text: /Bem-vindo ao CargaClick/
  end

  test "rota contato responde" do
    get contato_path
    assert_response :success
  end

  test "rota fidelidade responde se existir" do
    if Rails.application.routes.url_helpers.respond_to?(:fidelidade_path)
      get fidelidade_path
      assert_response :success
    else
      assert true
    end
  end

end
