# Verificação da gem Ruby

A verificação é local e utiliza dados sintéticos. Não publica pacotes, não faz
deploy e não envia SMTP. Os relatórios JSON registram resultados observados,
versões, imagens e alcance de cada execução.

Em 14/11/2026, a matriz principal passou em Ruby **3.3.13, 3.4.12 e 4.0.9**.
O ensaio da API real local também passou nos dez grupos descritos abaixo, com
23 migrações, TLS verificado e limpeza concluída. Os números e revisões completos
permanecem nos relatórios JSON correspondentes.

## Matriz e distribuição

Execute na raiz do repositório:

```sh
sh scripts/verificar.sh
```

O host precisa de shell POSIX e Docker Linux. Ruby, Bundler, Rails, Sinatra e
ferramentas de compilação ficam nas imagens. As bases Ruby 3.3, 3.4 e 4.0 estão
fixadas por digest, e as dependências de desenvolvimento pelo `Gemfile.lock`.
Não há instalação de ferramentas no host.

Além do lockfile, a suíte HTTPS é repetida com o `net-http` original de cada Ruby
(0.4.1, 0.6.0 e 0.9.1, respectivamente). Seus relatórios terminam em
`-http-padrao.json`. Isso exercita também o caminho de detecção de resposta
incompleta nas versões anteriores do transporte HTTP.

As suítes são executadas em processos separados, sem rede externa, com checkout
somente leitura e diretório temporário para Rails/SQLite/Active Storage. O
servidor HTTPS de teste escuta somente dentro do container e não publica portas.
Os relatórios `ruby-*.json` contêm as contagens por suíte; uma execução válida
precisa de `resultado: "aprovado"`, sem falhas, erros ou testes ignorados.

- Contrato: método, caminho, filtros e corpo das 151 operações, recursos filhos,
  identificadores escapados e preservação de `nil`/`false`.
- Protocolo HTTPS real: certificado/hostname, CAs, redirecionamentos, HTTP de erro,
  idempotência, desconexões sem retry, prazo total, limites, respostas truncadas,
  bytes binários, consumo em fluxo e isolamento entre threads.
- Assinatura: vetor HMAC independente, UTF-8, rotação, alteração do corpo e janela
  temporal de cinco minutos.
- Rails: Action Mailer/Mail reais e aplicação Action Mailbox com SQLite,
  armazenamento temporário e Active Job de teste. A fronteira HTTP desses
  adaptadores usa um cliente sintético, conforme [o guia Rails](rails.md).
- Sinatra: aplicação Rack real, autenticação, idempotência, limites de corpo,
  separação de credenciais e tratamento sanitizado dos erros.

O mesmo comando constrói a gem em `pkg/`, instala o artefato localmente dentro de
containers Ruby mínimos e verifica que o cliente puro carrega sem Rails/Sinatra.
O arquivo SHA-256 acompanha a gem. Os pacotes contêm código/documentação próprios,
sem testes, credenciais, arquivos de ambiente ou dependências vendorizadas.

## API e PostgreSQL reais locais

O ensaio adicional é separado por precisar do checkout backend e de imagens e
cache de compilação já preparados:

```sh
sh scripts/verificar_api.sh
```

São usados o checkout `mailcore` ao lado de `libs-mailcore`, a imagem
`mailcore/ruby-testes:3.4`, um runtime local da API, uma imagem Rust e o cache
público Cargo. O controlador compila a API com `--offline --locked` em Docker e
registra revisão, hash dos fontes e binário. O cache não inclui credenciais Cargo.
Consulte `python3 testes/integracao_api.py --help` dentro da imagem para informar
outros caminhos/imagens; `MAILCORE_BACKEND` e `MAILCORE_IMAGEM_CLIENTE` ajustam o
wrapper. Nenhum compilador deve ser instalado no host para esse ensaio.

O controlador usa o socket Docker para criar rede interna exclusiva, configurações
efêmeras em memória e instâncias novas da API e PostgreSQL. A API usa HTTPS e
PostgreSQL usa TLS `verify-full`; não são publicadas portas. Chaves de dados,
certificados, usuários e organização são sintéticos e exclusivos. Não são
iniciados worker, Postal ou SMTP.

Os cenários aprovados incluem chaves Full/Sending e negação por escopo; envio
composto com Cc/Cco/CID, replay e conflito de idempotência; lote atômico; domínios;
contatos, catálogos e exportação CSV por fluxo; modelos/pastas/versões/publicação
com controle de revisão; CRUD de marketing sem disparo; caixas/etiquetas/rascunhos;
recebimento MIME real pendente de processamento; concessões CLI e revogação.
O recebimento usa um callback privado sintético assinado, sem iniciar Postal.

O resultado e a limpeza ficam em [integracao-api.json](integracao-api.json).
`resultado: "aprovado"` e `limpeza_concluida: true` são necessários para considerar
o ensaio aprovado. Credenciais, corpos e mensagens de email não são gravados no
relatório. O controlador trata SIGINT/SIGTERM e remove apenas seus recursos.

A [interrupção por SIGTERM](integracao-api-interrupcao.json) também foi exercitada:
a saída de falha era esperada e a limpeza foi concluída, sem recursos rotulados
restantes. Esse ensaio não verifica SIGKILL nem desfaz intenções já aceitas.

## Limites das conclusões

Uma API real local comprova os contratos exercitados no binário/backend registrado,
sem simular entrega SMTP. Os testes Rails não comprovam a configuração da fila,
banco, armazenamento ou segredos de uma aplicação de produção. A matriz Docker
não garante todos os sistemas operacionais, versões Rails ou ambientes hospedados.
Não foi medido desempenho em produção nem equivalência de latência com outro
serviço. Uma publicação ou implantação futura exige validação própria.
