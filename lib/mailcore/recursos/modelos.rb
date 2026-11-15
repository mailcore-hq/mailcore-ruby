# frozen_string_literal: true

module Mailcore
  module Recursos
    class VersoesModelo < Base
      def listar(modelo_id, filtros = {}, **opcoes)
        executar('GET', "/templates/#{segmento(modelo_id)}/versions", consulta: filtros, **opcoes)
      end

      def obter(modelo_id, versao_id, **opcoes)
        executar('GET', "/templates/#{segmento(modelo_id)}/versions/#{segmento(versao_id)}", **opcoes)
      end

      def restaurar(modelo_id, versao_id, pedido, **opcoes)
        executar(
          'POST',
          "/templates/#{segmento(modelo_id)}/versions/#{segmento(versao_id)}/restore",
          corpo: pedido,
          **opcoes,
        )
      end

      def prever(modelo_id, versao_id, pedido = {}, **opcoes)
        executar(
          'POST',
          "/templates/#{segmento(modelo_id)}/versions/#{segmento(versao_id)}/preview",
          corpo: pedido,
          **opcoes,
        )
      end
    end

    class PastasModelo < Base
      def listar(**opcoes)
        executar('GET', "/template-folders", **opcoes)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/template-folders", corpo: pedido, **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/template-folders/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/template-folders/#{segmento(id)}", **opcoes)
      end
    end

    class Modelos < Base
      attr_reader :versoes, :pastas

      def initialize(transporte)
        super(transporte)
        @versoes = VersoesModelo.new(transporte)
        @pastas = PastasModelo.new(transporte)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/templates", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/templates", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/templates/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/templates/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/templates/#{segmento(id)}", **opcoes)
      end

      def prever(id, pedido, **opcoes)
        executar('POST', "/templates/#{segmento(id)}/preview", corpo: pedido, **opcoes)
      end

      def obter_previa(organizacao_id, previa_id, **opcoes)
        executar(
          'GET',
          "/template-previews/#{segmento(organizacao_id)}/#{segmento(previa_id)}",
          formato: :texto,
          **opcoes,
        )
      end

      def testar(id, pedido, **opcoes)
        executar('POST', "/templates/#{segmento(id)}/test", corpo: pedido, **opcoes)
      end

      def publicar(id, pedido, **opcoes)
        executar('POST', "/templates/#{segmento(id)}/publish", corpo: pedido, **opcoes)
      end

      def duplicar(id, pedido = {}, **opcoes)
        executar('POST', "/templates/#{segmento(id)}/duplicate", corpo: pedido, **opcoes)
      end
    end
  end
end
