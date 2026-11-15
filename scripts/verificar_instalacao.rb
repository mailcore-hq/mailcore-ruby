# frozen_string_literal: true

require 'mailcore'
require 'json'

raise 'Rails foi carregado pelo cliente puro.' if defined?(Rails) || defined?(ActionMailer) || defined?(Sinatra)
cliente = Mailcore::Cliente.new(chave_api: 'mc_sintetica_instalacao')
raise 'Recursos ausentes.' unless Mailcore::Cliente::RECURSOS.size == 16 && cliente.contatos.exportacoes && cliente.caixas.conversas.emails
raise 'Transporte incompatível.' unless Net::HTTP.instance_methods.include?(:max_retries=)
puts JSON.generate(resultado: 'aprovado', ruby: RUBY_VERSION, versao: Mailcore::VERSAO,
                   net_http: Net::HTTP::VERSION, json: JSON::VERSION, rails_carregado: false)
