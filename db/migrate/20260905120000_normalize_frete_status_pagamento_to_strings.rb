# frozen_string_literal: true

# Normaliza fretes.status_pagamento para o vocabulario de strings do enum.
#
# ---------------------------------------------------------------------------
# DECISAO: (a) manter a coluna como string e converter os dados.
#
# A alternativa (b) -- migrar a coluna para integer e usar enum numerico --
# foi descartada por tres razoes:
#
#   1. Consistencia interna. Os outros dois enums do Frete (status e
#      pin_status) sao string-valued sobre colunas string. status_pagamento
#      era o unico declarado com valores inteiros, e essa divergencia e
#      justamente a origem do bug: o valor ia ao banco como a string "0" e
#      voltava como String "0", que nao casa com a chave Integer 0 do enum.
#      O atributo lia nil e a validacao de presence reprovava todo update.
#
#   2. Legibilidade operacional. A coluna e indexada e consultada
#      diretamente em SQL/dashboards; "pago" e autoexplicativo, 1 nao e.
#
#   3. Menor risco de conversao. Migrar para integer exigiria dropar e
#      recriar o indice e fazer um cast de dados que hoje contem valores
#      textuais nao numericos ("pendente"), ou seja, um cast ambiguo.
#      Manter string transforma a migration em um simples remapeamento.
# ---------------------------------------------------------------------------
class NormalizeFreteStatusPagamentoToStrings < ActiveRecord::Migration[7.1]
  # Modelo leve e local: evita callbacks, validacoes e o proprio enum do
  # Frete, que durante a migration ainda pode estar em transicao.
  class MigrationFrete < ActiveRecord::Base
    self.table_name = "fretes"
    self.inheritance_column = nil
  end

  BATCH_SIZE = 500

  # Mapeamento reverso explicito: valor antigo (como esta gravado) -> valor novo.
  #
  # "0".."3" sao o resultado do enum numerico serializado na coluna string.
  # "pendente" era o default da coluna e nunca pertenceu ao enum; significa
  # "pagamento ainda nao efetuado", que e exatamente o papel de "aguardando".
  # "aguardando_pagamento" era gravado pelos servicos de PIX e tem o mesmo
  # significado, entao converge para o mesmo estado.
  FORWARD = {
    "0" => "aguardando",
    "1" => "pago",
    "2" => "liberado",
    "3" => "cancelado",
    "pendente" => "aguardando",
    "aguardando_pagamento" => "aguardando"
  }.freeze

  # A volta e aproximada: "aguardando" tinha tres origens possiveis
  # ("0", "pendente", "aguardando_pagamento") e nao ha como distingui-las
  # depois da convergencia. Restauramos a representacao numerica, que e a
  # que o enum antigo produzia.
  BACKWARD = {
    "aguardando" => "0",
    "pago" => "1",
    "liberado" => "2",
    "cancelado" => "3"
  }.freeze

  def up
    remap!(FORWARD)
    change_column_default :fretes, :status_pagamento, from: "pendente", to: "aguardando"
  end

  def down
    change_column_default :fretes, :status_pagamento, from: "aguardando", to: "pendente"
    remap!(BACKWARD)
  end

  private

  # Backfill em lote: in_batches + update_all opera via UPDATE ... WHERE id IN (...)
  # sem instanciar registros, entao a tabela nunca e carregada em memoria.
  def remap!(mapping)
    mapping.each do |from, to|
      MigrationFrete.where(status_pagamento: from).in_batches(of: BATCH_SIZE) do |batch|
        batch.update_all(status_pagamento: to)
      end
    end

    leftovers = MigrationFrete.where.not(status_pagamento: mapping.values.uniq).distinct
                              .pluck(:status_pagamento)
    return if leftovers.empty?

    say "AVISO: valores de status_pagamento fora do mapeamento permaneceram intactos: #{leftovers.inspect}"
  end
end
