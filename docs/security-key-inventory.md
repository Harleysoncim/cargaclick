# Inventário sanitizado de chaves históricas

Data: 2026-09-08. Todas são tratadas como comprometidas. Nenhuma foi usada para autenticar, copiada, revogada ou rotacionada nesta tarefa.

| Caminho sanitizado | Fingerprint pública | Working tree | Índice atual | Classificação |
| --- | --- | --- | --- | --- |
| `DeployRender` | `SHA256:1BVximoX2ZkB+gODHsFD6ubp3rg05xoa1rSK0B0tr48` | Ausente | Ausente | Associação desconhecida |
| `harleyjosesoncim` | `SHA256:ydm10XLDQ2pyP0EBT4KgaTZw5zfGztT3OI/l2Ia9fmM` | Ausente | Ausente | Associação desconhecida |
| `1234` | `SHA256:PW/qRCCrSRSqVzmy+xrqdIUFZEqAyFOG7yd4m+Dj15s` | Ausente | Ausente | Associação desconhecida |
| `[NOME_SANITIZADO]` | `SHA256:+npaPiqNC7/g11B022t4y8OgECnvl16nb1724yVLdDk` | Ausente | Ausente | Associação desconhecida |

`DeployRender` estava no índice e foi retirado somente do rastreamento. A exclusão de `harleyjosesoncim` já estava preparada pelo usuário. Os outros dois estavam apenas no histórico. Não houve cópia local dessas quatro chaves a mover ou apagar.

A primeira chave possui contêiner criptografado; isso não muda o tratamento de comprometimento. Nenhuma das fingerprints correspondeu aos arquivos públicos `*.pub` disponíveis em `/home/harley/.ssh`. Não foram lidas chaves privadas desse diretório.

As únicas referências históricas textuais encontradas foram `README.md:47` (blob `3a582b122f94`) e `render.yaml:6` (blob `2efb4c5d0316`) para o nome `harleyjosesoncim`. Um nome/referência não comprova vínculo com credencial de serviço nem uso ativo. Não se inferiu que `DeployRender` pertence ao Render apenas por seu nome. GitHub/Render/servidores não foram autenticados com essas chaves.

## Commits que alteraram os caminhos

Esta lista inclui inclusão, modificação ou remoção; não implica que a chave permaneça na árvore de cada commit. O histórico ainda é acessível.

### DeployRender

- `e9c9d9d65dcb5163f71e336e3091ddfe81e3c1f1 2025-09-20`
- `28fcd1bdfaef262e57274c6c966b5466218dc1d1 2025-07-10`

### harleyjosesoncim

- `e9c9d9d65dcb5163f71e336e3091ddfe81e3c1f1 2025-09-20`

### 1234

- `4dfbe49113d014c0c25d41121e97a3c6a7e2468e 2026-02-06`
- `e9c9d9d65dcb5163f71e336e3091ddfe81e3c1f1 2025-09-20`
- `28fcd1bdfaef262e57274c6c966b5466218dc1d1 2025-07-10`

### [NOME_SANITIZADO]

- `93827e6a6cc4bc3673946a4ad34e13053ace0580 2026-01-19`
- `e9c9d9d65dcb5163f71e336e3091ddfe81e3c1f1 2025-09-20`

## Referências locais cujo histórico é afetado

Inventário das referências disponíveis localmente, sem afirmar que cobre forks, refs de PR ou branches remotas não buscadas.

- `refs/heads/codex/pr3-playwright-fix`
- `refs/heads/feature/atendimentos-gerenciais`
- `refs/heads/feature/mobile-android-ios`
- `refs/heads/feature/seguro-carga-qrcode-nfe`
- `refs/heads/main`
- `refs/remotes/origin/HEAD`
- `refs/remotes/origin/chore/deploy-docker-runtime`
- `refs/remotes/origin/chore/health-robots-sentry`
- `refs/remotes/origin/chore/seo-basico`
- `refs/remotes/origin/chore/seo-sitemap`
- `refs/remotes/origin/feature/atendimentos-gerenciais`
- `refs/remotes/origin/feature/cadastro-publico-transportador-email`
- `refs/remotes/origin/feature/mobile-android-ios`
- `refs/remotes/origin/feature/seguro-carga-qrcode-nfe`
- `refs/remotes/origin/fix-navbar-navigation`
- `refs/remotes/origin/fix/precompile-mp-token`
- `refs/remotes/origin/flyio-new-files`
- `refs/remotes/origin/main`
- `refs/remotes/origin/recovery`
- `refs/tags/v0.1.0`
- `refs/tags/v1.0-stable-no-500`
- `refs/tags/v1.0-stable-ui`

## Confirmação necessária

Para cada fingerprint, o responsável deve informar o serviço/servidor/conta, onde a credencial é consumida e se existe substituta validada. Até isso ser confirmado, o estado permanece associação desconhecida e potencialmente em uso; rotação suspensa. Não enviar material privado para o chat.

## Plano de substituição sem indisponibilidade

Após identificar o serviço, apresentar autorização específica com fingerprint antiga, conta/serviço, consumidor e teste de acesso limitado. Para GitHub, identificar se é chave de conta, deploy key ou token; para SSH, identificar usuário e servidor; para Render/Fly, confirmar o mecanismo real, sem presumir que uma chave SSH seja token da API.

Depois da autorização: gerar nova credencial fora do repositório com permissões restritas; instalar a parte pública/credencial no serviço; testar a substituta no serviço confirmado sem imprimir valores; atualizar o consumidor; verificar produção e deploy; somente então revogar a antiga. Registrar apenas fingerprint, serviço, data e status. Nenhuma etapa externa foi executada.

## Limpeza do histórico — proposta não executada

1. Primeiro substituir as credenciais e confirmar acesso. Congelar pushes coordenadamente e inventariar também refs remotas, PRs, tags e forks.
2. Após autorização, preparar espelho de backup cifrado/restrito fora do projeto e verificar sua restauração. O backup realizado nesta tarefa contém apenas código local; não é um espelho dos segredos.
3. Em clone descartável novo, revisar os caminhos e confirmar que o padrão sanitizado abaixo corresponde exclusivamente ao quarto nome comprometido. Não incluir seu nome literal em comandos ou relatórios.

```bash
# Proposta somente; requer autorização explícita antes de executar.
git filter-repo --sensitive-data-removal --invert-paths \
  --path DeployRender --path harleyjosesoncim --path 1234 \
  --path-regex '^ghp_[A-Za-z0-9]{36}$'
```

4. O comando remove as quatro ocorrências por caminho/padrão; classificar separadamente os candidatos históricos em `connect_render.sh`, `config/database.yml` e `Dockerfile` antes de declarar saneamento completo. Não eliminar esses arquivos inteiros por alertas não confirmados.
5. Comparar árvores de código, escanear todos os blobs e validar testes. Commits descendentes terão hashes novos; assinaturas e referências a hashes antigos precisarão ser revisadas. Não executar a ferramenta no checkout compartilhado atual.
6. Solicitar nova aprovação específica para atualizar refs no servidor. A reescrita normalmente exige push forçado; essa autorização NÃO foi dada. Não foi executado force push, rebase destrutivo ou reescrita.
7. Todos os colaboradores, forks e worktrees antigos precisarão clonar novamente ou realinhar sem reintroduzir commits contaminados. O log local registra Harley Jose Soncim/Harley José Soncim/Harley Soncim, Seu Nome e Fly.io; isso não identifica todos os colaboradores ou operadores de CI, que precisam ser confirmados pelo proprietário.
8. Antes de publicar a reescrita, reversão significa abandonar o clone descartável e manter o original. Depois de publicar, restaurar refs do backup pode reexpor segredos e exige decisão coordenada e nova autorização. Nunca publicar o backup nem reativar credenciais revogadas.

A publicação normal de novos commits foi autorizada pelo usuário, mantendo o incidente histórico como pendência. Isso não autoriza limpar ou sobrescrever histórico. Remoção em um commit novo não apaga as versões antigas.

Referências: [procedimento GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) e [manual git-filter-repo](https://github.com/newren/git-filter-repo/blob/main/Documentation/git-filter-repo.txt).
