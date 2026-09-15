require "rails_helper"

RSpec.describe "Webhook Security", type: :request do
  let!(:cliente) { create(:cliente) }
  let!(:transportador) { create(:transportador) }
  let!(:cotacao) { create(:cotacao, transportador: transportador, valor: 100.00) }
  let!(:frete) do
    create(
      :frete,
      cliente: cliente,
      transportador: transportador,
      cotacao: cotacao,
      valor_final: 100.00,
      external_payment_id: "payment_123"
    )
  end

  describe "Webhook Validation" do
    let(:webhook_payload) do
      { data: { id: "payment_123", amount: 100.00 } }.to_json
    end

    context "with valid amount matching quotation" do
      before do
        allow(MercadoPagoPixService).to receive(:fetch).and_return(
          { approved: true, amount: 100.00 }
        )
      end

      it "accepts webhook and updates payment status" do
        post "/webhooks/pix/mercado_pago", params: webhook_payload

        expect(response).to have_http_status(:ok)
        expect(frete.reload.status_pagamento).to eq("pago")
      end
    end

    context "with invalid payload (malformed JSON)" do
      it "handles gracefully" do
        post "/webhooks/pix/mercado_pago", params: "invalid json"

        expect(response.status).to be_in([400, 422])
      end
    end
  end

  describe "Webhook Idempotency" do
    let(:webhook_payload) do
      { data: { id: "payment_123", amount: 100.00 } }.to_json
    end

    before do
      allow(MercadoPagoPixService).to receive(:fetch).and_return(
        { approved: true, amount: 100.00 }
      )
    end

    context "when webhook is processed twice" do
      it "processes only once (idempotent)" do
        expect {
          2.times do
            post "/webhooks/pix/mercado_pago", params: webhook_payload
            expect(response).to have_http_status(:ok)
          end
        }.to change(WebhookIdempotencyRecord, :count).by(1)

        processed_records = WebhookIdempotencyRecord.processed.count
        expect(processed_records).to eq(1)
      end
    end

    context "when webhook is replayed" do
      it "does not update status twice" do
        post "/webhooks/pix/mercado_pago", params: webhook_payload
        expect(frete.reload.status_pagamento).to eq("pago")
        first_updated_at = frete.updated_at

        sleep 0.1

        post "/webhooks/pix/mercado_pago", params: webhook_payload
        expect(frete.reload.status_pagamento).to eq("pago")
        expect(frete.updated_at).to eq(first_updated_at)
      end
    end
  end

  describe "Webhook Amount Validation" do
    before do
      allow(MercadoPagoPixService).to receive(:fetch).and_return(
        { approved: true, amount: 50.00 }
      )
    end

    context "when payment amount does not match quotation value" do
      let(:webhook_payload) do
        { data: { id: "payment_123", amount: 50.00 } }.to_json
      end

      it "rejects webhook with 422" do
        post "/webhooks/pix/mercado_pago", params: webhook_payload

        expect(response).to have_http_status(:unprocessable_entity)
        expect(frete.reload.status_pagamento).not_to eq("pago")
      end
    end

    context "when quotation expired" do
      let(:webhook_payload) do
        { data: { id: "payment_123", amount: 100.00 } }.to_json
      end

      before do
        cotacao.update(expires_at: 5.minutes.ago)
      end

      it "rejects webhook with 422" do
        post "/webhooks/pix/mercado_pago", params: webhook_payload

        expect(response).to have_http_status(:unprocessable_entity)
        expect(frete.reload.status_pagamento).not_to eq("pago")
      end
    end
  end

  describe "Webhook Without Frete" do
    context "when payment refers to non-existent frete" do
      let(:webhook_payload) do
        { data: { id: "payment_nonexistent", amount: 100.00 } }.to_json
      end

      before do
        allow(MercadoPagoPixService).to receive(:fetch).and_return(
          { approved: true, amount: 100.00 }
        )
      end

      it "returns 200 OK (no action needed)" do
        post "/webhooks/pix/mercado_pago", params: webhook_payload

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "EFI PIX Webhook" do
    context "with valid EFI payload" do
      let(:efi_payload) do
        {
          txid: "external_ref_123",
          valor: 100.00
        }.to_json
      end

      before do
        frete.update(external_reference: "external_ref_123")
      end

      it "processes payment correctly" do
        post "/webhooks/efi/pix/callback", params: efi_payload

        expect(response).to have_http_status(:ok)
        expect(frete.reload.status_pagamento).to eq("pago")
      end
    end

    context "with invalid amount in EFI payload" do
      let(:efi_payload) do
        {
          txid: "external_ref_123",
          valor: 50.00
        }.to_json
      end

      before do
        frete.update(external_reference: "external_ref_123")
      end

      it "rejects with 422" do
        post "/webhooks/efi/pix/callback", params: efi_payload

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
