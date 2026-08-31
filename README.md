CargaClick - Navegação integrada, offline-safe.

## Atendimentos Gerenciais

O painel administrativo está disponível em `/admin/atendimentos_gerenciais` e exige autenticação de `AdminUser`. A mesma autorização protege o endpoint JSON `GET /admin/atendimentos_gerenciais/data`.

O filtro aceita hoje, últimos 7 ou 30 dias, mês atual, mês anterior e intervalo personalizado de até 366 dias. Todos os intervalos usam o fuso `America/Sao_Paulo` configurado no Rails e são comparados com o período imediatamente anterior de igual duração.

Indicadores e fontes:

- faturamento: soma de `pagamentos.valor` para pagamentos liberados no período;
- clientes ativos: cadastro completo ou frete criado no período;
- transportadores ativos: status ativo ou vínculo com frete criado no período;
- cargas movimentadas e operações: fretes concluídos pela data de entrega;
- ticket médio: faturamento dividido pela quantidade de pagamentos liberados;
- taxa de conversão: fretes concluídos divididos pelos fretes criados;
- leads gerados: registros criados em `leads`;
- crescimento da base: variação percentual do total de clientes e transportadores.

CAC, conversão de campanhas e ROI ficam indisponíveis porque não há investimento, campanha ou atribuição de receita no modelo atual. Taxa e tempo médio de atendimento também ficam indisponíveis porque o sistema não registra abertura e conclusão de atendimentos. O painel nunca substitui esses dados por valores simulados.

Para testar, prepare o banco de teste e execute:

```sh
bin/rails db:test:prepare
bin/rails test test/services/admin/management_metrics_test.rb test/requests/admin_atendimentos_gerenciais_test.rb
```
