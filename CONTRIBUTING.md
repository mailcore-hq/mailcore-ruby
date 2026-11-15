# Contribuir

Use código, comentários e documentação em português do Brasil, preservando nomes
exigidos pelos protocolos Ruby/Rails/HTTP. Recursos ficam em `lib/mailcore/recursos`;
o transporte centraliza autenticação, TLS, erros, prazos e limites.

O servidor é a autoridade para os DTOs, escopos, permissões e transições. Compare
novas operações com as rotas públicas do backend antes de implementá-las. Não
normalize envelopes diferentes nem transforme ausência de campo em `nil` no JSON.

Execute `sh scripts/verificar.sh` com Docker Linux. Não é necessário instalar
ferramentas no host. Mantenha a matriz de runtimes, lockfile de desenvolvimento,
testes de contrato/protocolo e instalação da gem coerentes. Rails é opcional:
carregar o cliente puro não pode exigir Action Mailer ou Action Mailbox.

Use dados sintéticos em testes. Não inicie workers/SMTP ou publique portas para
verificar o cliente. A integração local real usa banco e API exclusivos e remove
seus recursos. Registre o alcance observado sem atribuir ao laboratório prova de
entrega, desempenho cloud ou configuração de uma conta de produção.

Os comandos de verificação não devem publicar pacotes ou fazer deploy. Uma
implantação posterior no Mailcore precisa ser testada no ambiente de produção.
