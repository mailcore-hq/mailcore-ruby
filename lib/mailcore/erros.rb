# frozen_string_literal: true

module Mailcore
  class Erro < StandardError
    attr_reader :codigo, :status, :cabecalhos

    def initialize(mensagem = 'Não foi possível concluir a operação.', codigo: 'erro_mailcore', status: nil, cabecalhos: {})
      super(mensagem)
      @codigo = codigo
      @status = status
      @cabecalhos = cabecalhos.freeze
    end
  end

  class ErroApi < Erro
    def initialize(codigo:, mensagem:, status:, cabecalhos: {})
      super(mensagem, codigo: codigo, status: status, cabecalhos: cabecalhos)
    end
  end

  class ErroConfiguracao < ArgumentError; end
  class ErroTransporte < Erro; end
  class ErroResposta < Erro; end
  class ErroAssinatura < Erro; end
end
