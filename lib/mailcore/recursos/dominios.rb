# frozen_string_literal: true

module Mailcore
  module Recursos
    class Dominios < Base
      def criar(pedido, **opcoes)
        executar('POST', "/domains", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/domains", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/domains/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/domains/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/domains/#{segmento(id)}", **opcoes)
      end

      def registros_dns(id, **opcoes)
        executar('GET', "/domains/#{segmento(id)}/dns", **opcoes)
      end

      def verificar(id, **opcoes)
        executar('POST', "/domains/#{segmento(id)}/verify", **opcoes)
      end
    end
  end
end
