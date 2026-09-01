# Plano seguro para rotação das credenciais de desenvolvimento

## Situação

`config/credentials/development.yml` continha configuração local para serviço externo e esteve presente no histórico Git remoto. Não foi possível determinar com segurança se algum valor foi reutilizado em staging ou produção; por isso a classificação é **D** e nenhuma rotação foi executada automaticamente.

O arquivo foi preservado localmente e removido apenas do rastreamento. Arquivos Rails criptografados (`*.yml.enc`) não fazem parte desta remoção.

## Procedimento proposto

1. Identificar, no painel do serviço externo, a credencial correspondente sem copiá-la para tickets, logs ou documentos.
2. Consultar responsáveis por desenvolvimento, staging e produção para confirmar em quais ambientes a credencial está configurada.
3. Verificar somente por comparação segura de fingerprints/hashes ou identificadores oferecidos pelo provedor, nunca pelo valor em texto claro.
4. Caso seja exclusivamente de desenvolvimento, criar uma credencial substituta com menor privilégio, restrições e quota próprias.
5. Caso seja compartilhada com staging ou produção, preparar credenciais distintas por ambiente e uma janela coordenada de troca.
6. Atualizar primeiro o ambiente de desenvolvimento por variável de ambiente ou mecanismo local ignorado pelo Git.
7. Validar as integrações em desenvolvimento e staging antes de qualquer mudança em produção.
8. Para produção, solicitar autorização específica, atualizar o segredo no provedor de hospedagem e observar inicialização, erros e métricas.
9. Revogar a credencial antiga somente depois de confirmar que todos os ambientes autorizados usam as novas credenciais.
10. Verificar no painel do serviço externo histórico de uso, origens inesperadas, quotas e possíveis abusos.
11. Manter exemplos apenas com nomes de variáveis e placeholders; nunca incluir valores reais.
12. Registrar data, responsáveis, ambientes atualizados e evidência de revogação sem armazenar os segredos.

## Histórico Git

Este plano não propõe reescrita de histórico, `git filter-repo` ou force push. A remoção em um novo commit impede exposição futura no estado atual da branch, mas não apaga versões anteriores. A credencial deve ser tratada como potencialmente conhecida por terceiros até ser revogada pelo provedor.

## Produção

Nenhuma credencial de produção, `RAILS_MASTER_KEY`, `config/credentials.yml.enc`, banco, infraestrutura ou serviço deve ser alterado sem autorização separada e plano de rollback.
