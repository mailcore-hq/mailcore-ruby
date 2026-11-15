# frozen_string_literal: true

module Mailcore
  class Cliente
    RECURSOS = {
      emails: Recursos::Emails, lotes: Recursos::Lotes, dominios: Recursos::Dominios,
      chaves_api: Recursos::ChavesApi, contatos: Recursos::Contatos,
      segmentos: Recursos::Segmentos, topicos: Recursos::Topicos,
      propriedades_contatos: Recursos::PropriedadesContatos, modelos: Recursos::Modelos,
      webhooks: Recursos::Webhooks, campanhas: Recursos::Campanhas,
      automacoes: Recursos::Automacoes, eventos: Recursos::Eventos,
      recebimento: Recursos::Recebimento, caixas: Recursos::Caixas, cli: Recursos::CliMailcore
    }.freeze
    attr_reader(*RECURSOS.keys)

    def initialize(chave_api: -> { ENV['MAILCORE_API_KEY'] }, **opcoes)
      transporte = Transporte.new(chave_api: chave_api, **opcoes)
      RECURSOS.each do |nome, classe|
        instance_variable_set("@#{nome}", classe.new(transporte))
      end
    end

    def inspect
      '#<Mailcore::Cliente credenciais=protegidas>'
    end
  end
end
