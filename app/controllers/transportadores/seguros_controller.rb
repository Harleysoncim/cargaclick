# frozen_string_literal: true

module Transportadores
  class SegurosController < ApplicationController
    before_action :authenticate_transportador!
    before_action :set_frete
    before_action :ensure_editable!, only: %i[update cotar aceitar destroy]

    def show; end

    def ler_nfe
      @nfe_preview = Nfe::QrcodeParser.call(params[:nfe_qrcode_text])
      flash.now[:alert] = @nfe_preview.error unless @nfe_preview.success?
      render :show, status: @nfe_preview.success? ? :ok : :unprocessable_entity
    end

    def update
      if params[:decision] == "sem_seguro"
        @frete.update!(seguro_carga: false, seguro_status: "recusado", seguro_recusado_em: Time.current)
        redirect_to transportadores_frete_seguro_path(@frete), notice: "Decisão registrada. A carga seguirá sem seguro contratado pela plataforma."
      elsif params[:nfe_qrcode_text].present?
        save_nfe
      else
        @frete.update!(insurance_params.merge(seguro_status: "aguardando_dados"))
        redirect_to transportadores_frete_seguro_path(@frete), notice: "Dados da carga atualizados."
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    def cotar
      return redirect_pending if @frete.seguro_status == "aguardando_cotacao"

      @frete.assign_attributes(insurance_params)
      @frete.seguro_consentimento_em ||= Time.current if @frete.seguro_consentimento?
      result = Seguros::Cotador.new(@frete).call
      if result.success?
        redirect_pending
      else
        flash.now[:alert] = result.error
        render :show, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    def aceitar
      unless @frete.seguro_status == "cotado" && @frete.seguro_numero_cotacao.present?
        return redirect_to transportadores_frete_seguro_path(@frete), alert: "Ainda não existe cotação válida para aceitar."
      end

      @frete.update!(seguro_status: "contratado", seguro_aceite_em: Time.current)
      redirect_to transportadores_frete_seguro_path(@frete), notice: "Seguro confirmado pela seguradora."
    end

    def destroy
      @frete.update!(
        seguro_carga: false, seguro_status: "nao_solicitado", seguro_recusado_em: nil,
        seguro_consentimento: false, seguro_consentimento_em: nil,
        seguro_valor_premio: nil, seguro_seguradora: nil, seguro_numero_cotacao: nil,
        seguro_cotado_em: nil, seguro_aceite_em: nil
      )
      redirect_to transportadores_frete_seguro_path(@frete), notice: "Decisão de seguro redefinida."
    end

    private

    def set_frete
      @frete = Frete.where("transportador_id = :id OR (transportador_id IS NULL AND status = :status)",
                           id: current_transportador.id, status: "pendente")
                    .find(params[:frete_id])
    end

    def ensure_editable!
      return if @frete.seguro_editavel?

      redirect_to transportadores_frete_seguro_path(@frete), alert: "O seguro não pode mais ser alterado após o início do frete."
    end

    def save_nfe
      parsed = Nfe::QrcodeParser.call(params[:nfe_qrcode_text])
      unless parsed.success?
        flash.now[:alert] = parsed.error
        return render :show, status: :unprocessable_entity
      end

      @frete.update!(nfe_chave_acesso: parsed.access_key, nfe_qrcode_url: parsed.url, nfe_lida_em: Time.current)
      redirect_to transportadores_frete_seguro_path(@frete), notice: "Nota fiscal vinculada ao frete."
    end

    def insurance_params
      params.fetch(:frete, ActionController::Parameters.new).permit(
        :seguro_valor_carga, :seguro_descricao_mercadoria, :seguro_consentimento,
        :seguro_origem, :seguro_destino, :seguro_peso, :seguro_tipo_veiculo,
        :seguro_carga_perigosa, :seguro_carga_perecivel, :seguro_carga_alto_valor,
        :nfe_emitente_documento, :nfe_emitente_nome, :nfe_numero, :nfe_serie, :nfe_valor_total
      )
    end

    def redirect_pending
      redirect_to transportadores_frete_seguro_path(@frete), notice: "Solicitação enviada para análise. Cotação não significa seguro contratado."
    end
  end
end
