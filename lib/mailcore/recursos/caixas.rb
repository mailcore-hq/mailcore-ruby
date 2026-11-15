# frozen_string_literal: true

module Mailcore
  module Recursos
    class EmailsCaixa < Base
      def listar(caixa_id, conversa_id, filtros = {}, **opcoes)
        executar(
          'GET',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/emails",
          consulta: filtros,
          **opcoes,
        )
      end

      def obter(caixa_id, conversa_id, email_id, **opcoes)
        executar(
          'GET',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/emails/#{segmento(email_id)}",
          **opcoes,
        )
      end

      def responder(caixa_id, conversa_id, email_id, pedido, **opcoes)
        executar(
          'POST',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/emails/#{segmento(email_id)}/reply",
          corpo: pedido,
          **opcoes,
        )
      end

      def encaminhar(caixa_id, conversa_id, email_id, pedido, **opcoes)
        executar(
          'POST',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/emails/#{segmento(email_id)}/forward",
          corpo: pedido,
          **opcoes,
        )
      end
    end

    class EtiquetasConversaCaixa < Base
      def adicionar(caixa_id, conversa_id, ids, **opcoes)
        executar(
          'POST',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/labels",
          corpo: { ids: ids },
          **opcoes,
        )
      end

      def substituir(caixa_id, conversa_id, ids, **opcoes)
        executar(
          'PUT',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/labels",
          corpo: { ids: ids },
          **opcoes,
        )
      end

      def remover(caixa_id, conversa_id, etiqueta_id, **opcoes)
        executar(
          'DELETE',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}/labels/#{segmento(etiqueta_id)}",
          **opcoes,
        )
      end
    end

    class ConversasCaixa < Base
      attr_reader :emails, :etiquetas

      def initialize(transporte)
        super(transporte)
        @emails = EmailsCaixa.new(transporte)
        @etiquetas = EtiquetasConversaCaixa.new(transporte)
      end

      def listar(caixa_id, filtros = {}, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/threads", consulta: filtros, **opcoes)
      end

      def buscar(caixa_id, filtros = {}, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/threads/search", consulta: filtros, **opcoes)
      end

      def obter(caixa_id, conversa_id, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}", **opcoes)
      end

      def atualizar(caixa_id, conversa_id, pedido, **opcoes)
        executar(
          'PATCH',
          "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}",
          corpo: pedido,
          **opcoes,
        )
      end

      def remover(caixa_id, conversa_id, **opcoes)
        executar('DELETE', "/inboxes/#{segmento(caixa_id)}/threads/#{segmento(conversa_id)}", **opcoes)
      end
    end

    class EtiquetasCaixa < Base
      def listar(caixa_id, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/labels", **opcoes)
      end

      def obter(caixa_id, etiqueta_id, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/labels/#{segmento(etiqueta_id)}", **opcoes)
      end

      def criar(caixa_id, pedido, **opcoes)
        executar('POST', "/inboxes/#{segmento(caixa_id)}/labels", corpo: pedido, **opcoes)
      end

      def atualizar(caixa_id, etiqueta_id, pedido, **opcoes)
        executar(
          'PATCH',
          "/inboxes/#{segmento(caixa_id)}/labels/#{segmento(etiqueta_id)}",
          corpo: pedido,
          **opcoes,
        )
      end

      def remover(caixa_id, etiqueta_id, **opcoes)
        executar('DELETE', "/inboxes/#{segmento(caixa_id)}/labels/#{segmento(etiqueta_id)}", **opcoes)
      end
    end

    class RascunhosCaixa < Base
      def listar(caixa_id, filtros = {}, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/drafts", consulta: filtros, **opcoes)
      end

      def obter(caixa_id, rascunho_id, **opcoes)
        executar('GET', "/inboxes/#{segmento(caixa_id)}/drafts/#{segmento(rascunho_id)}", **opcoes)
      end

      def criar(caixa_id, pedido = {}, **opcoes)
        executar('POST', "/inboxes/#{segmento(caixa_id)}/drafts", corpo: pedido, **opcoes)
      end

      def atualizar(caixa_id, rascunho_id, pedido, **opcoes)
        executar(
          'PATCH',
          "/inboxes/#{segmento(caixa_id)}/drafts/#{segmento(rascunho_id)}",
          corpo: pedido,
          **opcoes,
        )
      end

      def remover(caixa_id, rascunho_id, **opcoes)
        executar('DELETE', "/inboxes/#{segmento(caixa_id)}/drafts/#{segmento(rascunho_id)}", **opcoes)
      end

      def enviar(caixa_id, rascunho_id, pedido, **opcoes)
        executar(
          'POST',
          "/inboxes/#{segmento(caixa_id)}/drafts/#{segmento(rascunho_id)}/send",
          corpo: pedido,
          **opcoes,
        )
      end
    end

    class Caixas < Base
      attr_reader :conversas, :etiquetas, :rascunhos

      def initialize(transporte)
        super(transporte)
        @conversas = ConversasCaixa.new(transporte)
        @etiquetas = EtiquetasCaixa.new(transporte)
        @rascunhos = RascunhosCaixa.new(transporte)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/inboxes", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/inboxes", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/inboxes/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/inboxes/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/inboxes/#{segmento(id)}", **opcoes)
      end
    end
  end
end
