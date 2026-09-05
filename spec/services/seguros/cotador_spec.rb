# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seguros::Cotador do
  it "does not create a quote without cargo value" do
    frete = Frete.new(seguro_consentimento: true)
    result = described_class.new(frete).call
    expect(result).not_to be_success
    expect(result.error).to match(/valor de carga/)
  end

  it "leaves an offline request waiting for a real quote" do
    frete = Frete.new(
      seguro_valor_carga: 100, seguro_consentimento: true,
      seguro_descricao_mercadoria: "Alimentos", seguro_origem: "São Paulo",
      seguro_destino: "Santos", seguro_peso: 10, seguro_tipo_veiculo: "Furgão"
    )
    allow(frete).to receive(:update!).and_return(true)
    result = described_class.new(frete).call
    expect(result).to be_success
    expect(result.status).to eq("aguardando_cotacao")
  end
end
