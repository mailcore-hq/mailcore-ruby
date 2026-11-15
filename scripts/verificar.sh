#!/bin/sh
set -eu
raiz=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$raiz/docs" "$raiz/pkg"
definir_base() {
  case "$1" in
    3.3) base=ruby:3.3-slim-bookworm@sha256:ff0602276269e3a8aa65fbe8e3b8f67b294c79a1419af4fd73b27f1d6b3fbfd9 ;;
    3.4) base=ruby:3.4-slim-bookworm@sha256:c81ac5a2118161a9e01cfbb2da6d68ae1c96d3e6dff14fb1f7f485fee538babe ;;
    4.0) base=ruby:4.0-slim-bookworm@sha256:7b4fd26ff09739374536c8061253a9bd4a8e0055dc71f91c68f61548af223087 ;;
  esac
}
for perfil in 3.3 3.4 4.0; do
  definir_base "$perfil"
  docker build --target testes --build-arg "RUBY_IMAGE=$base" --tag "mailcore/ruby-testes:$perfil" "$raiz"
  imagem=$(docker image inspect "mailcore/ruby-testes:$perfil" --format '{{.Id}}')
  docker run --rm --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges:true --memory 1g --pids-limit 128 \
    --tmpfs /tmp:rw,nosuid,size=256m,mode=1777 --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=$raiz,dst=/sdk,readonly" \
    --mount "type=bind,src=$raiz/docs,dst=/relatorios" \
    --env "MAILCORE_IMAGEM_TESTE=$imagem" \
    "$imagem" bundle exec ruby scripts/executar_testes.rb
  docker run --rm --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges:true --memory 1g --pids-limit 128 \
    --tmpfs /tmp:rw,nosuid,size=128m,mode=1777 --user "$(id -u):$(id -g)" \
    --mount "type=bind,src=$raiz,dst=/sdk,readonly" \
    --mount "type=bind,src=$raiz/docs,dst=/relatorios" \
    --env "MAILCORE_IMAGEM_TESTE=$imagem" \
    "$imagem" ruby scripts/executar_testes.rb --http-padrao
done
docker build --target distribuicao --tag mailcore/ruby-distribuicao:local "$raiz"
container=$(docker create mailcore/ruby-distribuicao:local)
trap 'docker rm --force "$container" >/dev/null 2>&1 || true' EXIT HUP INT TERM
docker cp "$container:/pacotes/." "$raiz/pkg/"
docker rm "$container" >/dev/null
trap - EXIT HUP INT TERM
for perfil in 3.3 3.4 4.0; do
  definir_base "$perfil"
  docker run --rm --network none --read-only --tmpfs /tmp:rw,exec,nosuid,size=96m,mode=1777 \
    --user "$(id -u):$(id -g)" --env GEM_HOME=/tmp/gems \
    --mount "type=bind,src=$raiz/pkg,dst=/pacotes,readonly" \
    --mount "type=bind,src=$raiz/scripts,dst=/scripts,readonly" \
    "$base" sh -c \
    'gem install --local --no-document /pacotes/mailcore-0.1.0.alpha.1.gem && ruby /scripts/verificar_instalacao.rb'
done
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$raiz/pkg,dst=/pacotes" mailcore/ruby-distribuicao:local \
  ruby -rdigest -e 'arquivo="/pacotes/mailcore-0.1.0.alpha.1.gem"; File.write(arquivo+".sha256", Digest::SHA256.file(arquivo).hexdigest+"  "+File.basename(arquivo)+"\n")'
