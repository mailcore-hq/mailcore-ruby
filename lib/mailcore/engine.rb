# frozen_string_literal: true

require 'rails/engine'
require 'action_mailbox/engine'
require 'mail'
require 'mailcore'
require 'mailcore/limite_ingress'

module Mailcore
  class ErroEnvelopeActionMailbox < ArgumentError; end

  # Preserva os bytes MIME e acrescenta somente o envelope autenticado do evento.
  class MensagemActionMailbox
    def initialize(email_id:, destinatarios:, cliente: Mailcore.cliente)
      @email_id = email_id
      @destinatarios = validar_destinatarios(destinatarios)
      @cliente = cliente
    end

    def original
      fonte = @cliente.recebimento.baixar_original(@email_id).dados
      unless fonte.is_a?(String) && (fonte.include?("\r\n\r\n") || fonte.include?("\n\n"))
        raise Mailcore::Erro, 'O original recebido não contém uma mensagem MIME válida.'
      end

      prefixo = @destinatarios.sort.map { |endereco| "X-Original-To: #{endereco}\r\n" }.join.b
      prefixo + fonte.b
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private

    def validar_destinatarios(destinatarios)
      unless destinatarios.is_a?(Array) && !destinatarios.empty? && destinatarios.length <= 100
        raise ErroEnvelopeActionMailbox, 'O evento deve informar os destinatários do envelope.'
      end

      destinatarios.each do |endereco|
        unless endereco.is_a?(String) && endereco.bytesize <= 254 &&
               endereco.bytes.all? { |byte| byte.between?(33, 126) }
          raise ErroEnvelopeActionMailbox, 'Destinatário de envelope inválido.'
        end
        analisado = Mail::Address.new(endereco)
        unless analisado.address == endereco && analisado.local && analisado.domain
          raise ErroEnvelopeActionMailbox, 'Destinatário de envelope inválido.'
        end
      end
      destinatarios.uniq
    rescue Mail::Field::ParseError
      raise ErroEnvelopeActionMailbox, 'Destinatário de envelope inválido.'
    end
  end

  class Engine < ::Rails::Engine
    config.root = File.expand_path('../..', __dir__)

    initializer 'mailcore.action_mailbox.limite' do |aplicacao|
      aplicacao.middleware.insert_before 0, ::Mailcore::LimiteIngress
    end

    initializer 'mailcore.action_mailbox.rotas' do |aplicacao|
      aplicacao.routes.append do
        post '/rails/action_mailbox/mailcore/inbound_emails',
             to: 'action_mailbox/ingresses/mailcore/inbound_emails#create', format: false
      end
    end
  end
end
