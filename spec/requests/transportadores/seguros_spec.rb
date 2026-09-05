# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transportadores cargo insurance", type: :request do
  let!(:transportador) { Transportador.create!(email: "driver@example.com", password: "Password123!") }
  let!(:other_transportador) { Transportador.create!(email: "other@example.com", password: "Password123!") }
  let!(:frete) { Frete.create!(origem: "São Paulo", destino: "Santos", transportador:) }

  it "redirects an unauthenticated carrier" do
    get transportadores_frete_seguro_path(frete)
    expect(response).to redirect_to(new_transportador_session_path)
  end

  it "does not expose another carrier's shipment" do
    sign_in other_transportador
    get transportadores_frete_seguro_path(frete)
    expect(response).to have_http_status(:not_found)
  end

  it "opens the screen for the assigned carrier" do
    sign_in transportador
    get transportadores_frete_seguro_path(frete)
    expect(response).to have_http_status(:ok)
  end

  it "saves the choice to proceed without insurance" do
    sign_in transportador
    patch transportadores_frete_seguro_path(frete), params: { decision: "sem_seguro" }
    expect(frete.reload).to have_attributes(seguro_carga: false, seguro_status: "recusado")
  end

  it "does not accept financial quote fields from the browser" do
    sign_in transportador
    patch transportadores_frete_seguro_path(frete), params: {
      frete: { seguro_valor_premio: "1.00", seguro_numero_cotacao: "FAKE", seguro_seguradora: "Fake" }
    }
    expect(frete.reload.seguro_valor_premio).to be_nil
    expect(frete.seguro_numero_cotacao).to be_nil
  end

  it "deduplicates a quote already awaiting analysis" do
    frete.update_columns(seguro_status: "aguardando_cotacao", seguro_carga: true, seguro_valor_carga: 100)
    sign_in transportador
    expect(Seguros::Cotador).not_to receive(:new)
    post cotar_transportadores_frete_seguro_path(frete)
    expect(response).to redirect_to(transportadores_frete_seguro_path(frete))
  end
end
