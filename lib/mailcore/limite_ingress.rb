# frozen_string_literal: true

require 'stringio'

module Mailcore
  # Atua antes dos parsers e da instrumentação do Rails, somente no ingress.
  class LimiteIngress
    CAMINHO = '/rails/action_mailbox/mailcore/inbound_emails'
    LIMITE_BYTES = 256 * 1024
    FILTROS = [:data, :_json, :authorization, /svix[-_]signature/i].freeze

    def initialize(aplicacao)
      @aplicacao = aplicacao
    end

    def call(ambiente)
      caminho = ambiente['PATH_INFO'].to_s.squeeze('/').delete_suffix('/')
      return @aplicacao.call(ambiente) unless ambiente['REQUEST_METHOD'] == 'POST' && caminho == CAMINHO

      tamanho = ambiente['CONTENT_LENGTH'].to_s
      return recusar(413) if tamanho.match?(/\A[0-9]+\z/) && tamanho.to_i > LIMITE_BYTES

      entrada = ambiente['rack.input']
      return recusar(400) unless entrada.respond_to?(:read)

      begin
        corpo = entrada.read(LIMITE_BYTES + 1).to_s.b
      rescue IOError, EOFError
        return recusar(400)
      end
      return recusar(413) if corpo.bytesize > LIMITE_BYTES

      ambiente['rack.input'] = StringIO.new(corpo)
      ambiente['CONTENT_LENGTH'] = corpo.bytesize.to_s
      ambiente.delete('HTTP_TRANSFER_ENCODING')
      ambiente['RAW_POST_DATA'] = corpo
      # O controller usa somente o corpo assinado. Evita parsing e logs JSON
      # automáticos anteriores à autenticação, inclusive em JSON malformado.
      ambiente['action_dispatch.request.request_parameters'] = {}
      ambiente['action_dispatch.parameter_filter'] = Array(ambiente['action_dispatch.parameter_filter']).dup + FILTROS
      @aplicacao.call(ambiente)
    end

    private

    def recusar(status)
      [status, { 'content-type' => 'application/json; charset=utf-8', 'cache-control' => 'no-store' },
       ['{"erro":"Não foi possível aceitar o corpo do webhook."}']]
    end
  end
end
