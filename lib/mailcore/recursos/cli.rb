# frozen_string_literal: true

module Mailcore
  module Recursos
    class ConcessoesCli < Base
      def listar(filtros = {}, **opcoes)
        executar('GET', "/cli/oauth/grants", consulta: filtros, **opcoes)
      end

      def revogar(id, **opcoes)
        executar('POST', "/cli/oauth/grants/#{segmento(id)}/revoke", **opcoes)
      end
    end

    class CliMailcore < Base
      attr_reader :concessoes

      def initialize(transporte)
        super(transporte)
        @concessoes = ConcessoesCli.new(transporte)
      end
    end
  end
end
