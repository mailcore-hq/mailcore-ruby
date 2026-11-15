# Integração com Sinatra

O [exemplo Sinatra](../exemplos/sinatra.rb) usa o mesmo cliente `mailcore` da
integração Ruby. Sinatra é uma dependência da aplicação e do ambiente de testes;
não é uma dependência de runtime do gem Mailcore. A combinação verificada usa
Sinatra `4.2.1` e Rack `3.2.8`, compatível com o conjunto Rails `8.1.3.1` usado nos
testes do projeto.

O exemplo é uma aplicação modular `Sinatra::Base`. Ele oferece apenas
`POST /enviar`, que envia uma mensagem fixa para o endereço configurado no boot.
O corpo e a query da requisição não escolhem destinatários, conteúdo, chave da
API, URL da API ou cliente.

## Configurar na aplicação

Forneça estas variáveis pelo mecanismo de segredos do seu ambiente Docker:

| Variável                | Uso                                                                 |
| ----------------------- | ------------------------------------------------------------------- |
| `MAILCORE_API_KEY`      | Chave usada pelo SDK para falar com a API                           |
| `TOKEN_APLICACAO`       | Token separado que autoriza chamadas ao exemplo                     |
| `MAILCORE_REMETENTE`    | Remetente fixo em domínio autorizado                                |
| `MAILCORE_DESTINATARIO` | Destinatário fixo                                                   |
| `MAILCORE_API_URL`      | Opcional: URL base HTTPS da API; usa o padrão do SDK quando ausente |

O token precisa ser uma String de 32 a 256 caracteres em Base64URL, usando letras,
números, `_` e `-`, e deve ser diferente da chave da API. Gere-o com uma fonte
criptograficamente segura, por exemplo `SecureRandom.urlsafe_base64(32)`. O exemplo
recusa configuração incompleta ou ambígua no boot. Ele guarda um resumo SHA256 do
token e compara resumos de tamanho fixo com a operação de tempo constante do
OpenSSL.

Em um `config.ru` da aplicação, carregue o exemplo e construa uma instância:

```ruby
require_relative 'exemplos/sinatra'

run ExemploMailcoreSinatra.construir
```

Execute esse arquivo pelo servidor Rack da sua aplicação, dentro do ambiente
Docker configurado. O exemplo não inicia um servidor ao ser carregado. Configure
HTTPS na entrada da aplicação e preserve a comunicação verificada por HTTPS entre
o SDK e a API. Os testes deste projeto não publicam portas.

A fábrica também aceita `ambiente:` e `cliente:` no boot. Isso permite fornecer um
Hash de configuração isolado e um cliente já configurado, inclusive para testes.
Esses argumentos não são lidos dos parâmetros HTTP. A configuração global do gem
e o carregamento do cliente Ruby continuam independentes do Sinatra.

## Chamar a rota

```sh
curl --request POST "$URL_APLICACAO/enviar" \
  --header "Authorization: Bearer $TOKEN_APLICACAO" \
  --header 'Idempotency-Key: pedido-123-confirmacao' \
  --header 'Content-Type: application/json' \
  --data '{}'
```

O corpo precisa ser um objeto JSON válido em UTF-8, com até 4 KiB. Seus campos são
ignorados pelo envio fixo. A chave de idempotência é obrigatória, contém de 1 a 256
caracteres ASCII visíveis e não aceita vírgulas. Preserve a mesma chave para uma
repetição explícita da mesma intenção de negócio.

A resposta de aceitação é `202`, contendo apenas `id` e `estado`. A aceitação da
API não comprova entrega SMTP. Autenticação inválida retorna `401`; chave de
idempotência ou JSON inválido, `400`; conteúdo acima do limite, `413`; tipo de
conteúdo diferente de JSON, `415`. Rotas e métodos sem implementação recebem
`404` sem chamar o SDK.

Falhas da API preservam um status de erro HTTP aplicável, com mensagem genérica.
Falhas de comunicação, redirecionamentos recusados e respostas de aceitação
incompletas resultam em `502`. O exemplo não devolve mensagens privadas de erro,
cabeçalhos da API, chaves ou detalhes internos, e não faz repetição automática.

## Verificação

O arquivo `testes/testes_sinatra.rb`, no repositório de fontes, usa Sinatra e
`Rack::MockRequest` reais, com um cliente sintético injetado no boot. A verificação
local concluiu 11 testes e 250 asserções em Ruby 3.4, sem falhas. Ela exercita
roteamento, autorização, configuração, corpo malicioso, JSON/UTF-8, limites,
idempotência repassada, respostas sanitizadas e falhas sem repetição.

Os testes não abrem um listener, não chamam a API externa e não enviam SMTP. A
repetição com a mesma chave confirma que o exemplo a preserva; a deduplicação na
API real depende do contrato do servidor. A matriz geral pode ser executada pelo
verificador Docker do projeto, `sh scripts/verificar.sh`, sem instalar Ruby ou
gems no host.

Fontes dos componentes:
[documentação do Sinatra](https://sinatrarb.com/intro.html),
[Sinatra 4.2.1](https://rubygems.org/gems/sinatra/versions/4.2.1) e
[Rack](https://github.com/rack/rack).
