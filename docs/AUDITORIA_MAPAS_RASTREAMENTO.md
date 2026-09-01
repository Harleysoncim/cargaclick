# Auditoria de mapas, rotas e rastreamento — CargaClick

**Data da auditoria:** 1º de setembro de 2026  
**Escopo:** aplicação Rails em `cargaclick_repo` (frontend server-rendered/JavaScript, backend, schema/migrações, configuração e testes).  
**Método:** inspeção estática completa por termos geoespaciais e de tempo real, rastreamento das referências entre rotas/controllers/views/assets, validação de sintaxe Ruby e tentativa segura de inicialização. Nenhuma chamada com coordenadas reais, escrita em banco de produção, commit, push ou deploy foi realizada.

## Resumo objetivo da situação atual

**Categoria encontrada: A — não possui mapas nem rotas funcionais no sistema atual.**

Há código experimental/dormente que pode causar a impressão de uma solução mais avançada: Leaflet e assets do OpenStreetMap estão instalados; existem quatro implementações backend parciais para consultar o OpenRouteService (ORS); há um JavaScript legado com mapa, linha de rota e marcador fictícios; e existe um esqueleto de canal Action Cable chamado `RastreamentoChannel`. Porém, essas peças não formam uma funcionalidade operacional:

- a tela atual de rastreamento não contém mapa e informa estar em modo `offline-safe`;
- nenhuma view atual contém o elemento `#map` necessário para inicializar o Leaflet;
- o JavaScript legado de rastreamento não é importado pelo bundle principal usado pelo layout;
- origem, destino e transportador no protótipo são coordenadas fixas de demonstração, não dados do frete;
- não existe endpoint para receber ou consultar localização;
- não existem latitude/longitude, posições ou histórico de percurso no banco;
- não existe captura de GPS (`navigator.geolocation`, `watchPosition` ou equivalente);
- não existe produtor/broadcast de posições e o consumidor Action Cable está vazio;
- não existe autorização adequada no canal de rastreamento;
- a simulação de frete pode consultar o ORS para geocodificação e distância, mas, sem a variável esperada, substitui silenciosamente o resultado por uma distância aleatória; o tempo é apenas uma estimativa `distância / 60`, não o tempo calculado pela rota.

Assim, o CargaClick tem **experimentos de mapa e cálculo de distância**, mas não possui hoje mapa, desenho de rota, navegação ou rastreamento funcional de produção. A categoria A é a classificação da experiência realmente executável, não da mera presença de arquivos.

## As seis capacidades, claramente diferenciadas

| Capacidade | Situação atual | Evidência/observação |
|---|---|---|
| 1. Exibir um mapa | **Inexistente na UI atual** | A view `app/views/fretes/rastreamento.html.erb` contém apenas texto; nenhuma view contém `id="map"`. Leaflet/OSM existem como dependências e protótipo não conectado. |
| 2. Calcular e desenhar uma rota | **Incompleta e não operacional de ponta a ponta** | `CalcularFrete` tenta geocodificar e obter distância pelo ORS. `RoteirizacaoService` obtém distância/duração, mas não é usado. O desenho de polyline só existe em JS legado com pontos fixos. Não há geometria persistida nem apresentada ao usuário. |
| 3. Abrir navegação no Google Maps ou Waze | **Inexistente** | Nenhum deep link/URL para Google Maps, Waze, `geo:` ou esquema nativo foi encontrado. |
| 4. Receber a localização do celular | **Inexistente** | Não há uso da API de geolocalização nem endpoint autenticado de ingestão. |
| 5. Acompanhar o transportador em tempo real | **Inexistente** | Há apenas um canal Action Cable vazio e inseguro, sem publicação, assinatura por frete correta no cliente ou atualização de mapa. O polling legado aponta para uma rota inexistente. |
| 6. Armazenar o histórico da viagem | **Inexistente** | Schema e migrações não têm tabela/campos de posições, eventos ou trilha GPS. |

## Matriz detalhada de funcionalidades

| Funcionalidade solicitada | Estado | Detalhe |
|---|---|---|
| Exibir mapa | Inexistente operacionalmente | Protótipo Leaflet dormente. |
| Mostrar origem e destino | Parcial | Mostra as strings no frete/tela de rastreamento; marcadores só existem no protótipo com coordenadas fictícias. |
| Endereço → coordenadas | Parcial/dormente | ORS em serviços backend; Nominatim no JS principal, mas o gatilho depende de elementos que nenhuma view possui. Coordenadas não são guardadas. |
| Calcular distância | Parcial e não confiável | ORS quando configurado; fallback aleatório quando ausente/erro. Há três serviços divergentes e dois nomes de variável de ambiente. |
| Calcular tempo estimado | Parcial e impreciso | `CalcularFrete` usa velocidade fixa de 60 km/h. A duração real do ORS é lida por `RoteirizacaoService`, que não tem chamador. |
| Traçar rota origem–destino | Inexistente operacionalmente | Polyline apenas no protótipo fixo. |
| Múltiplas paradas | Inexistente | Sem modelo, formulário ou waypoints. |
| Recalcular rota | Inexistente | Sem posição atual, detecção de desvio ou nova solicitação de rota. |
| Abrir Google Maps/Waze | Inexistente | Sem links universais/deep links. |
| Localização atual do transportador | Inexistente | Marcador fictício no protótipo. |
| Atualização em tempo real | Inexistente | Polling legado a cada 15 s consulta endpoint inexistente; Action Cable não está implementado de ponta a ponta. |
| Histórico do percurso | Inexistente | Sem tabela/modelo/API. |
| Transportador no mapa do cliente/gestor | Inexistente | Sem mapa, autorização ou audiência. |
| Chegada/parada/atraso/desvio | Inexistente | Sem eventos, regras, geofences ou comparação com rota/ETA. |

## Bibliotecas e serviços encontrados

### Presentes

- **Leaflet 1.9.4**, em `package.json`, importado por `app/javascript/application.js`.
- **OpenStreetMap raster tiles**, referenciado por Leaflet em `app/javascript/application.js` e no protótipo `app/javascript/rastreamento.js`.
- **Nominatim público**, chamado diretamente do navegador para busca por CEP no JS principal.
- **OpenRouteService (ORS)**, usado ou esboçado em:
  - `app/services/calcular_frete.rb`;
  - `app/services/roteirizacao_service.rb`;
  - `app/services/route_distance_service.rb`;
  - `lib/open_route_service.rb`;
  - `app/javascript/rastreamento.js`.
- **Rails Action Cable**, com `@rails/actioncable`, `config/cable.yml` e canal `RastreamentoChannel`.
- **Redis**, configurável por `REDIS_URL` para Action Cable em produção; o fallback é `async` quando Redis não está configurado.

### Não encontrados

Google Maps SDK/API, Mapbox, HERE Maps, Socket.IO, Server-Sent Events/EventSource, bibliotecas de geofencing/map matching, SDK de navegação móvel e provedor comercial de tiles OSM.

## Arquivos, componentes, endpoints e tabelas envolvidos

### Frontend

- `app/views/fretes/rastreamento.html.erb`: tela atual sem mapa; exibe somente origem/destino em texto.
- `app/javascript/application.js`: carrega Leaflet e contém geocodificação Nominatim condicionada a `#cep_input`, `#endereco_input` e `#map`; esses três elementos não coexistem em nenhuma view atual.
- `app/javascript/rastreamento.js`: protótipo não conectado, com coordenadas fictícias, rota ORS, marcador fictício e polling para endpoint inexistente.
- `app/javascript/packs/application.js`: importa o protótipo, mas esse pack não é incluído pelo layout atual.
- `app/javascript/channels/rastreamento_channel.js`: assinatura sem `frete_id` e callbacks vazios; além disso, `app/javascript/channels/index.js` não a importa.
- `app/views/layouts/application.html.erb`: inclui o bundle `application` e CSS Leaflet, mas não o pack legado.
- `app/assets/stylesheets/leaflet.css` e imagens de marcadores: assets locais presentes.
- `app/views/shared/_frete_cards.html.erb`: oferece link “Rastreamento” ao transportador, mas leva à tela textual.

### Backend e rotas

- `GET /fretes/:id/rastreamento` → `FretesController#rastreamento`: existe, mas a rota não está dentro de um bloco autenticado e o controller apenas busca o frete pelo ID.
- **Não existe** `GET /fretes/:id/localizacao_transportador`, embora o JS legado tente chamá-lo.
- **Não existe** endpoint `POST/PATCH` para receber coordenadas do aplicativo/transportador.
- `app/controllers/fretes_controller.rb`: chama `CalcularFrete` na simulação e não aplica autenticação/autorização a `show`, `chat` ou `rastreamento`.
- `app/services/calcular_frete.rb`: serviço efetivamente chamado; usa `OPENROUTESERVICE_API_KEY`, distância ORS ou fallback aleatório, e ETA simplificado.
- `app/services/roteirizacao_service.rb`: implementação melhor de distância e duração ORS, mas sem chamadas encontradas; usa `ORS_API_KEY`.
- `app/services/route_distance_service.rb`: sem chamadas encontradas; usa `ORS_API_KEY` e espera uma forma de resposta diferente da solicitação GeoJSON usada.
- `lib/open_route_service.rb` e `SimuladorController`: código desconectado das rotas atuais.
- `app/channels/rastreamento_channel.rb`: faz `stream_from` usando parâmetro fornecido pelo cliente, sem validar usuário, frete ou vínculo.
- `app/channels/application_cable/connection.rb`: não identifica/autentica a conexão.

### Banco de dados

- `fretes` contém apenas `origem` e `destino` como strings e vínculo opcional a `transportador`.
- `transportadores` contém endereço/CEP/cidade, mas nenhuma coordenada.
- Não há campos `latitude`, `longitude`, `accuracy`, `speed`, `heading`, `captured_at` ou localização atual.
- Não há tabela de posições, viagens, paradas, eventos de rastreamento, geofences ou histórico de percurso.
- As tabelas `historico_emails`, `historico_posts` e `historico_propostas` não são histórico geográfico.

### Tempo real e processos agendados

- Action Cable está configurado, mas não há nenhum `ActionCable.server.broadcast`, `broadcast_to` ou produtor equivalente para rastreamento.
- Não há SSE nem Socket.IO.
- `config/schedule.rb` agenda apenas sitemap e limpeza de logs; nenhum processo atualiza posições.
- Os jobs existentes tratam alerta de pré-cadastro e pagamentos, não localização.

## Configuração de chaves e dependências externas

- O código usa **dois nomes incompatíveis** para a mesma finalidade: `OPENROUTESERVICE_API_KEY` e `ORS_API_KEY`.
- Nenhum deles está documentado no `.env.example`; uma implantação pode cair silenciosamente no resultado aleatório.
- `app/javascript/rastreamento.js` contém uma chave ORS escrita diretamente no código. O valor foi deliberadamente omitido deste relatório. Deve ser considerado comprometido, revogado/rotacionado e removido antes de qualquer reutilização.
- Chaves de rota/geocodificação devem permanecer no backend, com restrições de domínio/IP/serviço, quotas e alertas; nunca no bundle público, salvo tokens especificamente desenhados e restringidos para cliente.
- Tiles OSM, Nominatim e ORS são dependências de rede externas. A tela atual evita essas dependências, mas o protótipo e o cadastro planejado não têm SLA ou fallback real de provider.

## Testes seguros realizados

| Teste | Resultado |
|---|---|
| Busca global no frontend/backend/schema/migrações/testes por latitude, longitude, geolocation, location, tracking, route/rota, mapa, origem, destino, motorista, transportador, GPS, WebSocket, Socket.IO e tempo real | Encontrou os protótipos/serviços descritos; não encontrou ingestão GPS, campos/tabelas de posição, deep links, SSE/Socket.IO ou eventos operacionais. |
| Rastreamento de rotas → controller → view → JavaScript | Confirmou tela textual, protótipo fora do bundle e endpoint de polling inexistente. |
| Busca por elemento HTML `#map` e IDs exigidos pelo JS | Nenhuma view atual fornece o elemento necessário; Leaflet não inicializa mapa. |
| Inspeção do `db/schema.rb` e de todas as migrações | Nenhum campo lat/lon nem tabela de posições/histórico. |
| Busca por broadcast/producer Action Cable | Nenhum publicador de localização encontrado. |
| Inspeção de autenticação/autorização | Canal sem identidade/autorização; rota de rastreamento e leitura de frete sem proteção específica. |
| Validação `ruby -c` dos serviços e canal centrais | `Syntax OK` para `calcular_frete.rb`, `roteirizacao_service.rb` e `rastreamento_channel.rb`. |
| Inicialização Rails, listagem de rotas e runner de inspeção | Não executados: `bundle exec rails` falhou porque os executáveis/gems Rails não estão instalados neste checkout. Nenhuma instalação foi feita. |
| Teste visual das telas via navegador local | Não realizável sem servidor Rails inicializável. A conclusão sobre a tela é baseada na view e no encadeamento de assets, não em alegação de teste visual bem-sucedido. |
| Testes automatizados de rastreamento | O único teste de canal está inteiramente comentado; não existe cobertura funcional de mapas/rotas/rastreamento. |

Observação de qualidade: `app/views/fretes/resultado.html.erb` contém código de controller Ruby em vez de template de resultado. Isso torna o fluxo visual de simulação suspeito e precisa ser corrigido/testado em uma etapa própria antes de validar o cálculo pela interface.

## Riscos técnicos e de segurança

### Críticos

1. **Chave ORS exposta no repositório/bundle legado.** Rotacionar e verificar uso indevido; não basta apagar do arquivo porque permanece no histórico Git.
2. **Ausência de autorização no rastreamento.** `GET /fretes/:id/rastreamento` aceita IDs e o canal aceita `frete_id` fornecido pelo cliente sem verificar se o usuário é o cliente, transportador vinculado ou gestor autorizado.
3. **Canal Action Cable sem autenticação.** `ApplicationCable::Connection` não identifica usuário; se o broadcast for ativado como está, há risco de enumeração e espionagem de localização.
4. **Resultados comerciais não determinísticos.** Na falta/falha da chave ORS, a distância é aleatória e influencia preço e tempo. O usuário não é informado de que é estimativa fictícia.

### Altos/médios

- Cinco implementações geoespaciais divergentes aumentam manutenção, erros de formato e inconsistência de variáveis de ambiente.
- A chamada direta ao Nominatim público não envia identificação explícita do aplicativo, não possui proxy/cache e não é adequada para escala de rastreamento/comercial.
- O tile server público do OSM é best-effort, sem SLA e pode bloquear uso pesado; não deve ser tratado como CDN gratuita de produção.
- O fallback `async` do Action Cable em produção não distribui mensagens entre múltiplos processos/instâncias; rastreamento exigirá Redis (ou serviço gerenciado equivalente).
- Polling fixo a cada 15 s, se ativado, escala mal, consome bateria/dados e não trata aba oculta, backoff ou falha prolongada.
- Ausência de timeouts em algumas chamadas ORS pode prender workers; apenas `RoteirizacaoService` define timeouts.
- Sem idempotência, limites por usuário/dispositivo, validação de plausibilidade, proteção contra replay ou antifraude de coordenadas.
- Sem política de retenção, transparência, registro de consentimento/base legal, auditoria de acesso ou procedimento de exclusão LGPD.
- Origem/destino e localização são dados pessoais/contextuais; logs e broadcasts podem vazar rotinas, residência e carga valiosa.

## Custos e limitações atuais dos serviços

Valores e políticas abaixo foram consultados em 1º de setembro de 2026 e devem ser reconfirmados antes da contratação.

- **OpenStreetMap:** os dados são abertos, mas os servidores públicos de tiles não são um serviço gratuito ilimitado; são best-effort, sem SLA e podem bloquear uso inadequado. Para produção, contratar um provedor de tiles OSM ou hospedar infraestrutura própria. Fonte: [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).
- **Nominatim público:** máximo absoluto de 1 requisição/s, identificação e atribuição obrigatórias, cache recomendado e sem uso pesado. A política destaca restrições para aplicações comerciais/de rastreamento e proíbe enviar dados pessoais/confidenciais. O uso direto atual não é base adequada para escala. Fonte: [OSMF Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/).
- **OpenRouteService:** o plano público tem limites de requisição, distância, waypoints e área; excedentes exigem infraestrutura própria ou acordo com o provedor. O custo direto pode ser zero dentro do plano, mas isso não equivale a SLA ou capacidade ilimitada. Fontes: [restrições oficiais do ORS](https://openrouteservice.org/restrictions/) e [planos](https://openrouteservice.org/plans/).
- **Google Maps Platform:** pay-as-you-go por evento, com franquias por SKU. Em 2026, Maps SDK móvel aparece com franquia ilimitada, enquanto Dynamic Maps tem 10 mil cargas/mês gratuitas e depois parte de US$ 7/1.000; Compute Routes Essentials e Geocoding têm 10 mil eventos/mês gratuitos e depois partem de US$ 5/1.000. Há também assinaturas (por exemplo, Starter de US$ 100/mês para 50 mil chamadas combinadas). Fonte: [tabela oficial de preços](https://developers.google.com/maps/billing-and-pricing/pricing) e [visão geral de assinaturas](https://developers.google.com/maps/billing-and-pricing/overview).
- **Mapbox:** em 2026, SDKs móveis de mapas têm até 25 mil MAU gratuitos; Mapbox GL JS até 50 mil cargas; Directions e Optimization até 100 mil requisições gratuitas, com faixas pagas posteriores. Navigation SDK v3 inclui até 100 MAU e 1.000 viagens gratuitas, depois cobra por usuário e viagem. Uso veicular pode exigir licença comercial específica, portanto é obrigatório confirmar com vendas/termos. Fonte: [preços oficiais Mapbox](https://www.mapbox.com/pricing).

Custos de rastreamento não se limitam ao mapa: Redis/WebSocket, banco de séries temporais/particionamento, armazenamento/backup, observabilidade, transferência de dados, notificações, suporte e revisão jurídica/LGPD devem entrar no orçamento.

## Impacto na futura versão Android e iOS

- A camada geoespacial deve ser projetada como API de domínio independente do Rails server-rendered, para servir web, Android e iOS com o mesmo contrato.
- O aplicativo do transportador será o produtor confiável de amostras de localização durante uma viagem ativa; o navegador atual não substitui background location móvel.
- Android e iOS exigem fluxos distintos de permissão, indicadores de uso, políticas de loja e restrições severas de execução em segundo plano.
- O app precisa de fila local durável e reenvio idempotente; conexão móvel intermitente é o caso normal, não exceção.
- Deep links para Google Maps/Waze são uma função separada e simples; navegação turn-by-turn embutida é outra iniciativa, com SDK, licença e consumo de bateria próprios.
- Cliente e gestor podem continuar usando web inicialmente, recebendo atualizações autorizadas via WebSocket e fallback de polling/SSE.
- A escolha do mapa deve ser encapsulada: coordenadas, viagens e eventos pertencem ao CargaClick; tiles/geocoding/routing são adapters substituíveis.

## Plano técnico proposto — sem implementação

### 1. Modelo de domínio e ciclo explícito

Criar uma entidade `viagens` vinculada a `frete`, cliente e transportador, com estados como `planejada`, `rastreamento_ativo`, `pausada`, `concluida` e `cancelada`. O rastreamento só começa após ação explícita “Iniciar viagem” do transportador e termina por “Concluir viagem”, cancelamento autorizado ou regra operacional auditável. Não coletar GPS fora de viagem ativa.

Separar:

- `viagens`: estado, início/fim, rota planejada, ETA e consentimento/aviso apresentado;
- `posicoes_viagem`: latitude/longitude, precisão, velocidade, direção, altitude opcional, `captured_at` do aparelho, `received_at` do servidor, sequência/idempotency key e fonte;
- `eventos_viagem`: chegada, saída, parada, atraso, desvio, perda/retorno de sinal e mudanças de estado;
- localização atual materializada/cacheada: última posição válida por viagem para leitura rápida, sem substituir o histórico.

### 2. Captura no aplicativo do transportador

- Solicitar localização **durante o uso** no momento em que uma funcionalidade necessita dela.
- Solicitar localização **em segundo plano somente** quando o produto provar que o rastreamento precisa continuar com tela bloqueada/app fora do primeiro plano durante viagem ativa. Explicar claramente finalidade e oferecer controle visível.
- Android: foreground service persistente durante viagem ativa, notificação obrigatória e tratamento de Doze/battery optimization conforme políticas vigentes.
- iOS: background location mode apenas para viagem ativa, indicador do sistema e configuração de precisão/distância apropriada.
- Nunca iniciar silenciosamente no login ou boot; retomar somente uma viagem que o próprio usuário iniciou e ainda está ativa, com sinalização clara.

### 3. Frequência, bateria e dados

Perfil inicial recomendado, calibrado por testes de campo:

- em movimento e viagem ativa: amostra a cada **15–30 segundos** ou **100–250 m**, o que ocorrer depois/segundo estratégia adaptativa;
- parado: reduzir para **2–5 minutos** após detecção consistente, mantendo eventos de mudança significativa;
- próximo de coleta/entrega: temporariamente **10–15 segundos** para geofence/chegada;
- app em foreground com mapa: pode atualizar a animação local mais frequentemente sem necessariamente enviar cada amostra;
- enviar lotes comprimidos (por exemplo, até 20–50 pontos) e adaptar por velocidade, precisão, bateria baixa e qualidade da rede.

Descartar/rebaixar pontos com precisão ruim, limitar precisão excessiva quando desnecessária e medir consumo real em rotas urbanas/rodoviárias antes de fixar parâmetros.

### 4. API segura de ingestão

Exemplo de contrato: `POST /api/v1/viagens/:id/posicoes/batch`.

- autenticação de transportador/dispositivo com tokens curtos e rotacionáveis;
- autorização server-side: viagem ativa e pertencente ao transportador autenticado;
- TLS obrigatório, rate limit, tamanho máximo de lote e validação de latitude/longitude/timestamps;
- idempotency key + sequência por dispositivo para reenvio seguro e ordenação;
- rejeitar timestamps futuros/antigos fora da janela, saltos impossíveis e payloads malformados;
- não aceitar `transportador_id` como autoridade fornecida pelo cliente;
- logs sem coordenadas completas/tokens; trilha de auditoria de acessos à localização;
- considerar attestation do dispositivo como camada antifraude, sem tratá-la como prova absoluta de GPS legítimo.

### 5. Perda de internet e retomada

O app armazena amostras em fila local criptografada, marcada por viagem e sequência. Sem rede, continua coletando dentro das regras; ao voltar, envia em lotes ordenados com backoff exponencial e jitter. O servidor confirma até qual sequência persistiu. Limitar tamanho/idade da fila e mostrar estado “sem conexão — posições pendentes”. Encerramento da viagem deve tentar flush e permitir conclusão controlada com pendências claramente registradas.

### 6. Persistência e retenção

- PostgreSQL é suficiente para o MVP, idealmente com PostGIS para distância, geofences e índices espaciais; particionar `posicoes_viagem` por mês quando o volume justificar.
- Índices mínimos: `(viagem_id, captured_at)`, idempotency key única por viagem/dispositivo e índice espacial se PostGIS.
- Cache da última posição em Redis para fan-out rápido; PostgreSQL continua sendo fonte auditável.
- Proposta inicial de retenção: posições detalhadas por **90 dias após conclusão**, depois apagar ou agregar/anonimizar; eventos comerciais mínimos podem seguir prazo fiscal/contratual separado. Validar o prazo com jurídico/DPO, finalidade e obrigações de disputa/seguro.
- Implementar rotina de exclusão verificável, legal hold controlado, exportação do titular e métricas sem coordenadas identificáveis.

### 7. Atualização de cliente e gestor

Após persistir a posição, publicar somente a última posição sanitizada em canal por viagem. Usar Action Cable + Redis inicialmente, desde que:

- `ApplicationCable::Connection` identifique o usuário autenticado/token;
- a inscrição confira vínculo: cliente dono do frete, transportador designado ou gestor com permissão explícita;
- nomes de stream não sejam autoridade; IDs opacos ajudam, mas não substituem autorização;
- posição detalhada seja visível apenas durante janela operacional definida;
- reconexão faça `GET /api/v1/viagens/:id/snapshot` e continue do último evento.

Fallback recomendado: polling condicional a cada 30–60 s quando WebSocket falhar. SSE é boa alternativa para cliente/gestor somente leitura, mas Action Cable já está no stack e atende comunicação bidirecional se corretamente implementado.

### 8. Rota, ETA e eventos

- Geocodificar origem/destino uma vez, permitir confirmação manual e persistir coordenadas validadas.
- Calcular rota planejada e ETA no backend por adapter de provider; persistir provider/versão/horário.
- Detectar chegada por geofence com precisão e permanência mínima, não por um único ponto.
- Detectar parada após velocidade/raio por janela temporal; distinguir pausa do GPS de veículo parado.
- Detectar desvio comparando posição map-matched/corredor da rota por distância e várias amostras consecutivas; recalcular com cooldown para evitar custo e oscilação.
- Atraso compara ETA recalculado com janela prometida; comunicar como estimativa, não certeza.
- Eventos automáticos devem aceitar revisão e guardar evidência/metodologia.

### 9. LGPD e privacidade

- Definir finalidade, base legal e papéis de controlador/operadores antes do desenvolvimento; produzir RIPD conforme avaliação do DPO/jurídico.
- Aviso claro e granular antes de iniciar; coletar o mínimo necessário e impedir rastreamento fora da viagem.
- Controle de acesso por função e vínculo, expiração do acesso do cliente, MFA para gestores sensíveis e auditoria de visualização/exportação.
- Criptografia em trânsito e em repouso, gestão/rotação de segredos e resposta a incidentes.
- Canal para acesso, correção, portabilidade quando aplicável e exclusão; documentar compartilhamento com provedores internacionais e transferências internacionais.
- Não usar localização para finalidade nova (marketing, score ou disciplina) sem nova análise/base/transparência.

## Comparação: Google Maps, Mapbox e OpenStreetMap

| Opção | Pontos fortes | Limitações/custos | Adequação ao CargaClick |
|---|---|---|---|
| Google Maps Platform | Cobertura e familiaridade fortes, geocoding/rotas/tráfego maduros, SDKs Android/iOS e abertura natural no Google Maps | Pay-as-you-go por SKU, dependência do fornecedor e regras de armazenamento/uso; navegação avançada pode elevar custo | Melhor caminho para MVP móvel se prioridade for confiabilidade e velocidade de entrega; controlar quotas e abstrair provider. |
| Mapbox | Excelente customização, SDKs móveis/offline e APIs de directions/optimization/map matching; free tiers generosos | Cobrança por MAU/viagem/requisição; termos/licença comercial veicular exigem confirmação | Forte alternativa se experiência visual customizada, offline e navegação embutida forem estratégicos. |
| OpenStreetMap + serviços | Dados abertos, independência e possibilidade de self-host; Leaflet já está no projeto | OSM não é um pacote de tiles/geocoder/router com SLA. Operar tiles, Nominatim, OSRM/Valhalla/ORS exige DevOps; APIs públicas não servem à escala comercial de rastreamento | Bom como dados/base e para evitar lock-in, mas contratar provider OSM ou self-host com equipe/custo. Não usar endpoints públicos atuais como produção. |

## Recomendação para o CargaClick

Adotar uma arquitetura **provider-agnostic**, começando com:

1. **PostgreSQL + PostGIS** para viagens, posições, geofences e histórico;
2. **API Rails versionada** para ingestão em lote, idempotente e fortemente autorizada;
3. **Action Cable + Redis** para última posição/eventos, com snapshot HTTP e fallback de polling;
4. **SDK nativo de localização** do Android/iOS para captura; não depender do mapa para obter GPS;
5. **Google Maps Platform para o MVP** de mapas/geocoding/rotas, devido à maturidade móvel e menor risco operacional, mantendo adapter para Mapbox/serviço OSM;
6. **Deep links para Google Maps e Waze** primeiro; navegação turn-by-turn embutida somente após validar demanda e custo;
7. fila offline no app, frequência adaptativa, retenção curta (proposta de 90 dias) e controles LGPD desde o desenho;
8. remover o fallback aleatório e retornar estado explícito “cálculo indisponível” quando o provider falhar.

Não reaproveitar diretamente o protótipo de rastreamento atual. Reaproveitar apenas a escolha de Leaflet se a web continuar com tiles de um provider suportado; consolidar os serviços de rota em uma interface única e coberta por testes.

## Estimativa de etapas (não é cronograma contratual)

Estimativa para equipe com 1 backend, 1 mobile, 1 frontend/QA compartilhado e apoio de produto/segurança:

| Etapa | Entregas | Estimativa |
|---|---|---|
| 0. Descoberta, privacidade e provider | requisitos, papéis, RIPD inicial, métricas, prova de cobertura/custo | 1–2 semanas |
| 1. Fundação backend/banco | viagens, posições, PostGIS, API batch, auth, idempotência, retenção | 2–3 semanas |
| 2. App transportador | permissões, foreground/background, fila offline, início/fim, telemetria de bateria | 3–5 semanas |
| 3. Mapa web cliente/gestor | snapshot, Action Cable autorizado, reconexão, estados de sinal | 2–3 semanas |
| 4. Rotas/ETA/eventos | geocoding confirmado, rota, geofence, parada/atraso/desvio e recalculo controlado | 2–4 semanas |
| 5. Hardening e piloto | carga, segurança, LGPD, lojas, bateria em campo, observabilidade e piloto limitado | 2–4 semanas |

**MVP controlado:** aproximadamente 8–12 semanas com frentes parcialmente paralelas.  
**Versão endurecida com eventos avançados e piloto concluído:** aproximadamente 12–18 semanas.  
As estimativas aumentam se Android e iOS forem implementados separadamente em vez de uma base cross-platform, se houver navegação embutida/offline, ou se for escolhida infraestrutura OSM self-hosted.

## Impacto por camada

- **Backend:** novos endpoints versionados, política de autorização, adapter de mapas/rotas, ingestão batch, jobs de retenção/eventos, broadcasts e observabilidade.
- **Frontend web:** componente de mapa real, trilha/última posição, estados de conexão/privacidade, filtros de gestor e deep links.
- **Banco:** `viagens`, `posicoes_viagem`, `eventos_viagem`, PostGIS/índices/particionamento, retenção e auditoria.
- **Aplicativo:** permissões, serviço de localização, fila offline, sincronização idempotente, UI de início/fim e diagnóstico de bateria/rede.
- **Infraestrutura:** Redis gerenciado, quotas/budgets do provider, alertas, backups, capacidade WebSocket e políticas de segredo.
- **Produto/jurídico:** regras de visibilidade, janela de rastreamento, transparência, retenção, direitos do titular e resposta a incidentes.

## Critérios mínimos antes de chamar de “tempo real completo” (categoria E)

- GPS real capturado apenas em viagem ativa e testado em Android/iOS com tela bloqueada;
- fila offline + retomada sem duplicação/perda relevante;
- API autenticada/autorizada e histórico persistido;
- mapa do cliente/gestor autorizado com posição recente, idade do sinal e reconexão;
- WebSocket distribuído por Redis, snapshot/fallback e testes de carga;
- origem/destino/rota reais, ETA e eventos com tolerância a ruído;
- início/fim explícitos, retenção/exclusão e auditoria LGPD;
- testes automatizados, piloto de campo e monitoramento de bateria, dados, latência e custo.

Até esses critérios serem atendidos, a existência de um marcador, polling ou canal vazio não deve ser comunicada como rastreamento em tempo real.
