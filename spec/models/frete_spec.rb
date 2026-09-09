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

  describe "status_pagamento" do
    # Regressao: o enum era declarado com valores inteiros sobre uma coluna
    # string, entao o valor ia ao banco como "0" e voltava como String "0",
    # que nao casa com a chave Integer 0. O atributo lia nil e a validacao de
    # presence reprovava QUALQUER update de frete ja persistido.
    it "survives a database round-trip" do
      persisted = described_class.create!(origem: "São Paulo", destino: "Santos")
      expect(persisted.status_pagamento).to eq("aguardando")

      reloaded = described_class.find(persisted.id)
      expect(reloaded.status_pagamento).to eq("aguardando")
      expect(reloaded.read_attribute_before_type_cast(:status_pagamento)).to eq("aguardando")
    end

    it "allows updating an already persisted shipment" do
      persisted = described_class.create!(origem: "São Paulo", destino: "Santos")
      reloaded = described_class.find(persisted.id)

      expect(reloaded.update(origem: "Campinas")).to be(true)
      expect(reloaded.errors).to be_empty
    end

    it "exposes the prefixed predicates over string values" do
      persisted = described_class.create!(origem: "São Paulo", destino: "Santos")
      expect(persisted).to be_pagamento_aguardando

      persisted.update!(status_pagamento: :pago)
      expect(persisted.reload).to be_pagamento_pago
    end
  end
end
