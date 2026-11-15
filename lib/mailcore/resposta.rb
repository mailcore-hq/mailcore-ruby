# frozen_string_literal: true

module Mailcore
  # JSON mantém o envelope da API; downloads usam String binária ou contagem de bytes.
  class Resposta
    attr_reader :dados, :status, :cabecalhos

    def initialize(dados:, status:, cabecalhos: {})
      @dados = dados
      @status = status
      @cabecalhos = cabecalhos.freeze
    end

    def [](chave)
      dados[chave]
    end

    def inspect
      "#<Mailcore::Resposta status=#{status}>"
    end
  end
end
