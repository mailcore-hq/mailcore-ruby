# frozen_string_literal: true

require_relative 'mailcore/versao'
require_relative 'mailcore/erros'
require_relative 'mailcore/resposta'
require_relative 'mailcore/configuracao'
require_relative 'mailcore/transporte'
require_relative 'mailcore/assinatura'
require_relative 'mailcore/recursos/base'
%w[emails dominios chaves_api contatos modelos webhooks campanhas automacoes eventos recebimento caixas cli].each do |nome|
  require_relative "mailcore/recursos/#{nome}"
end
require_relative 'mailcore/cliente'

module Mailcore
  class << self
    def configuracao
      @configuracao ||= Configuracao.new
    end

    # Configure no boot. Para credenciais distintas em paralelo, use instâncias Cliente.
    def configurar
      yield configuracao
    end

    def cliente
      Cliente.new(**configuracao.opcoes_cliente)
    end

    def verificar_assinatura(**opcoes)
      Assinatura.verificar(**opcoes)
    end
  end
end

require_relative 'mailcore/railtie' if defined?(Rails::Railtie)
