# frozen_string_literal: true

module Pix
  class EfiService
    class Error < StandardError; end

    def initialize(frete:)
      @frete = frete

      raise Error, "Frete inválido" unless @frete.is_a?(Frete)

      base = valor_base
      raise Error, "Valor do frete inválido" if base.to_d <= 0

      raise Error, "Configuração EFI ausente" unless Payments::Efi.config.present?
    end

    # =========================================================
    # Cria cobrança Pix imediata (EFI)
    # =========================================================
    def criar_cobranca!
      raise Error, "Frete já possui cobrança Pix" if @frete.pix_txid.present?

      # Garante cálculo do split antes da cobrança
      @frete.calcular_split!

      response = efi_client.pix_create_immediate_charge(payload)

      persistir_pix!(response)

      response
    rescue => e
      Rails.logger.error("[PIX][EFI] #{e.class} - #{e.message}")
      raise Error, "Falha ao criar cobrança Pix"
    end

    private

    # =========================================================
    # Cliente EFI SDK
    # =========================================================
    def efi_client
      @efi_client ||= EfiPay.new(Payments::Efi.config)
    end

    # =========================================================
    # Payload da cobrança
    # =========================================================
    def payload
      {
        calendario: {
          expiracao: 3600 # 1 hora
        },
        valor: {
          original: format("%.2f", valor_base)
        },
        solicitacaoPagador: descricao_pagamento
      }
    end

    # =========================================================
    # Persistência segura no Frete
    # =========================================================
    def persistir_pix!(response)
      @frete.update!(
        pix_txid:         response["txid"],
        pix_qr_code:      response.dig("qrCode"),
        pix_copia_cola:   response.dig("pixCopiaECola"),
        status_pagamento: "aguardando"
      )
    end

    # =========================================================
    # Helpers
    # =========================================================
    def valor_base
      @frete.valor_final || @frete.valor_estimado
    end

    def descricao_pagamento
      "Frete ##{@frete.id} — CargaClick"
    end
  end
end
