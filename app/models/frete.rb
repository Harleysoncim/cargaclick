# frozen_string_literal: true

class Frete < ApplicationRecord
  SEGURO_STATUSES = %w[
    nao_solicitado aguardando_dados aguardando_cotacao cotado contratado recusado erro
  ].freeze
  # ==========================================================
  # 📎 ASSOCIAÇÕES
  # ==========================================================
  belongs_to :cliente,       optional: true
  belongs_to :transportador, optional: true

  has_many :avaliacoes, dependent: :destroy
  has_one  :cotacao,    dependent: :destroy

  # ==========================================================
  # 🎛️ ENUMS (PREFIXADOS – SEM AMBIGUIDADE)
  # ==========================================================

  # Coluna: status (string)
  enum status: {
    pendente:     "pendente",
    aceito:       "aceito",
    em_andamento: "em_andamento",
    concluido:    "concluido",
    cancelado:    "cancelado"
  }, _prefix: :frete

  # Coluna: status_pagamento (integer)
  enum status_pagamento: {
    aguardando: 0,
    pago:       1,
    liberado:   2,
    cancelado:  3
  }, _prefix: :pagamento

  # Coluna: pin_status (string)
  enum pin_status: {
    pendente:   "pendente",
    confirmado: "confirmado",
    expirado:   "expirado"
  }, _prefix: :pin

  # ==========================================================
  # ✅ VALIDAÇÕES
  # ==========================================================
  validates :status, :status_pagamento, :pin_status, presence: true
  validates :seguro_status, inclusion: { in: SEGURO_STATUSES }
  validates :nfe_chave_acesso, format: { with: /\A\d{44}\z/ }, allow_blank: true
  validates :seguro_valor_carga,
            numericality: { greater_than: 0 },
            if: :seguro_carga?
  validate :seguro_contratado_exige_cotacao_confirmada

  validates :tentativas_pin,
            numericality: { greater_than_or_equal_to: 0 }

  validates :valor,
            :valor_estimado,
            :valor_negociado,
            :valor_final,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  # ==========================================================
  # 🔄 CALLBACKS (ORDEM SEGURA)
  # ==========================================================
  before_validation :definir_defaults,      on: :create
  before_validation :definir_valor_final,   on: :create
  before_validation :calcular_split!,       on: :create

  # ==========================================================
  # 🔐 PIN DE ENTREGA
  # ==========================================================
  def confirmar_entrega!(pin_informado)
    return false if pin_expirado?
    return false if tentativas_pin >= 3
    return false if pin_informado.blank?

    if ActiveSupport::SecurityUtils.secure_compare(
         pin_entrega.to_s,
         pin_informado.to_s
       )
      update!(
        pin_status:       :confirmado,
        status:           :concluido,
        status_pagamento: :liberado,
        entregue_em:      Time.current
      )
      true
    else
      registrar_tentativa_pin!
      false
    end
  end

  def expirar_pin!
    update!(pin_status: :expirado)
  end

  # ==========================================================
  # 💰 MONETIZAÇÃO
  # ==========================================================
  def valor_total
    base_para_split
  end

  # ==========================================================
  # 🔎 SCOPES
  # ==========================================================
  scope :disponiveis, -> { where(status: "pendente") }
  scope :recentes,   -> { order(created_at: :desc) }
  scope :por_cep, ->(cep) { where(origem_cep: cep) if cep.present? }

  def nfe_chave_mascarada
    return if nfe_chave_acesso.blank?

    "#{nfe_chave_acesso.first(6)}#{'*' * 32}#{nfe_chave_acesso.last(6)}"
  end

  def seguro_editavel?
    !frete_em_andamento? && !frete_concluido?
  end

  # ==========================================================
  # 🔒 MÉTODOS PRIVADOS
  # ==========================================================
  private

  def seguro_contratado_exige_cotacao_confirmada
    return unless seguro_status == "contratado"
    return if seguro_numero_cotacao.present? && seguro_seguradora.present? &&
              seguro_valor_premio.to_d.positive? && seguro_aceite_em.present?

    errors.add(:seguro_status, "não pode ser contratado sem cotação confirmada")
  end

  # ---------- Defaults seguros ----------
  def definir_defaults
    self.pin_entrega         ||= gerar_pin
    self.pin_status          ||= "pendente"
    self.status              ||= "pendente"
    self.status_pagamento    ||= "aguardando"
    self.tentativas_pin      ||= 0
    self.comissao_percentual ||= percentual_comissao_calculado
  end

  # ---------- Valor Final (REGRA-CHAVE) ----------
  def definir_valor_final
    self.valor_final ||= base_para_split
  end

  # ---------- PIN ----------
  def gerar_pin
    SecureRandom.random_number(10_000).to_s.rjust(4, "0")
  end

  def registrar_tentativa_pin!
    increment!(:tentativas_pin)
    expirar_pin! if tentativas_pin >= 3
  end

  # ---------- Comissão / Split ----------
  def calcular_split!
    base = base_para_split
    return if base <= 0

    percentual = percentual_comissao_calculado

    self.comissao_percentual = percentual
    self.valor_comissao      = (base * percentual / 100.0).round(2)
    self.valor_transportador = (base - valor_comissao).round(2)
  end

  def percentual_comissao_calculado
    ComissaoCalculator.percentual_para(transportador)
  end

  def base_para_split
    valor_final.presence ||
      valor_negociado.presence ||
      valor.presence ||
      valor_estimado.presence ||
      0
  end
end
