# frozen_string_literal: true

module Mailcore
  module Recursos
    class SegmentosContato < Base
      def listar(contato_id, **opcoes)
        executar('GET', "/contacts/#{segmento(contato_id)}/segments", **opcoes)
      end

      def adicionar(contato_id, segmento_id, **opcoes)
        executar(
          'POST',
          "/contacts/#{segmento(contato_id)}/segments",
          corpo: { segmento_id: segmento_id },
          aceitar_vazio: true,
          **opcoes,
        )
      end

      def remover(contato_id, segmento_id, **opcoes)
        executar('DELETE', "/contacts/#{segmento(contato_id)}/segments/#{segmento(segmento_id)}", **opcoes)
      end
    end

    class TopicosContato < Base
      def listar(contato_id, **opcoes)
        executar('GET', "/contacts/#{segmento(contato_id)}/topics", **opcoes)
      end

      def atualizar(contato_id, topicos, **opcoes)
        executar('PATCH', "/contacts/#{segmento(contato_id)}/topics", corpo: { topicos: topicos }, **opcoes)
      end
    end

    class ImportacoesContatos < Base
      def prever(pedido, **opcoes)
        executar('POST', "/contacts/imports/preview", corpo: pedido, **opcoes)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/contacts/imports", corpo: pedido, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/contacts/imports/#{segmento(id)}", **opcoes)
      end
    end

    class ExportacoesContatos < Base
      def criar(filtros = {}, **opcoes)
        executar('POST', "/contacts/exports", corpo: filtros, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/contacts/exports", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/contacts/exports/#{segmento(id)}", **opcoes)
      end

      def baixar(id, **opcoes)
        executar('GET', "/contacts/exports/#{segmento(id)}/download", formato: :bytes, **opcoes)
      end

      def baixar_fluxo(id, **opcoes, &bloco)
        raise ArgumentError, 'Forneça um bloco para consumir o download.' unless bloco

        executar('GET', "/contacts/exports/#{segmento(id)}/download", formato: :fluxo, **opcoes, &bloco)
      end
    end

    class Contatos < Base
      attr_reader :segmentos, :topicos, :importacoes, :exportacoes

      def initialize(transporte)
        super(transporte)
        @segmentos = SegmentosContato.new(transporte)
        @topicos = TopicosContato.new(transporte)
        @importacoes = ImportacoesContatos.new(transporte)
        @exportacoes = ExportacoesContatos.new(transporte)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/contacts", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/contacts", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/contacts/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/contacts/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/contacts/#{segmento(id)}", **opcoes)
      end

      def adicionar_em_lote(pedido, **opcoes)
        executar('POST', "/contacts/batch", corpo: pedido, **opcoes)
      end

      def alterar_em_lote(pedido, **opcoes)
        executar('POST', "/contacts/bulk", corpo: pedido, **opcoes)
      end
    end

    class Segmentos < Base
      def criar(pedido, **opcoes)
        executar('POST', "/segments", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/segments", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/segments/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/segments/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/segments/#{segmento(id)}", **opcoes)
      end
    end

    class Topicos < Base
      def criar(pedido, **opcoes)
        executar('POST', "/topics", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/topics", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/topics/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/topics/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/topics/#{segmento(id)}", **opcoes)
      end
    end

    class PropriedadesContatos < Base
      def criar(pedido, **opcoes)
        executar('POST', "/contact-properties", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/contact-properties", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/contact-properties/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/contact-properties/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/contact-properties/#{segmento(id)}", **opcoes)
      end
    end
  end
end
