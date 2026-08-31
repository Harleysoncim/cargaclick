# frozen_string_literal: true

require "test_helper"

class Admin::ManagementMetricsTest < ActiveSupport::TestCase
  test "rejects an inverted custom range" do
    error = assert_raises(ArgumentError) do
      Admin::ManagementMetrics.new(period: "custom", start_date: "2026-08-20", end_date: "2026-08-10")
    end

    assert_match(/data inicial/, error.message)
  end

  test "builds equivalent previous range" do
    service = Admin::ManagementMetrics.new(
      period: "custom",
      start_date: "2026-08-01",
      end_date: "2026-08-07",
      now: Time.zone.parse("2026-08-31 12:00")
    )

    assert_equal service.end_at - service.start_at, service.previous_end_at - service.previous_start_at
    assert_equal service.start_at - 1.second, service.previous_end_at
  end

  test "returns unavailable instead of dividing by zero" do
    dashboard = Admin::ManagementMetrics.new(
      period: "custom",
      start_date: "2000-01-01",
      end_date: "2000-01-02",
      now: Time.zone.parse("2026-08-31 12:00")
    ).call

    ticket = dashboard.dig(:sections, :commercial).find { |item| item[:name] == "Ticket médio" }
    conversion = dashboard.dig(:sections, :commercial).find { |item| item[:name] == "Taxa de conversão" }

    assert_not ticket[:available]
    assert_not conversion[:available]
    assert_nil ticket[:comparison]
  end

  test "calculates revenue ticket and completed operations from persisted data" do
    timestamp = Time.zone.parse("2026-08-10 10:00")
    cliente = Cliente.create!(nome: "Cliente Métricas", email: "metricas@example.com", password: "senha-segura", status_cadastro: :completo)
    transportador = Transportador.create!(nome: "Transportador Métricas", email: "transportador.metricas@example.com", password: "senha-segura")
    frete_id = Frete.insert_all!([{
      cliente_id: cliente.id, transportador_id: transportador.id, origem: "A", destino: "B",
      status: "concluido", status_pagamento: "liberado", pin_status: "confirmado",
      tentativas_pin: 0, entregue_em: timestamp, valor_final: 200, created_at: timestamp, updated_at: timestamp
    }]).rows.first.first
    Pagamento.insert_all!([{
      frete_id: frete_id, cliente_id: cliente.id, transportador_id: transportador.id,
      valor: 200, status: "liberado", liberado_at: timestamp, created_at: timestamp, updated_at: timestamp
    }])

    dashboard = Admin::ManagementMetrics.new(period: "custom", start_date: "2026-08-10", end_date: "2026-08-10", now: timestamp).call
    commercial = dashboard.dig(:sections, :commercial).index_by { |item| item[:name] }

    assert_equal 200.to_d, commercial["Faturamento"][:value]
    assert_equal 200.to_d, commercial["Ticket médio"][:value]
    assert_equal 1, commercial["Cargas movimentadas"][:value]
  end
end
