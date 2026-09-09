# Preparação do CargaClick para Fly.io

Atualizado em 2026-09-08. Commit, push normal e deploy no aplicativo existente foram autorizados. Criação de recursos pagos, alteração de DNS e reescrita do histórico não foram autorizadas.

## Destinos confirmados

- GitHub: `https://github.com/Harleysoncim/cargaclick.git` (`origin`).
- Branch de trabalho: `feature/seguro-carga-qrcode-nfe`.
- Branch principal remota: `main`, em `464cbe4ae722c6e2fc498694e3d6d3046fe3cf7d` na consulta. Push nesta branch dispara o workflow Render; a publicação da preparação deve permanecer na branch de trabalho para preservar a produção anterior.
- Fly: aplicativo existente `cargaclick`, organização `personal`, região configurada `gru`, hostname informado `cargaclick.fly.dev`.

## Bloqueios do deploy

A consulta atual ao Fly retornou **nenhuma imagem, nenhuma máquina e nenhum volume**. O único nome de segredo existente é `SECRET_KEY_BASE`. A configuração exige também `DATABASE_URL` e `RAILS_MASTER_KEY`. Nenhum segredo foi criado ou substituído.

Não há versão Fly anterior disponível para rollback. Executar deploy agora dependeria de provisionamento pago e configuração de banco/segredos, fora da autorização atual. Nenhum recurso Fly foi criado, excluído ou modificado.

Antes do deploy, é necessário:

1. Definir e autorizar a máquina e o volume `cargaclick_storage`, com seus custos.
2. Confirmar o destino do banco, backup, compatibilidade do schema e plano para migrar dados e anexos. Não usar banco de produção compartilhado para testes.
3. Configurar os nomes de segredos ausentes pelo canal seguro do provedor, com valores adequados ao destino; nunca copiar valores locais para produção por suposição.
4. Validar as migrations no destino autorizado e somente então habilitar `FLY_MIGRATIONS_ENABLED`. O release permanece bloqueado por padrão.
5. Implantar a imagem inspecionada por digest, sem criar aplicativo ou IP dedicado e sem alterar DNS.

## Configuração preparada

- `Dockerfile.fly`: Ruby 3.2.4, Node 22, instalação Linux das dependências e compilação dos assets.
- `Dockerfile.fly.dockerignore`: contexto com lista de entradas permitidas, excluindo chaves privadas, `.env`, histórico Git, checkout duplicado, caches, logs, dumps e backups. Credenciais Rails criptografadas podem entrar; master key não.
- `fly.toml`: porta 8080, HTTPS, `/up`, volume em `/data`, máquina shared CPU/1 GB e release de migrations com trava.
- `bin/fly-start`: verifica variáveis obrigatórias e volume montado, prepara a pasta de uploads e inicia Puma como usuário `rails`.
- `bin/fly-release`: impede migrations enquanto o destino não estiver aprovado.
- Active Storage usa o volume somente quando executado no Fly; a configuração de armazenamento anterior é preservada nos demais ambientes.

## Correções e validação local

A correção do enum `Frete.status_pagamento` alinha os valores à coluna string e inclui migration para os valores legados. Os testes cobrem persistência e atualização do frete, além da proteção dos campos financeiros do seguro.

Os bundles ActiveAdmin, o acesso à variável do controller no Arbre e o condicional ERB do painel foram corrigidos. Os testes de scaffolds antigos verificam que as rotas retiradas continuam respondendo 404 e não modificam registros. Nenhum teste foi marcado como skip/pending e nenhuma regra de negócio foi relaxada.

Validações repetidas nesta execução, em banco local exclusivo:

| Verificação | Resultado |
| --- | --- |
| Rails Test | 37 testes, 214 assertions, 0 falhas, 0 erros, 0 skips |
| RSpec | 20 exemplos, 0 falhas |
| Painel e métricas administrativas | 7 testes, 19 assertions, 0 falhas/erros/skips |
| Sintaxe | 267 arquivos Ruby e 2 scripts shell aprovados |
| Configuração Fly | `fly config validate` aprovado |
| Boot development/test/production | Aprovado nos três ambientes |
| Banco local | `SELECT 1` aprovado; nenhuma migration pendente no schema local |
| Health local via Rack | `/up` HTTP 200 nos três ambientes |

O banco local foi carregado pelo schema. Isso não certifica a cadeia histórica de migrations nem o estado do banco de produção. Os diagnósticos de boot não usam dotenv nem fazem entregas externas. A validação Docker e o resultado final de publicação são registrados no relatório desta execução.

O CI da branch executa Zeitwerk, RSpec, Rails Test e Playwright, com PostgreSQL efêmero carregado pelo schema. O workflow Render continua restrito a `main` e execução manual.

## Segurança

`DeployRender` e os demais caminhos de chaves comprometidas estão fora do índice. As exclusões já preparadas de artefatos e duplicações foram preservadas. Caches, logs, bancos locais, arquivos temporários e o checkout duplicado permanecem fora da publicação.

As quatro chaves históricas continuam como pendência de identificação e rotação, sem suposição de serviço e sem tentativa de autenticação. Consulte o [inventário sanitizado](security-key-inventory.md). Excluir arquivos em um commit novo não elimina as versões históricas. Não houve force-push, rebase destrutivo, reescrita ou exclusão de cópias locais de credenciais.

Backups e logs locais de validação ficam em `tmp/fly-remediation/`, fora do Git. Não restaurar o backup integral sobre alterações posteriores.

## Produção anterior e pós-deploy

Nenhum deploy Render foi acionado e nenhum DNS foi modificado. Na consulta desta execução, `https://cargaclick.com.br` falhou no handshake TLS e o hostname Fly não resolveu no DNS a partir do ambiente de validação. Essas observações não identificam a causa nem comprovam indisponibilidade para todos os clientes.

As verificações remotas de máquinas, logs, `/up`, home, login, painel, assets, banco e operação essencial continuam pendentes enquanto o Fly não estiver implantado. Após um deploy autorizado, somente considerar a migração pronta com esses itens aprovados. Preservar a produção anterior até validação completa; não fazer rollback automático de schema nem redirecionar DNS nesta etapa.

## Atualização de 2026-09-09: imagem, custos e comandos pendentes

As suítes locais foram repetidas e mantiveram os resultados acima. Há espaço livre novamente, mas o Docker Desktop falha antes de iniciar o engine ao preparar seu disco interno. Não foi formatado ou recriado disco, nem executado prune. O build local anterior terminou, mas a inspeção encontrou `tmp/local_secret.txt`, gerado pelo Rails com chave fictícia. O Dockerfile agora remove esse arquivo e os logs na mesma instrução RUN, antes de gravar a camada; a reconstrução local corrigida e o smoke local permanecem sem aprovação por indisponibilidade do engine.

O workflow `Validate Fly image` faz build com o contexto restrito, inspeciona os arquivos da aplicação em todas as camadas da imagem final (inclusive arquivos posteriormente apagados) e executa o script real `bin/fly-start`. O smoke usa rede interna, PostgreSQL e armazenamento temporários, valores sintéticos e nenhum segredo do GitHub/Fly. Verifica `/up`, home, formulário e login administrativo com CSRF, painel, CSS/JS, banco e persistência/atualização de um frete sintético. Não publica imagem nem realiza deploy. Os arquivos permanentes `test/docker/verify.py` e `smoke.rb` existem para essa validação reproduzível; os diagnósticos de `tmp/fly-audit/` continuam ignorados.

A alteração preexistente em `.github/workflows/deploy.yml` foi preservada somente na árvore local e ficou fora do commit, conforme a instrução de não alterar o deploy Render.

### Estimativa sujeita a autorização

Preços oficiais consultados em 2026-09-09, em dólares, sem impostos, câmbio, tráfego, excedentes ou recursos transitórios de release/build:

| Recurso proposto | Estimativa por mês |
| --- | ---: |
| Uma máquina shared-cpu-1x, 1 GB, ligada continuamente em gru | US$ 9,20 |
| Volume de uploads de 1 GB | US$ 0,15 |
| Managed Postgres Basic, caso escolhido | US$ 38,00 |
| Armazenamento do banco de 10 GB | US$ 2,80 |
| Total com esse banco novo | **US$ 50,15** |
| Máquina + volume, se houver banco externo aprovado | **US$ 9,35**, além do custo do banco |

Fontes: [preços Fly por região e armazenamento](https://fly.io/docs/about/pricing/) e [Managed Postgres](https://fly.io/docs/mpg/). Snapshots custam US$ 0,08/GB/mês após a franquia inicial de 10 GB da organização. Tráfego é variável. Os tamanhos acima são uma proposta mínima para orçamento, não garantia de capacidade ou alta disponibilidade; devem considerar o volume real de dados e uploads.

### Comandos propostos — não executados

Somente após aprovar custo, capacidade, banco de destino, migração dos dados/anexos e credenciais corretas:

```sh
# Somente se a decisão for criar um banco gerenciado novo.
# Selecionar o plano Basic no assistente e conferir a cotação antes de confirmar.
fly mpg create --org personal --name cargaclick-db --region gru --volume-size 10

# Criar somente o volume aprovado no app já existente.
fly volumes create cargaclick_storage --app cargaclick --region gru --size 1

# Importar exclusivamente os valores de produção já verificados, via entrada
# segura. Não colocar valores em argumentos, histórico do shell ou Git.
fly secrets import --stage --app cargaclick

# Conferências somente por nomes e estado.
fly secrets list --app cargaclick
fly ips list --app cargaclick

# Apenas se ainda não houver endereços e após aprovação do plano de rede:
fly ips allocate-v6 --app cargaclick
fly ips allocate-v4 --shared --app cargaclick

# A imagem deverá ser construída, inspecionada e enviada ao registry do app
# antes deste comando. DIGEST_VALIDADO é um marcador, não um valor real.
# Habilitar migrations somente após backup e teste no banco aprovado.
fly deploy --app cargaclick --config fly.toml \
  --image registry.fly.io/cargaclick@sha256:DIGEST_VALIDADO \
  --ha=false --env FLY_MIGRATIONS_ENABLED=true

fly status --app cargaclick
fly checks list --app cargaclick
```

Os segredos ausentes são `DATABASE_URL` e `RAILS_MASTER_KEY`. O responsável deve confirmar a conexão do banco correto, a chave correspondente às credenciais criptografadas e o plano de transferência dos dados. Integrações de pagamento, e-mail e mapas também precisam ser confirmadas antes de uso real; nenhum valor será inventado ou copiado por suposição.

O primeiro deploy criará uma máquina e uma máquina temporária de release, gerando cobrança. Não existe release Fly anterior para rollback; em uma primeira tentativa malsucedida, manter o Render e o DNS atuais, sem migrar tráfego. Em deploys posteriores, registrar a imagem estável anterior e usá-la na reversão de aplicação, sem rollback automático do schema.
