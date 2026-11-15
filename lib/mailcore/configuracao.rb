# frozen_string_literal: true

module Mailcore
  class Configuracao
    attr_accessor :chave_api, :url_base, :tempo_limite, :tempo_conexao,
                  :limite_resposta_bytes, :certificado_ca, :permitir_http_local,
                  :segredo_webhook

    def initialize
      @chave_api = -> { ENV['MAILCORE_API_KEY'] }
      @url_base = 'https://mailcore.com.br/v1'
      @tempo_limite = 30
      @tempo_conexao = 10
      @limite_resposta_bytes = 16 * 1024 * 1024
      @permitir_http_local = false
      @certificado_ca = nil
      @segredo_webhook = -> { ENV['MAILCORE_WEBHOOK_SECRET'] }
    end

    def opcoes_cliente
      { chave_api: chave_api, url_base: url_base, tempo_limite: tempo_limite,
        tempo_conexao: tempo_conexao, limite_resposta_bytes: limite_resposta_bytes,
        certificado_ca: certificado_ca, permitir_http_local: permitir_http_local }
    end

    def inspect
      '#<Mailcore::Configuracao credenciais=protegidas>'
    end
  end
end
