# Cobertura da gem Mailcore

A versão `0.1.0.alpha.1` reúne **16 recursos principais, 30 classes de recursos e
151 métodos HTTP**. O contrato foi conferido no backend
`e001da831365c536f5764dc703fb7a03964f807f` e no SDK Node
`a234dc2d6f22389f8a57046a142d82a4a4feddf5`, em 14/11/2026. A superfície Ruby
preserva os caminhos, campos e envelopes selecionados nessa conferência.

Os nomes abaixo partem de uma instância `cliente = Mailcore::Cliente.new(...)`.
Pedidos e filtros são `Hash` posicionais; opções da operação são palavras-chave,
como `chave_idempotencia:`, `tempo_limite:`, `limite_resposta_bytes:` e
`cabecalhos:`. Os prazos usam segundos. Os métodos síncronos retornam
`Mailcore::Resposta`, com `dados`, `status` e `cabecalhos`; `resposta[:id]`
consulta a chave correspondente em `dados`.

## Recursos e métodos

| Recurso                      | Métodos                                                                                                                                                                                              |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `emails`                     | `enviar`, `listar`, `obter`, `reagendar`, `cancelar`, `eventos`, `obter_por_idempotencia`, `baixar_anexo`                                                                                            |
| `lotes`                      | `enviar`, `obter_por_idempotencia`                                                                                                                                                                   |
| `dominios`                   | `criar`, `listar`, `obter`, `atualizar`, `registros_dns`, `verificar`, `remover`                                                                                                                     |
| `chaves_api`                 | `criar`, `listar`, `renomear`, `revogar`                                                                                                                                                             |
| `contatos`                   | `criar`, `listar`, `obter`, `atualizar`, `remover`, `adicionar_em_lote`, `alterar_em_lote`                                                                                                           |
| `contatos.segmentos`         | `listar`, `adicionar`, `remover`                                                                                                                                                                     |
| `contatos.topicos`           | `listar`, `atualizar`                                                                                                                                                                                |
| `contatos.importacoes`       | `prever`, `criar`, `obter`                                                                                                                                                                           |
| `contatos.exportacoes`       | `criar`, `listar`, `obter`, `baixar`, `baixar_fluxo`                                                                                                                                                 |
| `segmentos`                  | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `topicos`                    | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `propriedades_contatos`      | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `modelos`                    | `criar`, `listar`, `obter`, `atualizar`, `remover`, `publicar`, `duplicar`, `prever`, `testar`, `obter_previa`                                                                                       |
| `modelos.versoes`            | `listar`, `obter`, `restaurar`, `prever`                                                                                                                                                             |
| `modelos.pastas`             | `listar`, `criar`, `atualizar`, `remover`                                                                                                                                                            |
| `webhooks`                   | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `webhooks.eventos`           | `listar`, `obter`, `listar_tentativas`, `reenviar`                                                                                                                                                   |
| `campanhas`                  | `criar`, `listar`, `obter`, `atualizar`, `remover`, `duplicar`, `revisar`, `enviar`, `cancelar`, `prever`, `ler_previa`, `testar`, `obter_metricas`, `listar_destinatarios`, `listar_links_clicados` |
| `automacoes`                 | `criar`, `listar`, `obter`, `atualizar`, `remover`, `duplicar`, `parar`                                                                                                                              |
| `automacoes.execucoes`       | `listar`, `obter`                                                                                                                                                                                    |
| `eventos`                    | `criar`, `listar`, `obter`, `atualizar`, `remover`, `enviar`                                                                                                                                         |
| `recebimento`                | `listar`, `obter`, `listar_anexos`, `obter_anexo`, `baixar_original`, `baixar_anexo`, `baixar_original_fluxo`, `baixar_anexo_fluxo`                                                                  |
| `caixas`                     | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `caixas.etiquetas`           | `criar`, `listar`, `obter`, `atualizar`, `remover`                                                                                                                                                   |
| `caixas.conversas`           | `listar`, `buscar`, `obter`, `atualizar`, `remover`                                                                                                                                                  |
| `caixas.conversas.etiquetas` | `adicionar`, `substituir`, `remover`                                                                                                                                                                 |
| `caixas.conversas.emails`    | `listar`, `obter`, `responder`, `encaminhar`                                                                                                                                                         |
| `caixas.rascunhos`           | `criar`, `listar`, `obter`, `atualizar`, `remover`, `enviar`                                                                                                                                         |
| `cli.concessoes`             | `listar`, `revogar`                                                                                                                                                                                  |

`cli` é a classe agregadora que expõe `concessoes`, completando as 30 classes.
A função local `Mailcore.verificar_assinatura` verifica webhooks sem fazer
requisições HTTP e não integra a contagem dos 151 métodos.

## Pedidos, respostas e paginação

A gem mantém os nomes em português do contrato HTTP. Campos como
`remetente`, `destinatarios`, `agendada_em`, `segmento_id` e `revisao` são enviados
conforme fornecidos. O servidor valida regras de negócio, permissões e os DTOs
específicos de cada recurso. A gem não converte um pedido de caixa em envio
transacional nem acrescenta campos para ampliar permissões.

JSON admite strings e símbolos como chaves, texto codificável em UTF-8, inteiros,
floats finitos, booleanos, arrays, hashes e `nil`. Objetos arbitrários e números
que seriam serializados como texto são recusados. Nomes de chave precisam
permanecer únicos após a conversão para UTF-8. Respostas JSON usam chaves
simbolizadas, preservando arrays e valores anuláveis.

Omissão de um campo e seu envio explícito com `nil` têm significados diferentes.
O transporte conserva `nil` e `false` no corpo; não aplica `compact`. Nos filtros
da URL, `nil` é omitido e `false` permanece como `false`. Identificadores são
codificados como um segmento de caminho; UUIDs, aliases, nomes de eventos e
endereços de contato não viram trechos de URL controlados pela aplicação.

A paginação é explícita. O cliente consulta uma página por chamada e devolve os
cursores sem recalcular ou carregar páginas adicionais. O servidor pode aplicar
limites diferentes por recurso; os envelopes permanecem próprios:

| Envelope dentro de `resposta.dados`      | Grupos                                                                                                            |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `{ dados:, proximo: }`                   | E-mails, domínios e concessões CLI                                                                                |
| `{ dados:, tem_mais:, proximo_cursor: }` | Contatos, exportações, segmentos, tópicos, propriedades de contatos, modelos/versões, webhooks/eventos/tentativas |
| `{ dados:, proximo:, tem_mais: }`        | Campanhas e suas listas, automações/execuções, eventos personalizados, recebimento e caixas                       |
| `{ dados: }`                             | Chaves de API, pastas de modelos e eventos de entrega de um e-mail                                                |

## Contratos por área

| Área                   | Regras relevantes                                                                                                                                                                                                                                                                                                                                                  |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Envio transacional     | Texto e/ou HTML, Cc/Cco, cabeçalhos e anexos CID conforme o DTO de composição. Até 50 destinatários somados, HTML + texto até 500 KiB, JSON do endpoint até 8 MiB, até 10 anexos com soma decodificada de 5 MiB nos tipos aceitos. A gem não baixa anexos remotos do envio transacional. Aceitação retorna `id` e `estado`; a entrega é acompanhada separadamente. |
| Envio por modelo       | Modelo publicado por ID/alias e variáveis. Usa o DTO específico, com anexos básicos e sem compor simultaneamente conteúdo direto, Cc/Cco, cabeçalhos ou CID.                                                                                                                                                                                                       |
| Lotes                  | Array de 1 a 100 mensagens, com aceitação atômica e ordenada. Sem anexos, Cc/Cco ou cabeçalhos de mensagem. Uma operação gera uma chamada; a gem não divide o lote ou repete automaticamente seu envio.                                                                                                                                                            |
| Agendamento            | `agendada_em` usa ISO 8601 com fuso, dentro da janela de até 30 dias. Reagendar e cancelar dependem do estado atual e da autorização da chave.                                                                                                                                                                                                                     |
| Domínios               | Capacidades de envio/recebimento `enabled` ou `disabled`, mantendo ao menos uma habilitada. Tracking e diagnóstico seguem os campos do servidor. Remover devolve o estado suspenso do domínio.                                                                                                                                                                     |
| Chaves de API          | O segredo aparece somente na criação. A alteração pública renomeia a chave; a revogação devolve resposta sem conteúdo. A listagem não usa cursor.                                                                                                                                                                                                                  |
| Contatos               | CRUD por UUID ou e-mail; associações exigem UUID. Nomes anuláveis, propriedades tipadas e preferências são preservados. Operações em lote admitem até 1.000 contatos. Tópicos usam as assinaturas `opt_in` e `opt_out`.                                                                                                                                            |
| Importação de contatos | CSV UTF-8 em string JSON, até 8 MiB e 100.000 registros, com mapeamento por índice de coluna. O upload admite JSON até 50 MiB para acomodar os escapes. `prever` não persiste; `criar` inicia processamento e `obter` acompanha o estado. Não há método de listagem de importações.                                                                                |
| Exportação de contatos | Criar com filtros, consultar/listar e baixar CSV. Criação e download revalidam o papel administrativo. `baixar` devolve bytes; `baixar_fluxo` entrega os blocos ao consumidor e devolve a contagem total.                                                                                                                                                          |
| Modelos                | CRUD e publicação por UUID/alias, com revisão exigida na edição, publicação e restauração. Versões imutáveis, pastas hierárquicas, prévias e testes com destinatários explícitos. `obter_previa(organizacao_id, previa_id)` lê HTML pela rota autenticada.                                                                                                         |
| Campanhas              | Marketing para segmento, tópico opcional, revisão e confirmação explícita no envio. Testes usam destinatários explícitos. Cancelamento respeita o estado da campanha; despacho concluído não comprova entrega. Métricas mantêm `nil` quando a telemetria está indisponível.                                                                                        |
| Automações             | Fluxos ativos/inativos, etapas e conexões informadas juntas, condições, esperas, intervalos e ações do contrato. Parar impede novas inscrições e preserva as execuções aceitas. A gem consulta execuções; não oferece mutação individual dessas execuções.                                                                                                         |
| Eventos personalizados | Definição com nome imutável e esquema opcional. Enviar ocorrência exige exatamente `email` ou `contato_id`, com `dados` até 64 KiB. Esquema `nil` difere de `{}`. O nome literal `send` continua consultável e editável pelos métodos de definição.                                                                                                                |
| Webhooks               | CRUD, eventos, tentativas e reenvio do evento original. O servidor preserva identificador e payload no replay. Consumidores devem verificar a assinatura sobre o corpo bruto e deduplicar o `svix-id` antes de executar efeitos.                                                                                                                                   |
| Recebimento            | Lista, busca, intervalo temporal e metadados/anexos. `obter` aceita `formato_html: 'cid'` ou `'data_uri'` no Hash de filtros; o formato efetivo pode ser `cid` por limite de expansão. Cabeçalhos repetidos permanecem pares ordenados. MIME original e anexos usam rotas fixas autenticadas.                                                                      |
| Caixas                 | Caixas, etiquetas, conversas, mensagens e rascunhos usam IDs explícitos e revisões conforme o DTO. Responder e encaminhar aceitam a intenção de envio pela fila. Remover conversa a move para a lixeira. Etiquetas podem ser substituídas por `[]` para remover todas as associações.                                                                              |
| Anexos de caixas       | Resposta/encaminhamento admitem Base64 ou URL e CID conforme o contrato; rascunhos recusam CID fornecido pelo cliente. O servidor resolve URLs com suas próprias proteções. O cliente Ruby não navega nessas URLs. JSON de caixas é limitado a 8 MiB no endpoint.                                                                                                  |
| Concessões CLI         | Listagem e revogação das concessões autorizadas do ator atual. Fluxos interativos de autorização e renovação permanecem fora do cliente comum.                                                                                                                                                                                                                     |

O teto de **50 MiB do transporte JSON** acomoda a importação escapada; ele não
substitui limites menores de cada endpoint, como os 8 MiB do envio e das caixas.
O limite padrão de leitura da resposta é **16 MiB**, configurável por operação.
Downloads usam `String` binária. Os métodos com sufixo `_fluxo` exigem um bloco,
leem de forma síncrona e mantêm o prazo e o teto de bytes durante o consumo.

## Recebimento, Rails e limites de superfície

O recurso `recebimento` acessa somente as rotas autenticadas de consulta, anexos,
MIME original e download. URLs temporárias presentes nos metadados são
capacidades sensíveis; a gem não as segue automaticamente e não envia a chave
Mailcore a um endereço devolvido pela API. O conteúdo recebido está sujeito à
retenção e à disponibilidade atuais do servidor. Listagem não garante que MIME
ou anexos ainda estejam disponíveis.

Rails é opcional. As integrações Action Mailer e Action Mailbox usam a mesma gem
e o mesmo cliente HTTP; o cliente Ruby básico não exige carregar Rails. Templates
Ruby/Rails podem produzir o HTML e o texto enviados ao Mailcore. A renderização
React pertence à integração JavaScript e não faz parte desta gem.

Esta matriz cobre os 151 métodos selecionados, sem anunciar toda a API do
produto. As rotas públicas de métricas globais e auditoria existentes no backend
ficam fora desta versão, assim como no SDK Node usado na conferência. Nenhum
helper de dashboard, sessão, visualização compartilhada ou token temporário foi
acrescentado por inferência. Endereços de anexos de caixas com prefixo de dashboard
continuam como metadados; não há um método público fictício para baixá-los.

O teste de contrato exercita os 151 métodos contra um transporte coletor,
conferindo método, caminho, corpo, filtros, formato e opções. Os testes HTTPS
reais com servidor sintético cobrem o transporte separadamente. Essa combinação
não equivale a executar cada endpoint contra uma conta real ou a medir capacidade
de envio em produção; os resultados efetivamente executados estão no relatório
de verificação do repositório.
