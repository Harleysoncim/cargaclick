require "rails_helper"

RSpec.describe "Fretes Quotation Integrity", type: :request do
  let!(:cliente) { create(:cliente, status_cadastro: :completo) }
  let!(:transportador) { create(:transportador, status: :ativo, status_cadastro: :completo) }

  describe "POST /fretes (create)" do
    context "with valid quotation" do
      let!(:cotacao) do
        create(
          :cotacao,
          transportador: transportador,
          valor: 100.00,
          status: "pendente",
          expires_at: 30.minutes.from_now
        )
      end

      it "creates frete with quotation value" do
        sign_in cliente
        expect {
          post fretes_path, params: {
            frete: {
              origem: "São Paulo",
              destino: "Rio de Janeiro",
              peso: 100,
              volume: 50,
              tipo_carga: "Eletrônicos",
              tipo_veiculo: "Carro",
              cotacao_id: cotacao.id
            }
          }
        }.to change(Frete, :count).by(1)

        frete = Frete.last
        expect(frete.cliente_id).to eq(cliente.id)
        expect(frete.valor).to eq(BigDecimal("100.00"))
        expect(frete.cotacao_id).to eq(cotacao.id)
      end
    end

    context "with expired quotation" do
      let!(:cotacao) do
        create(
          :cotacao,
          transportador: transportador,
          valor: 100.00,
          status: "pendente",
          expires_at: 5.minutes.ago
        )
      end

      it "rejects with error message" do
        sign_in cliente
        post fretes_path, params: {
          frete: {
            origem: "São Paulo",
            destino: "Rio de Janeiro",
            peso: 100,
            volume: 50,
            tipo_carga: "Eletrônicos",
            tipo_veiculo: "Carro",
            cotacao_id: cotacao.id
          }
        }

        expect(response).to redirect_to(simular_frete_path)
        expect(flash[:alert]).to include("inválida ou expirada")
      end
    end

    context "without quotation ID" do
      it "rejects with error message" do
        sign_in cliente
        post fretes_path, params: {
          frete: {
            origem: "São Paulo",
            destino: "Rio de Janeiro",
            peso: 100,
            volume: 50,
            tipo_carga: "Eletrônicos",
            tipo_veiculo: "Carro"
          }
        }

        expect(response).to redirect_to(simular_frete_path)
        expect(flash[:alert]).to include("inválida ou expirada")
      end
    end

    context "with rejected quotation" do
      let!(:cotacao) do
        create(
          :cotacao,
          transportador: transportador,
          valor: 100.00,
          status: "rejeitado",
          expires_at: 30.minutes.from_now
        )
      end

      it "rejects the contract" do
        sign_in cliente
        post fretes_path, params: {
          frete: {
            origem: "São Paulo",
            destino: "Rio de Janeiro",
            peso: 100,
            volume: 50,
            tipo_carga: "Eletrônicos",
            tipo_veiculo: "Carro",
            cotacao_id: cotacao.id
          }
        }

        expect(response).to redirect_to(simular_frete_path)
        expect(flash[:alert]).to include("inválida ou expirada")
      end
    end

    context "when user tries to override valor parameter" do
      let!(:cotacao) do
        create(
          :cotacao,
          transportador: transportador,
          valor: 100.00,
          status: "pendente",
          expires_at: 30.minutes.from_now
        )
      end

      it "ignores the valor parameter and uses quotation value" do
        sign_in cliente
        post fretes_path, params: {
          frete: {
            origem: "São Paulo",
            destino: "Rio de Janeiro",
            peso: 100,
            volume: 50,
            tipo_carga: "Eletrônicos",
            tipo_veiculo: "Carro",
            cotacao_id: cotacao.id,
            valor: 50.00
          }
        }

        frete = Frete.last
        expect(frete.valor).to eq(BigDecimal("100.00"))
      end
    end
  end

  describe "Cotacao expiry" do
    context "when creating new cotacao" do
      it "sets default expiry of 30 minutes" do
        cotacao = create(:cotacao, transportador: transportador)
        expect(cotacao.expires_at).to be_present
        expect(cotacao.expires_at).to be_within(1.minute).of(30.minutes.from_now)
      end
    end

    context "when calling Cotacao.valid scope" do
      before do
        create(:cotacao, transportador: transportador, expires_at: 5.minutes.from_now)
        create(:cotacao, transportador: transportador, expires_at: 5.minutes.ago)
        create(:cotacao, transportador: transportador, expires_at: nil)
      end

      it "returns only non-expired cotacoes" do
        valid_count = Cotacao.valid.count
        expect(valid_count).to eq(2)
      end
    end

    context "when calling expired? method" do
      it "returns true for expired cotacao" do
        cotacao = create(:cotacao, transportador: transportador, expires_at: 5.minutes.ago)
        expect(cotacao.expired?).to be true
      end

      it "returns false for valid cotacao" do
        cotacao = create(:cotacao, transportador: transportador, expires_at: 5.minutes.from_now)
        expect(cotacao.expired?).to be false
      end
    end
  end
end
