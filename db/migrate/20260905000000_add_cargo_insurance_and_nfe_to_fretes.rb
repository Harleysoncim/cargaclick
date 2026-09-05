# frozen_string_literal: true

class AddCargoInsuranceAndNfeToFretes < ActiveRecord::Migration[7.1]
  def change
    change_table :fretes, bulk: true do |t|
      t.boolean :seguro_carga, null: false, default: false
      t.string :seguro_status, null: false, default: "nao_solicitado"
      t.decimal :seguro_valor_carga, precision: 12, scale: 2
      t.decimal :seguro_valor_premio, precision: 12, scale: 2
      t.string :seguro_seguradora
      t.string :seguro_numero_cotacao
      t.datetime :seguro_cotado_em
      t.datetime :seguro_aceite_em
      t.datetime :seguro_recusado_em
      t.boolean :seguro_consentimento, null: false, default: false
      t.datetime :seguro_consentimento_em
      t.text :seguro_descricao_mercadoria
      t.string :seguro_origem
      t.string :seguro_destino
      t.decimal :seguro_peso, precision: 10, scale: 2
      t.string :seguro_tipo_veiculo
      t.boolean :seguro_carga_perigosa, null: false, default: false
      t.boolean :seguro_carga_perecivel, null: false, default: false
      t.boolean :seguro_carga_alto_valor, null: false, default: false

      t.string :nfe_chave_acesso
      t.text :nfe_qrcode_url
      t.string :nfe_numero
      t.string :nfe_serie
      t.string :nfe_emitente_documento
      t.string :nfe_emitente_nome
      t.decimal :nfe_valor_total, precision: 12, scale: 2
      t.datetime :nfe_lida_em
    end

    add_index :fretes, :nfe_chave_acesso
    add_index :fretes, :seguro_status
  end
end
