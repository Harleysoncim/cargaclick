# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Freight pricing fallback", type: :request do
  it "keeps the current estimate labeled as provisional when disabled" do
    allow(CalcularFrete).to receive(:call).and_return(
      sucesso: true,
      origem: "São Paulo",
      destino: "Santos",
      peso: BigDecimal("10"),
      volume: BigDecimal("1"),
      distancia_km: 75.57,
      duracao_minutos: 75.0,
      valor_total: BigDecimal("188.93"),
      breakdown: { subtotal_km: BigDecimal("188.93"), taxa_minima: BigDecimal("30") },
      pricing: FreightPricingService.call(
        params: { peso: BigDecimal("10"), volume: BigDecimal("1") },
        route: { distancia_km: 75.57, duracao_minutos: 75.0 },
        fallback: { valor_final: BigDecimal("188.93"), subtotal_km: BigDecimal("188.93"), taxa_minima: BigDecimal("30") }
      )
    )

    post "/simular-frete", params: { origem: "São Paulo", destino: "Santos", peso: "10", volume: "1" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Estimativa provisória")
    expect(response.body).to include("Amostra insuficiente")
    expect(response.body).not_to include("média nacional")
  end
end
