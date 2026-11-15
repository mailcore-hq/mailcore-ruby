# frozen_string_literal: true

module Mailcore
  module Recursos
    class Eventos < Base
      def criar(pedido, **opcoes)
        executar('POST', "/events", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/events", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/events/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/events/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/events/#{segmento(id)}", **opcoes)
      end

      def enviar(pedido, **opcoes)
        executar('POST', "/events/send", corpo: pedido, **opcoes)
      end
    end
  end
end
