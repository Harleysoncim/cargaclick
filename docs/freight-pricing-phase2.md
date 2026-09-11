# Fase 2 — Observações e estatística tarifária

## Migration proposta, não executada

`db/migrate/20260911120000_add_pricing_observation_fields_to_cotacoes.rb` adiciona campos nulos à tabela `cotacoes` para registrar snapshots comparáveis. `Cotacao.valor` permanece legado; `valor_cotado` registra explicitamente a observação tarifária e `valor_aceito` registra o valor efetivamente aceito quando houver.

A migration inclui índices de comparabilidade por status, veículo e carga, e por data da cotação. Não foi executada e não altera o banco atual.

## Rollback proposto

Após execução autorizada, o rollback seria:

```sh
bin/rails db:rollback STEP=1
```

Somente depois de backup restaurável, confirmação de que a última migration é esta e janela aprovada. Em produção, não executar rollback automático de dados; validar primeiro o impacto dos índices e dos registros escritos.

## Impacto estimado

- 20 colunas nullable em `cotacoes`, majoritariamente strings, inteiros, decimais e um timestamp.
- Dois índices adicionais.
- Sem backfill: registros antigos permanecem nulos.
- Armazenamento exato depende da cardinalidade futura; a estimativa deve ser feita pelo tamanho real da tabela antes da execução.

## Estatística

`FreightPricingStatisticsService` recebe um escopo e filtros de comparabilidade, usa `valor_aceito`, depois `valor_cotado`, e cai para o legado `valor` caso contrário. Calcula quantidade, P25, mediana e P75. O mínimo vem exclusivamente de `config/freight_rates.yml`; atualmente está `null`, portanto não há amostra mínima arbitrariamente definida.

Comparabilidade futura deve considerar veículo/eixos, tipo de carga, distância, peso real, volume/peso cubado, região e demais parâmetros aprovados. A amostra não deve misturar registros incompatíveis.

## Relatório anonimizado

A leitura agregada do banco isolado precisa ser executada em sessão autenticada e registrada somente como contagens/período, sem nomes, endereços, documentos, telefones ou e-mails. O schema atual permite afirmar estruturalmente:

- cotações: valor, status, timestamps e vínculos;
- fretes: origem/destino, peso, volume, dimensões, valores e status;
- distância, duração, peso cubado, peso tarifável, regiões, pedágio, retorno, urgência e versão tarifária ainda não são armazenados nas cotações.

Assim, não é possível formar amostras completas e comparáveis para a nova tabela antes da migration e da coleta futura. Registros antigos podem formar apenas subconjuntos parciais, sem imputação.

## Campos comerciais pendentes

Ainda precisam de aprovação: fator de cubagem por veículo/eixos, bandas de distância, adicionais de peso/volume, pedágio, retorno, urgência, região, carga, piso operacional, fonte/data/versão e mínimo de amostra. Nenhum valor comercial foi inventado.

## Backup e autorização

Antes de executar a migration: backup do banco isolado/produto conforme ambiente autorizado, teste de restauração, registro de schema/migrations, janela de mudança, plano de rollback e aprovação separada. A flag `NATIONAL_FREIGHT_PRICING_ENABLED` permanece `false`.
