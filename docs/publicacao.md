# Publicação e consumo da gem Ruby

A versão alpha [`mailcore` `0.1.0.alpha.1`](https://rubygems.org/gems/mailcore/versions/0.1.0.alpha.1)
foi publicada e sua instalação pública validada em 15/11/2026.

```sh
gem install mailcore --version 0.1.0.alpha.1 --no-prerelease
```

O SDK requer Ruby 3.3 ou superior. A versão alpha está fixada explicitamente;
`--no-prerelease` evita candidatos prerelease nas dependências. No RubyGems 3.6.9,
o argumento `--version` com alpha habilita essa resolução automaticamente quando
não há opção explícita, conforme o [código oficial do RubyGems](https://github.com/rubygems/rubygems/blob/v3.6.9/lib/rubygems/version_option.rb#L61-L64).
Retirar somente `--pre` não bastou no ensaio observado.

## Origem e integridade

| Referência | Valor |
|---|---|
| Versão do RubyGems | `0.1.0.alpha.1` |
| Tag anotada, imutável | [`v0.1.0.alpha.1`](https://github.com/mailcore-hq/mailcore-ruby/tree/v0.1.0.alpha.1) |
| Objeto da tag | `582d9a35c4980c151f26401e9135e22e743dca24` |
| Commit da publicação | [`47c62fcfc79ab75115031fc40f240354da2f5b3a`](https://github.com/mailcore-hq/mailcore-ruby/commit/47c62fcfc79ab75115031fc40f240354da2f5b3a) |
| Execução manual do workflow | [`43749864519`](https://github.com/mailcore-hq/mailcore-ruby/actions/runs/43749864519) |
| Artefato aprovado pelo CI | `14175477551` |
| SHA-256 da gem publicada | `17185526fa1c9fd62a01fbab0f2e21fc96015541493982e83f1f6dff32f791b2` |
| SHA-256 do ZIP de artefato do CI | `df0258c69072d4cb9530cf9c48162931f949a7ddd2effe26f6b88539a7f67e20` |

A [API de versão do RubyGems](https://rubygems.org/api/v2/rubygems/mailcore/versions/0.1.0.alpha.1.json)
e o [download público](https://rubygems.org/downloads/mailcore-0.1.0.alpha.1.gem)
concordaram no SHA-256. A gem interna do ZIP aprovado no CI, a recebida do
registro e a instalada pelo consumidor eram idênticas byte a byte.

Os 45 arquivos empacotados corresponderam integralmente ao commit da publicação.
A preparação local anterior tinha SHA-256
`99fb7fb71d16daafe05faa09f55b1f6010f96b1b1d1338639c857d892b78ad96`:
seus cabeçalhos TAR usavam modo `0664`, enquanto o CI usou `0644`, com os
checksums correspondentes. O conteúdo dos 45 arquivos e `metadata.gz` eram
idênticos; nenhuma mudança de implementação explica essa diferença.
Atualizações documentais posteriores em `main` não substituem a gem publicada.

## Consumidor público

A instalação partiu do RubyGems padrão, com cache e `GEM_HOME` vazios, usando
Ruby 3.4.12 e RubyGems 3.6.9. O comando recomendado carregou somente dependências
estáveis: JSON 2.21.2, net-http 0.10.0, OpenSSL 4.0.2, base64 0.3.0 e timeout 0.6.1.

O consumidor executou fora do checkout e confirmou o carregamento da gem
instalada, os 16 recursos principais, 151 métodos e três callbacks. As
151 requisições HTTP foram sintéticas e executadas sem rede; não houve credencial
real, envio de e-mail ou medição de desempenho de produção. Rails e Sinatra
permaneceram opcionais. Containers e diretório de instalação foram removidos,
sem criação de volumes persistentes.
