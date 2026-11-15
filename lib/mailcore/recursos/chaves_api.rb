# frozen_string_literal: true

module Mailcore
  module Recursos
    class ChavesApi < Base
      def criar(pedido, **opcoes)
        executar('POST', "/api-keys", corpo: pedido, **opcoes)
      end

      def listar(**opcoes)
        executar('GET', "/api-keys", **opcoes)
      end

      def renomear(id, pedido, **opcoes)
        executar('PATCH', "/api-keys/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def revogar(id, **opcoes)
        executar('DELETE', "/api-keys/#{segmento(id)}", **opcoes)
      end
    end
  end
end
