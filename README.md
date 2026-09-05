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

## NF-e e seguro de carga

Na área autenticada do transportador, abra um frete disponível ou atribuído e selecione **Seguro da carga**. A nota pode ser lida pela câmera traseira, por uma foto escolhida no aparelho ou pela entrada manual da chave/URL. A permissão da câmera só é solicitada após o clique, o stream é encerrado ao fechar ou sair da tela, e fotos não são enviadas ao servidor nem armazenadas. Sempre há uma confirmação antes de vincular a leitura ao frete.

O QR Code normalmente contém apenas uma chave de 44 dígitos ou um endereço oficial de consulta. O sistema não acessa automaticamente esse endereço, não faz scraping da SEFAZ e não inventa número, emitente ou valor. Dados ausentes precisam ser informados pelo transportador. A chave é mascarada na interface e filtrada dos logs.

O transportador pode recusar o seguro ou consentir com o envio dos dados e pedir uma cotação. A recusa pode ser revista enquanto o frete não começou. Os estados são: `nao_solicitado`, `aguardando_dados`, `aguardando_cotacao`, `cotado`, `contratado`, `recusado` e `erro`. **Uma cotação não representa cobertura**: a interface só mostra “Carga segurada” após uma resposta real do provider, com seguradora, prêmio e número de cotação confirmados.

### Provider de seguros

Por padrão, `INSURANCE_PROVIDER=disabled`: a solicitação fica em `aguardando_cotacao`, sem prêmio, cobrança ou apólice simulada. Uma integração futura deve herdar de `Seguros::Providers::Base`, respeitar timeout, normalizar a resposta e nunca registrar chave completa da NF-e ou documentos fiscais. Configure apenas no ambiente, sem commitar valores:

- `INSURANCE_PROVIDER`
- `INSURANCE_API_URL`
- `INSURANCE_API_KEY`
- `NFE_QRCODE_ALLOWED_HOSTS` (somente hosts oficiais adicionais, separados por vírgula)

Dados enviados mediante consentimento: valor e descrição da carga, origem, destino, peso, tipo de veículo, documento do emitente e indicadores de risco. A operação não guarda a fotografia. Chave e dados fiscais devem ser retidos somente durante o frete e pelos prazos legais/auditáveis aplicáveis; a rotina operacional de retenção deve anonimizar ou excluir esses campos ao fim desse prazo.

Para validar a funcionalidade:

```sh
bundle exec rails db:migrate
bundle exec rails db:migrate RAILS_ENV=test
bundle exec rspec
bundle exec rails routes
bundle exec rails zeitwerk:check
bundle exec rails runner 'puts :ok'
git diff --check
```
