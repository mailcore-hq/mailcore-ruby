# frozen_string_literal: true

module Mailcore
  module Recursos
    class Recebimento < Base
      def listar(filtros = {}, **opcoes)
        executar('GET', "/receiving", consulta: filtros, **opcoes)
      end

      def obter(id, filtros = {}, **opcoes)
        executar('GET', "/receiving/#{segmento(id)}", consulta: filtros, **opcoes)
      end

      def listar_anexos(id, **opcoes)
        executar('GET', "/receiving/#{segmento(id)}/attachments", **opcoes)
      end

      def obter_anexo(id, anexo_id, **opcoes)
        executar('GET', "/receiving/#{segmento(id)}/attachments/#{segmento(anexo_id)}", **opcoes)
      end

      def baixar_original(id, **opcoes)
        executar('GET', "/receiving/#{segmento(id)}/raw", formato: :bytes, **opcoes)
      end

      def baixar_anexo(id, anexo_id, **opcoes)
        executar(
          'GET',
          "/receiving/#{segmento(id)}/attachments/#{segmento(anexo_id)}/download",
          formato: :bytes,
          **opcoes,
        )
      end

      def baixar_original_fluxo(id, **opcoes, &bloco)
        raise ArgumentError, 'Forneça um bloco para consumir o download.' unless bloco

        executar('GET', "/receiving/#{segmento(id)}/raw", formato: :fluxo, **opcoes, &bloco)
      end

      def baixar_anexo_fluxo(id, anexo_id, **opcoes, &bloco)
        raise ArgumentError, 'Forneça um bloco para consumir o download.' unless bloco

        executar(
          'GET',
          "/receiving/#{segmento(id)}/attachments/#{segmento(anexo_id)}/download",
          formato: :fluxo,
          **opcoes,
          &bloco
        )
      end
    end
  end
end
