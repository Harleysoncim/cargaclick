# frozen_string_literal: true

require "test_helper"

class AdminAtendimentosGerenciaisTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "redirects anonymous users to admin login" do
    get admin_atendimentos_gerenciais_path

    assert_redirected_to new_admin_user_session_path
  end

  test "renders dashboard for an authenticated administrator" do
    admin = AdminUser.create!(email: "gestor@example.com", password: "senha-segura")
    sign_in admin

    get admin_atendimentos_gerenciais_path, params: { period: "today" }

    assert_response :success
    assert_select "h2", "Atendimentos Gerenciais"
    assert_select ".mgmt-card", minimum: 14
  end

  test "returns validation error from protected data endpoint" do
    admin = AdminUser.create!(email: "gestor.api@example.com", password: "senha-segura")
    sign_in admin

    get data_admin_atendimentos_gerenciais_path, params: { period: "custom", start_date: "2026-09-01", end_date: "2026-08-01" }

    assert_response :unprocessable_entity
    assert_match(/data inicial/, response.parsed_body.fetch("error"))
  end
end
