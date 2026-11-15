# frozen_string_literal: true

module Mailcore
  module Recursos
    class ExecucoesAutomacoes < Base
      def listar(automacao_id, filtros = {}, **opcoes)
        executar('GET', "/automations/#{segmento(automacao_id)}/runs", consulta: filtros, **opcoes)
      end

      def obter(automacao_id, execucao_id, **opcoes)
        executar('GET', "/automations/#{segmento(automacao_id)}/runs/#{segmento(execucao_id)}", **opcoes)
      end
    end

    class Automacoes < Base
      attr_reader :execucoes

      def initialize(transporte)
        super(transporte)
        @execucoes = ExecucoesAutomacoes.new(transporte)
      end

      def criar(pedido, **opcoes)
        executar('POST', "/automations", corpo: pedido, **opcoes)
      end

      def listar(filtros = {}, **opcoes)
        executar('GET', "/automations", consulta: filtros, **opcoes)
      end

      def obter(id, **opcoes)
        executar('GET', "/automations/#{segmento(id)}", **opcoes)
      end

      def atualizar(id, pedido, **opcoes)
        executar('PATCH', "/automations/#{segmento(id)}", corpo: pedido, **opcoes)
      end

      def remover(id, **opcoes)
        executar('DELETE', "/automations/#{segmento(id)}", **opcoes)
      end

      def duplicar(id, pedido = {}, **opcoes)
        executar('POST', "/automations/#{segmento(id)}/duplicate", corpo: pedido, **opcoes)
      end

      def parar(id, pedido, **opcoes)
        executar('POST', "/automations/#{segmento(id)}/stop", corpo: pedido, **opcoes)
      end
    end
  end
end
