# frozen_string_literal: true

require 'base64'
require 'mailcore'

module Mailcore
  # Converte mensagens Mail sem implementar uma fila ou um transporte SMTP.
  class EntregaActionMailer
    CAMPOS_CLIENTE = %i[chave_api url_base tempo_limite tempo_conexao certificado_ca limite_resposta_bytes].freeze
    CABECALHOS_RESERVADOS = %w[
      from to cc bcc sender return-path reply-to subject message-id in-reply-to
      references date received mime-version content-type content-transfer-encoding
      authentication-results dkim-signature authorization mailcore-opcoes
      mailcore_opcoes
    ].freeze

    attr_reader :settings

    def initialize(opcoes = {})
      @settings = { return_response: true }.merge(opcoes.transform_keys(&:to_sym))
    end

    def deliver!(mensagem)
      opcoes = opcoes_mensagem(mensagem)
      pedido = converter(mensagem)
      pedido[:tags] = opcoes[:tags] if opcoes.key?(:tags)
      pedido[:agendada_em] = opcoes[:agendada_em] if opcoes.key?(:agendada_em)
      chave = opcoes.fetch(:chave_idempotencia, settings[:chave_idempotencia])
      argumentos = chave.nil? ? {} : { chave_idempotencia: chave }
      resposta = cliente.emails.enviar(pedido, **argumentos)
      identificador = resposta.dados[:id]
      mensagem.message_id = identificador if identificador
      resposta
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private

    def cliente
      return settings[:cliente] if settings[:cliente]

      configuracao = settings.select { |nome, _| CAMPOS_CLIENTE.include?(nome) }
      return Mailcore.cliente if configuracao.empty?

      Mailcore::Cliente.new(**Mailcore.configuracao.opcoes_cliente.merge(configuracao))
    end

    def opcoes_mensagem(mensagem)
      valor = mensagem[:mailcore_opcoes]&.unparsed_value
      return {} if valor.nil?
      raise ArgumentError, 'mailcore_opcoes deve ser um Hash.' unless valor.is_a?(Hash)

      opcoes = valor.transform_keys(&:to_sym)
      desconhecidas = opcoes.keys - %i[chave_idempotencia tags agendada_em]
      raise ArgumentError, 'Opção de mensagem não reconhecida.' unless desconhecidas.empty?

      opcoes
    end

    def converter(mensagem)
      remetentes = Array(mensagem[:from]&.formatted)
      raise ArgumentError, 'Informe exatamente um remetente.' unless remetentes.length == 1
      raise ArgumentError, 'Informe no máximo um endereço de resposta.' if Array(mensagem.reply_to).length > 1

      pedido = { remetente: remetentes.first, destinatarios: Array(mensagem.to), assunto: mensagem.subject }
      pedido[:cc] = mensagem.cc if mensagem.cc && !mensagem.cc.empty?
      pedido[:cco] = mensagem.bcc if mensagem.bcc && !mensagem.bcc.empty?
      pedido[:responder_para] = mensagem.reply_to.first if mensagem.reply_to && !mensagem.reply_to.empty?
      pedido.merge!(conteudos(mensagem))
      cabecalhos = mensagem.header.fields.each_with_object({}) do |campo, resultado|
        nome = campo.name.to_s
        normalizado = nome.downcase
        next if CABECALHOS_RESERVADOS.include?(normalizado)
        next if normalizado.start_with?('x-postal-', 'x-mailcore-', 'arc-', 'content-')

        resultado[nome] = campo.decoded.to_s
      end
      pedido[:cabecalhos] = cabecalhos unless cabecalhos.empty?
      anexos = mensagem.attachments.map do |parte|
        anexo = {
          nome: parte.filename,
          tipo_conteudo: parte.mime_type || 'application/octet-stream',
          conteudo_base64: Base64.strict_encode64(parte.body.decoded.b)
        }
        anexo[:id_conteudo] = parte.cid if parte.inline?
        anexo
      end
      pedido[:anexos] = anexos unless anexos.empty?
      pedido
    end

    def conteudos(mensagem)
      if mensagem.multipart?
        partes = partes_de_corpo(mensagem)
        texto = partes.find { |parte| parte.mime_type == 'text/plain' }
        html = partes.find { |parte| parte.mime_type == 'text/html' }
        {}.tap do |resultado|
          resultado[:texto] = decodificar_texto(texto) if texto
          resultado[:html] = decodificar_texto(html) if html
        end
      elsif mensagem.mime_type == 'text/html'
        { html: decodificar_texto(mensagem) }
      elsif mensagem.mime_type.nil? || mensagem.mime_type == 'text/plain'
        { texto: decodificar_texto(mensagem) }
      else
        raise ArgumentError, 'Use conteúdo de mensagem em texto ou HTML.'
      end
    end

    def decodificar_texto(parte)
      parte.body.decoded.dup.force_encoding(parte.charset || 'UTF-8').encode(Encoding::UTF_8)
    end

    def partes_de_corpo(parte)
      return [] if parte.attachment?
      return [parte] unless parte.multipart?

      parte.parts.flat_map { |filha| partes_de_corpo(filha) }
    end
  end
end
