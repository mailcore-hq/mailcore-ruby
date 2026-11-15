# frozen_string_literal: true

module Mailcore
  module Recursos
    class EventosWebhook < Base
      def listar(webhook_id, filtros = {}, **opcoes)
        executar('GET', "/webhooks/#{segmento(webhook_id)}/events", consulta: filtros, **opcoes)
      end

      def obter(webhook_id, evento_id, **opcoes)
        executar('GET', "/webhooks/#{segmento(webhook_id)}/events/#{segmento(evento_id)}", **opcoes)
      end

      def listar_tentativas(webhook_id, evento_id, filtros = {}, **opcoes)
        executar(
          'GET',
          "/webhooks/#{segmento(webhook_id)}/events/#{segmento(evento_id)}/attempts",
          consulta: filtros,
          **opcoes,
        )
      end

      def reenviar(webhook_id, evento_id, **opcoes)
        executar('POST', "/webhooks/#{segmento(webhook_id)}/events/#{segmento(evento_id)}/replay", **opcoes)
      end
    end

    class Webhooks < Base
      attr_reader :eventos

      def initialize(transporte)
        super(transporte)
        @eventos = EventosWebhook.new(transporte)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/webhooks", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/webhooks", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/webhooks/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/webhooks/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/webhooks/#{segmento(id)}", **opcoes)
      end
    end
  end
end
