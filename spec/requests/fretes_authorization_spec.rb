require "rails_helper"

RSpec.describe "Fretes Authorization", type: :request do
  let!(:cliente1) { create(:cliente, status_cadastro: :completo) }
  let!(:cliente2) { create(:cliente, status_cadastro: :completo) }
  let!(:transportador1) { create(:transportador, status: :ativo, status_cadastro: :completo) }
  let!(:frete) { create(:frete, cliente: cliente1, transportador: transportador1) }

  describe "GET /fretes/:id (show)" do
    context "when cliente owns the frete" do
      it "allows access" do
        sign_in cliente1
        get frete_path(frete)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when cliente does not own the frete" do
      it "denies access with 404" do
        sign_in cliente2
        get frete_path(frete)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when transportador is linked to frete" do
      it "allows access" do
        sign_in transportador1
        get frete_path(frete)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when transportador is not linked to frete" do
      let!(:transportador2) { create(:transportador, status: :ativo) }

      it "denies access with 404" do
        sign_in transportador2
        get frete_path(frete)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when admin" do
      let!(:admin) { create(:admin_user) }

      it "allows access" do
        sign_in admin
        get frete_path(frete)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to login" do
        get frete_path(frete)
        expect(response).to redirect_to(new_cliente_session_path)
      end
    end
  end

  describe "GET /fretes/:id/edit (edit)" do
    context "when cliente owns the frete" do
      it "allows access" do
        sign_in cliente1
        get edit_frete_path(frete)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when another cliente tries to edit" do
      it "denies access with 404" do
        sign_in cliente2
        get edit_frete_path(frete)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH/PUT /fretes/:id (update)" do
    context "when cliente owns the frete" do
      it "allows update" do
        sign_in cliente1
        patch frete_path(frete), params: { frete: { descricao: "Updated" } }
        expect(response).to redirect_to(frete_path(frete))
      end
    end

    context "when another cliente tries to update" do
      it "denies access with 404" do
        sign_in cliente2
        patch frete_path(frete), params: { frete: { descricao: "Hacked" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /fretes/:id (destroy)" do
    context "when cliente owns the frete" do
      it "allows deletion" do
        sign_in cliente1
        delete frete_path(frete)
        expect(response).to redirect_to(inicio_path)
        expect(Frete.find_by(id: frete.id)).to be_nil
      end
    end

    context "when another cliente tries to delete" do
      it "denies access with 404" do
        sign_in cliente2
        delete frete_path(frete)
        expect(response).to have_http_status(:not_found)
        expect(Frete.find_by(id: frete.id)).to be_present
      end
    end
  end
end
