# frozen_string_literal: true

require_relative 'lib/mailcore/versao'

Gem::Specification.new do |gem|
  gem.name = 'mailcore'
  gem.version = Mailcore::VERSAO
  gem.authors = ['Mailcore']
  gem.summary = 'Cliente Ruby da API Mailcore e integração opcional com Rails.'
  gem.description = 'Envio, recebimento, contatos e recursos públicos Mailcore com TLS, idempotência e downloads limitados.'
  gem.homepage = 'https://mailcore.com.br'
  gem.license = 'MIT'
  gem.required_ruby_version = '>= 3.3'
  gem.files = Dir['lib/**/*.rb', 'app/**/*.rb', 'config/**/*.rb', 'sig/**/*.rbs',
                  'exemplos/**/*.rb', 'docs/**/*.md', 'docs/**/*.json'] + %w[README.md CHANGELOG.md LICENSE SECURITY.md CONTRIBUTING.md]
  gem.require_paths = ['lib']
  gem.metadata = {
    'allowed_push_host' => 'https://rubygems.org',
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/mailcore-hq/mailcore-ruby',
    'bug_tracker_uri' => 'https://github.com/mailcore-hq/mailcore-ruby/issues',
    'changelog_uri' => 'https://github.com/mailcore-hq/mailcore-ruby/blob/main/CHANGELOG.md'
  }
  gem.add_dependency 'net-http', '>= 0.4', '< 1'
  gem.add_dependency 'json', '>= 2.7', '< 3'
  gem.add_dependency 'openssl', '>= 3.2', '< 5'
  gem.add_dependency 'base64', '>= 0.2', '< 1'
  gem.add_dependency 'timeout', '>= 0.4', '< 1'
end
