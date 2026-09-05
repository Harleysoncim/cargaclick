# frozen_string_literal: true

require "rails_helper"

RSpec.describe Frete, type: :model do
  subject(:frete) { described_class.new(origem: "São Paulo", destino: "Santos") }

  it "rejects an unknown insurance status" do
    frete.seguro_status = "inventado"
    expect(frete).not_to be_valid
  end

  it "requires a positive cargo value when insurance is requested" do
    frete.seguro_carga = true
    frete.seguro_valor_carga = 0
    expect(frete).not_to be_valid
  end

  it "does not mark insurance as contracted without a confirmed quote" do
    frete.seguro_status = "contratado"
    expect(frete).not_to be_valid
    expect(frete.errors[:seguro_status]).to be_present
  end

  it "accepts a 44-digit NF-e access key" do
    frete.nfe_chave_acesso = "1" * 44
    frete.valid?
    expect(frete.errors[:nfe_chave_acesso]).to be_empty
  end
end
