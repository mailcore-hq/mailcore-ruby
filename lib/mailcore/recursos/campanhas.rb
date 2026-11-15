# frozen_string_literal: true

module Mailcore
  module Recursos
    class Campanhas < Base
      def criar(pedido, **opcoes)
        executar('POST', "/broadcasts", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/broadcasts", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/broadcasts/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/broadcasts/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/broadcasts/#{segmento(id)}", **opcoes)
      end

      def duplicar(id, pedido = {}, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/duplicate", corpo: pedido, **opcoes)
      end

      def revisar(id, pedido, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/review", corpo: pedido, **opcoes)
      end

      def enviar(id, pedido, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/send", corpo: pedido, **opcoes)
      end

      def cancelar(id, pedido, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/cancel", corpo: pedido, **opcoes)
      end

      def prever(id, pedido = {}, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/preview", corpo: pedido, **opcoes)
      end

      def testar(id, pedido, **opcoes)
        executar('POST', "/broadcasts/#{segmento(id)}/test", corpo: pedido, **opcoes)
      end

      def ler_previa(organizacao_id, previa_id, **opcoes)
        executar(
          'GET',
          "/broadcast-previews/#{segmento(organizacao_id)}/#{segmento(previa_id)}",
          formato: :texto,
          **opcoes,
        )
      end

      def obter_metricas(id, **opcoes)
        executar('GET', "/broadcasts/#{segmento(id)}/metrics", **opcoes)
      end

      def listar_destinatarios(id, filtros = {}, **opcoes)
        executar('GET', "/broadcasts/#{segmento(id)}/recipients", consulta: filtros, **opcoes)
      end

      def listar_links_clicados(id, filtros = {}, **opcoes)
        executar('GET', "/broadcasts/#{segmento(id)}/clicked-links", consulta: filtros, **opcoes)
      end
    end
  end
end
