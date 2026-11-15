ARG RUBY_IMAGE=ruby:3.4-slim-bookworm@sha256:c81ac5a2118161a9e01cfbb2da6d68ae1c96d3e6dff14fb1f7f485fee538babe
FROM ${RUBY_IMAGE} AS testes
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates openssl libssl-dev libyaml-dev build-essential python3 git && rm -rf /var/lib/apt/lists/*
COPY --from=docker:29-cli@sha256:5a7af0dcb0e46c803efe9b45371dd21cb500e5b4453250394ac6f06d49b6e6f1 /usr/local/bin/docker /usr/local/bin/docker
WORKDIR /sdk
COPY Gemfile Gemfile.lock mailcore.gemspec ./
COPY lib/mailcore/versao.rb ./lib/mailcore/versao.rb
RUN bundle install
COPY . .
CMD ["bundle", "exec", "rake", "testes"]

FROM ${RUBY_IMAGE} AS distribuicao
WORKDIR /sdk
COPY . .
RUN mkdir -p /pacotes && gem build mailcore.gemspec --output /pacotes/mailcore-0.1.0.alpha.1.gem
