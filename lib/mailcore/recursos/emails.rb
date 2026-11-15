# frozen_string_literal: true

module Mailcore
  module Recursos
    class Emails < Base
      # A aceitação da intenção não comprova a entrega da mensagem.
      def enviar(pedido, **opcoes)
        executar('POST', "/emails", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/emails", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/emails/#{segmento(id)}", **opcoes)
      end

      def reagendar(id, pedido, **opcoes)
        executar('PATCH', "/emails/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def cancelar(id, **opcoes)
        executar('POST', "/emails/#{segmento(id)}/cancel", **opcoes)
      end

      def obter_por_idempotencia(chave, **opcoes)
        executar('GET', "/emails/idempotency/#{segmento(chave)}", **opcoes)
      end

      def eventos(id, **opcoes)
        executar('GET', "/emails/#{segmento(id)}/events", **opcoes)
      end

      def baixar_anexo(id, indice, **opcoes)
        unless indice.is_a?(Integer) && indice >= 0
          raise ArgumentError, 'Informe um índice de anexo inteiro e não negativo.'
        end

        executar('GET', "/emails/#{segmento(id)}/attachments/#{indice}", formato: :bytes, **opcoes)
      end
    end

    class Lotes < Base
      def enviar(pedidos, **opcoes)
        executar('POST', "/emails/batch", corpo: pedidos, **opcoes)
      end

      def obter_por_idempotencia(chave, **opcoes)
        executar('GET', "/emails/batch/idempotency/#{segmento(chave)}", **opcoes)
      end
    end
  end
end
