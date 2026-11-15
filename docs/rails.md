# Rails: envio e recebimento

O gem `mailcore` integra o cliente HTTP com Action Mailer e Action Mailbox. Rails
e Mail são dependências opcionais: o cliente Ruby funciona sem esses componentes.
A combinação verificada é Ruby 3.4, Rails/Action Mailer/Action Mailbox `8.1.3.1`,
Mail `2.9.1` e JSON `>= 2.7, < 3`. Consulte o relatório geral do SDK para as outras
versões Ruby efetivamente exercitadas. Esta faixa de JSON preserva a integração
com o decodificador do Active Support dessa versão Rails.

## Action Mailer

Configure a chave em runtime. O bloco permite um `Proc`, resolvido ao fazer cada
pedido, para carregar a credencial pelo mecanismo de segredos da aplicação:

```ruby
# config/initializers/mailcore.rb
Mailcore.configurar do |configuracao|
  configuracao.chave_api = -> { ENV.fetch('MAILCORE_API_KEY') }
end
```

Ative o método de entrega:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :mailcore
```

O carregamento padrão do Rails registra esse método pelo Railtie. Se o cliente
Ruby foi carregado antes do framework, carregue explicitamente
`require 'mailcore/railtie'` antes de inicializar a aplicação.

Os mailers e templates continuam sendo os do Rails:

```ruby
class AvisoMailer < ApplicationMailer
  default from: 'Equipe <avisos@seu-dominio.example>'

  def confirmacao
    headers['mailcore_opcoes'] = {
      chave_idempotencia: "pedido-#{params.fetch(:pedido_id)}-confirmacao",
      tags: { tipo: 'confirmacao' }
    }
    mail(to: params.fetch(:destinatario), subject: 'Pedido confirmado')
  end
end
```

Use `deliver_now` para aguardar a aceitação HTTP ou `deliver_later` para entregar a
execução ao Active Job configurado pela aplicação. O gem não cria uma fila. A
aceitação da API não comprova entrega SMTP.

A conversão inclui remetente com nome, destinatários, cópias, cópias ocultas, um
endereço de resposta, texto, HTML, multipart, cabeçalhos personalizados e anexos.
Anexos mantêm os bytes em base64 estrito, o tipo MIME e o Content-ID quando inline.
Cabeçalhos estruturais e reservados pelo Mailcore são filtrados; os demais seguem
as validações da API.

`mailcore_opcoes` aceita `chave_idempotencia`, `tags` e `agendada_em`. Esta última
usa o formato ISO 8601 com fuso aceito pela API. Essas opções são metadados do
adaptador e não se tornam cabeçalhos do email. Uma chave estável identifica a mesma
intenção de negócio, inclusive quando a aplicação decide repetir um job. O gem não
repete um envio automaticamente após falhas ambíguas.

Para uma configuração específica, use `config.action_mailer.mailcore_settings` ou
`delivery_method_options` do Rails. São aceitas as opções do cliente
`chave_api`, `url_base`, `tempo_limite`, `tempo_conexao`, `certificado_ca` e
`limite_resposta_bytes`, além de `chave_idempotencia`. A opção `cliente` permite
fornecer uma instância isolada já configurada; ela prevalece sobre as demais opções
de conexão. Configure cada organização com seu próprio cliente, sem trocar a
configuração global durante pedidos concorrentes.

O identificador retornado pela API é colocado no `message_id` do objeto Mail
somente após sucesso. Erros do cliente são propagados para o mecanismo normal de
falhas do Rails, sem substituir o identificador anterior.

## Action Mailbox

A aplicação precisa ter Action Mailbox, Active Record, Active Storage e Active
Job configurados. Faça a instalação e as migrações próprias do Rails no ambiente
da aplicação. O gem não altera o banco nem escolhe armazenamento ou filas.

Carregue o ingress e habilite-o:

```ruby
# config/application.rb, depois de carregar os componentes Rails
require 'mailcore/engine'

# config/environments/production.rb
config.action_mailbox.ingress = :mailcore
```

Cadastre no Mailcore um webhook do evento `email.received` apontando para:

```text
https://sua-aplicacao.example/rails/action_mailbox/mailcore/inbound_emails
```

Guarde o segredo de assinatura nas credenciais criptografadas do Rails:

```yaml
action_mailbox:
  mailcore_segredo: segredo_fornecido_pelo_webhook
```

Como alternativa, configure `Mailcore.configuracao.segredo_webhook` pelo bloco
`Mailcore.configurar`; o padrão consulta `MAILCORE_WEBHOOK_SECRET`. A credencial
Rails tem precedência. Configure também uma chave de API com permissão para ler
o original recebido. A chave da API e o segredo do webhook têm funções distintas.

O endpoint aceita POST e exige assinatura válida do corpo bruto. Para corpos
dentro do limite, sem o ingress habilitado responde `404`; assinatura inválida resulta em `401`; configuração do
segredo ausente resulta em `503`. Eventos assinados de outros tipos recebem `204`
sem buscar conteúdo. O evento de recebimento deve conter `data.email_id` e um
array não vazio de endereços SMTP em `data.to`; envelope inválido resulta em
`422`. Corpos acima de 256 KiB são recusados com `413`.

Um middleware atua antes dos parsers e da instrumentação do Rails, somente no
POST desse ingress. Ele lê no máximo 256 KiB mais um byte, inclusive quando a
requisição não informa Content-Length. Um corpo permitido é recolocado em um
StringIO com os mesmos bytes e tamanho correto; o controller verifica a assinatura
desse conteúdo sem normalizar ou reserializar o JSON.

Nessa rota, o corpo não é convertido automaticamente em parâmetros Rails antes
da autenticação. Assim, os metadados de email não entram no campo de parâmetros
da instrumentação, e o parser Rails não registra o corpo de um JSON malformado.
Filtros adicionais para `data`, `_json` e credenciais são aplicados somente ao
ambiente da requisição, preservando os filtros da aplicação. Outras rotas e
métodos seguem seu processamento habitual.

Após validar a assinatura, o ingress baixa o original pela rota autenticada do
cliente, `recebimento.baixar_original`. Ele não visita URLs fornecidas no webhook
e não reconstrói anexos a partir de metadados incompletos. A falha desse download
retorna `503`, preservando a possibilidade de entrega posterior do webhook.
Falhas internas do banco ou armazenamento seguem o tratamento de erros do Rails.

Os bytes MIME do original são preservados. O ingress acrescenta cabeçalhos
`X-Original-To` com os destinatários validados do envelope assinado. Isso permite
que o roteamento normal do Action Mailbox também encontre cópias ocultas ou
destinos de encaminhamento ausentes do cabeçalho `To`. Esses endereços fazem parte
do conteúdo armazenado pela aplicação e devem receber a mesma proteção dos emails.

```ruby
class ApplicationMailbox < ActionMailbox::Base
  routing /^suporte@/i => :suporte
end
```

O Action Mailbox armazena a mensagem e encaminha o processamento pelo Active Job.
A deduplicação nativa considera o par Message-ID e checksum do conteúdo. A
repetição do mesmo original com Message-ID e o mesmo envelope recebe `204` sem
criar uma nova mensagem. Quando o original não contém Message-ID, o Rails gera um
identificador que inclui o hostname; não há garantia de deduplicação entre réplicas
nesse caso. Isso não transforma o webhook em uma entrega exatamente uma vez: um
original ou envelope diferente pode gerar outro registro, e os efeitos do mailbox
da aplicação também precisam ser idempotentes. Os prazos de replay e retenção são
responsabilidade do Mailcore e da aplicação, respectivamente.

Configure armazenamento protegido, a retenção do Action Mailbox e filtros de logs
na aplicação. Não registre o corpo bruto, endereços de destinatários, credenciais
ou cabeçalhos de assinatura. Os adaptadores não registram esses valores.

## Verificação local

Os testes do adaptador usam Action Mailer e Mail reais para converter mensagens,
com um cliente sintético no ponto de chamada HTTP. Os testes do ingress executam
uma aplicação Rails em memória, com SQLite, Active Storage em pasta temporária e
Active Job de teste. Eles verificam a assinatura por um vetor HMAC independente,
persistência do original, destinatário oculto, replay, acesso recusado e falha de
consulta. Esses testes não abrem portas, chamam produção ou enviam SMTP.

Uma entrada virtual de 4 GiB, sem Content-Length, comprova que a aplicação Rails
solicita uma única leitura de 262.145 bytes antes de recusar o corpo, sem alocar
os 4 GiB. Outros casos verificam os bytes assinados com espaços e quebras de linha,
a ausência de metadados de email nos parâmetros instrumentados, os filtros locais
e a propagação de erros de I/O posteriores à leitura.

Os arquivos `testes/testes_action_mailer.rb` e
`testes/testes_action_mailbox.rb` são executados em processos separados, usando as
dependências do ambiente Docker de testes do projeto. A configuração de banco e
armazenamento desses testes é descartável e exclusiva do processo.

Contratos Rails utilizados:
[Action Mailer](https://guides.rubyonrails.org/action_mailer_basics.html) e
[Action Mailbox](https://guides.rubyonrails.org/action_mailbox_basics.html).
