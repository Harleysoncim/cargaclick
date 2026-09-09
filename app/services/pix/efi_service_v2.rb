# frozen_string_literal: true

module Pix
  class EfiServiceV2
    class Error < StandardError; end

    def initialize(frete:)
      @frete = frete
      validar_frete!
    end

    # --------------------------------------------------------
    # Cria cobrança Pix imediata
    # --------------------------------------------------------
    def criar_cobranca!
      response = Payments::Efi.client.pix_create_immediate_charge(payload)

      persistir_pix!(response)

      response
    rescue => e
      Rails.logger.error("[PIX][EFI] Erro ao criar cobrança: #{e.class} - #{e.message}")
      raise Error, "Falha ao criar cobrança Pix"
    end

    private

    # --------------------------------------------------------
    # Validações
    # --------------------------------------------------------
    def validar_frete!
      raise Error, "Frete inválido" unless @frete.is_a?(Frete)

      valor = valor_base
      raise Error, "Valor do frete inválido" if valor <= 0

      raise Error, "Configuração Efi ausente" unless Payments::Efi.config.present?
      raise Error, "Chave Pix não configurada" if ENV["EFI_PIX_KEY"].blank?
    end

    # --------------------------------------------------------
    # Payload Pix (Efi)
    # --------------------------------------------------------
    def payload
      {
        calendario: { expiracao: 3600 }, # 1 hora
        valor: {
          original: format("%.2f", valor_base)
        },
        chave: ENV["EFI_PIX_KEY"],
        solicitacaoPagador: descricao_pagamento
      }
    end

    # --------------------------------------------------------
    # Persistência segura
    # --------------------------------------------------------
    def persistir_pix!(response)
      @frete.update!(
        pix_txid:           response["txid"],
        pix_qr_code:        response.dig("loc", "qrcode"),
        pix_copia_cola:     response.dig("pixCopiaECola"),
        status_pagamento:   "aguardando"
      )
    end

    # --------------------------------------------------------
    # Utilitários
    # --------------------------------------------------------
    def valor_base
      (@frete.valor_final || @frete.valor_estimado).to_d
    end

    def descricao_pagamento
      "Frete ##{@frete.id} — CargaClick"
    end
  end
end
