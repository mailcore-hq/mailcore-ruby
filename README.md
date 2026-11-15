# Mailcore para Ruby

[Código-fonte](https://github.com/mailcore-hq/mailcore-ruby) · [Problemas e sugestões](https://github.com/mailcore-hq/mailcore-ruby/issues)

Cliente Ruby da API Mailcore, com integração opcional com Rails. Versão
alpha `0.1.0.alpha.1`. Requer Ruby 3.3 ou superior.
Cada instância mantém sua configuração; pedidos concorrentes não compartilham
credenciais ou estado de envio.

## Instalação

Instale a versão alpha pelo RubyGems:

```sh
gem install mailcore --version 0.1.0.alpha.1 --no-prerelease
```

Com Bundler, adicione ao Gemfile da aplicação:

```ruby
gem 'mailcore', '0.1.0.alpha.1'
```

### Desenvolvimento e instalação local

A verificação Docker gera `pkg/mailcore-0.1.0.alpha.1.gem`. Em uma aplicação Ruby:

```sh
gem install /caminho/mailcore-0.1.0.alpha.1.gem
```

O comando pode buscar dependências no RubyGems. Outra opção é apontar o Gemfile
da aplicação para este checkout e executar Bundler:

```ruby
gem 'mailcore', path: '/caminho/libs-mailcore/mailcore-ruby'
```

Não é necessário instalar Rails para utilizar o cliente. As dependências de
runtime são `net-http`, `json`, `openssl`, `base64` e `timeout`; o pacote não
inclui um cliente HTTP compilado próprio. A versão alpha está fixada no comando;
`--no-prerelease` mantém a resolução das dependências em versões estáveis.
A instalação pública foi validada com JSON 2.x, também utilizado na matriz Rails.
Veja os [checksums e resultados da publicação](docs/publicacao.md).

## Primeiro envio

Configure `MAILCORE_API_KEY` somente no servidor. Use domínio verificado e uma
chave autorizada para o remetente.

```ruby
require 'mailcore'

cliente = Mailcore::Cliente.new(chave_api: ENV.fetch('MAILCORE_API_KEY'))
pedido = {
  remetente: 'Equipe <equipe@example.com>',
  destinatarios: ['pessoa@example.com'],
  assunto: 'Bem-vindo',
  html: '<p>Sua conta está pronta.</p>',
  texto: 'Sua conta está pronta.'
}
resposta = cliente.emails.enviar(pedido, chave_idempotencia: 'pedido-123-confirmacao')
puts resposta[:id]
```

`202` confirma a aceitação da intenção; a entrega é acompanhada pelos eventos da
mensagem ou webhooks. Reutilize a mesma chave e o mesmo conteúdo ao repetir a
mesma intenção. A biblioteca não repete requisições automaticamente, inclusive
após timeout, `429` e desconexão. Um timeout não desfaz uma intenção aceita.

Anexos usam `nome`, `tipo_conteudo`, `conteudo_base64` e, no envio composto,
`id_conteudo` opcional para CID. O lote aceita de 1 a 100 mensagens, em uma única
operação atômica; não divide pedidos nem aceita anexos, Cc/Cco ou cabeçalhos de
mensagem. Agendamento usa `agendada_em` ISO 8601 com fuso. As regras de domínio,
permissões e limites do DTO são validadas pelo servidor.

## Resultados, erros e opções

As operações devolvem `Mailcore::Resposta`: `dados` contém o JSON da API com
chaves simbolizadas recursivamente; `status` e `cabecalhos` preservam metadados
HTTP. `resposta[:id]` abrevia `resposta.dados[:id]`. Listas mantêm os envelopes
originais (`dados`, `proximo`, `proximo_cursor`, `tem_mais`, conforme a rota).
Nenhuma paginação é percorrida automaticamente.

```ruby
begin
  pagina = cliente.contatos.listar({ limite: 20 })
  proximo = pagina.dados[:proximo_cursor]
rescue Mailcore::ErroApi => erro
  # erro.codigo, erro.status e erro.cabecalhos['retry-after']
rescue Mailcore::ErroTransporte => erro
  # Confirme a intenção antes de decidir repetir um envio ambíguo.
end
```

`ErroApi` preserva códigos e mensagens JSON públicos do servidor.
`ErroResposta` identifica JSON inválido e limites excedidos.
`ErroTransporte` identifica falhas de comunicação, resposta incompleta ou prazo; configuração inválida
gera `ErroConfiguracao`. As mensagens de transporte não reproduzem credenciais
ou corpos recebidos. Erros de API podem conter dados privados; registre somente
os campos necessários.

Todas as operações aceitam as palavras-chave `chave_idempotencia`,
`tempo_limite` (segundos), `limite_resposta_bytes` e `cabecalhos` adicionais.
Cabeçalhos de autenticação, protocolo e idempotência são reservados pelo cliente.
O prazo total padrão é 30 segundos, conexão até 10 segundos e resposta até 16 MiB.
O teto JSON de pedido é 50 MiB, para comportar o envelope de importação CSV;
cada rota aplica seu limite específico no servidor.

```ruby
cliente = Mailcore::Cliente.new(
  chave_api: -> { ENV.fetch('MAILCORE_API_KEY') },
  url_base: 'https://mailcore.com.br/v1',
  tempo_limite: 30,
  tempo_conexao: 10
)
```

Uma chave em `Proc` é resolvida a cada operação, permitindo rotação. Use instâncias
distintas para credenciais distintas; configure o módulo global somente no boot.
O cliente exige HTTPS, verifica certificado e hostname e recusa redirecionamentos.
Não herda proxies do ambiente. CAs privadas podem ser informadas por
`certificado_ca: '/caminho/ca.crt'`; TLS permanece verificado. HTTP só é permitido
em loopback com `permitir_http_local: true`, para testes explícitos.

## Downloads e webhooks

Downloads completos devolvem `String` em `Encoding::BINARY`, preservando MIME,
CSV e anexos. Os métodos com sufixo `_fluxo` exigem bloco e entregam partes de
forma síncrona, respeitando o ritmo do consumidor e o teto de bytes. A resposta
final informa o total em `dados`. Prazo e tamanho continuam ativos até terminar.

```ruby
File.open('/caminho/mensagem.eml.parcial', 'wb') do |arquivo|
  cliente.recebimento.baixar_original_fluxo('id-da-mensagem') do |parte|
    arquivo.write(parte)
  end
end
```

Só trate o arquivo como completo depois de sucesso; uma falha pode deixar partes
já escritas. Downloads usam rotas autenticadas da API; URLs temporárias retornadas
em metadados não são acessadas automaticamente.

```ruby
evento = Mailcore.verificar_assinatura(
  corpo_bruto: corpo_recebido_sem_alteracoes,
  cabecalhos: cabecalhos_recebidos,
  segredo: ENV.fetch('MAILCORE_WEBHOOK_SECRET')
)
```

A verificação usa HMAC-SHA256, cabeçalhos `svix-*`, comparação em tempo constante
e janela temporal de cinco minutos. Corpo alterado, cabeçalhos ambíguos e
timestamps vencidos/futuros são recusados. Deduplicação dos eventos e confirmação
durável pertencem ao consumidor; uma assinatura válida não torna a ação idempotente.

## Rails e demais recursos

O [guia Rails](docs/rails.md) cobre Action Mailer e Action Mailbox, incluindo
HTML/texto, anexos/CID e recebimento autenticado. Rails e Mail são opcionais para
a gem; os adaptadores usam os componentes já instalados na aplicação.
O [exemplo Sinatra](docs/sinatra.md) demonstra uma rota privada de envio com
destino fixo, usando o mesmo cliente Ruby e a instalação Sinatra da aplicação.

A [cobertura](docs/cobertura.md) lista os recursos e contratos. O cliente inclui
envio, lote, domínios, chaves, contatos, segmentos, tópicos, propriedades,
importações/exportações, modelos, campanhas, automações, eventos, webhooks,
recebimento, caixas e concessões CLI. Não converte métodos privados do dashboard
em API pública nem cria capacidades ausentes no servidor.

## Desenvolver e verificar com Docker

Requisitos do host: shell POSIX e Docker Linux acessível ao usuário.
Ruby, Bundler, Rails e ferramentas de compilação rodam dentro das imagens:

```sh
sh scripts/verificar.sh
```

O comando verifica a matriz Ruby 3.3, 3.4 e 4.0, prepara a gem e confere sua
instalação. Os testes de protocolo usam dados sintéticos, TLS verificado e nenhuma
porta publicada. A [verificação](docs/verificacao.md) distingue os testes de
contrato, HTTPS, Rails e integração com a API real local.

Publicação no RubyGems e deploy não são executados por esses comandos.
Leia [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) e [LICENSE](LICENSE).
