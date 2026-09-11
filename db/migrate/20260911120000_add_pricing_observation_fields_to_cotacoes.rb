# frozen_string_literal: true

class AddPricingObservationFieldsToCotacoes < ActiveRecord::Migration[7.1]
  def change
    change_table :cotacoes, bulk: true do |t|
      t.string :tipo_veiculo
      t.integer :numero_eixos
      t.string :tipo_carga
      t.decimal :distancia_km, precision: 12, scale: 3
      t.decimal :duracao_minutos, precision: 10, scale: 2
      t.decimal :peso_real, precision: 12, scale: 3
      t.decimal :volume, precision: 12, scale: 3
      t.decimal :peso_cubado, precision: 12, scale: 3
      t.decimal :peso_tarifavel, precision: 12, scale: 3
      t.string :regiao_origem
      t.string :regiao_destino
      t.decimal :pedagio, precision: 12, scale: 2
      t.decimal :distancia_retorno_km, precision: 12, scale: 3
      t.string :urgencia
      t.decimal :valor_cotado, precision: 12, scale: 2
      t.decimal :valor_aceito, precision: 12, scale: 2
      t.datetime :data_cotacao
      t.string :versao_tabela_tarifaria
    end

    add_index :cotacoes, [:status, :tipo_veiculo, :tipo_carga], name: "idx_cotacoes_pricing_comparability"
    add_index :cotacoes, :data_cotacao
  end
end
