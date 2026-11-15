# frozen_string_literal: true

require 'base64'
require 'openssl'
require 'json'

module Mailcore
  module Assinatura
    module_function

    # O corpo precisa ser o recebido na rede, antes de interpretar ou normalizar JSON.
    def verificar(corpo_bruto:, cabecalhos:, segredo:, agora: Time.now, tolerancia: 300)
      unless corpo_bruto.is_a?(String) && corpo_bruto.bytesize <= 8 * 1024 * 1024 &&
             segredo.is_a?(String) && segredo.start_with?('whsec_') && segredo.bytesize <= 1024 &&
             tolerancia.is_a?(Integer) && tolerancia.between?(1, 300)
        falhar
      end
      recebidos = {}
      cabecalhos.each do |nome, valor|
        nome = nome.to_s.downcase.tr('_', '-').delete_prefix('http-')
        next unless %w[svix-id svix-timestamp svix-signature].include?(nome)

        falhar if recebidos.key?(nome) || !valor.is_a?(String)
        recebidos[nome] = valor
      end
      id = recebidos['svix-id']
      instante = recebidos['svix-timestamp']
      assinaturas = recebidos['svix-signature']
      falhar unless id&.match?(/\A[\x21-\x7e]{1,256}\z/) &&
                    instante&.match?(/\A[1-9][0-9]{0,15}\z/) &&
                    assinaturas && assinaturas.bytesize <= 4096 &&
                    (agora.to_i - instante.to_i).abs <= tolerancia

      chave = Base64.strict_decode64(segredo.delete_prefix('whsec_'))
      falhar if chave.bytesize < 16
      esperado = OpenSSL::HMAC.digest('SHA256', chave, "#{id}.#{instante}.".b + corpo_bruto.b)
      valido = assinaturas.split(' ').first(32).any? do |assinatura|
        versao, valor = assinatura.split(',', 2)
        next false unless versao == 'v1' && valor

        begin
          recebido = Base64.strict_decode64(valor)
          recebido.bytesize == esperado.bytesize && OpenSSL.fixed_length_secure_compare(recebido, esperado)
        rescue ArgumentError
          false
        end
      end
      falhar unless valido
      evento = JSON.parse(corpo_bruto, symbolize_names: true)
      falhar unless evento.is_a?(Hash) && evento[:type].is_a?(String) &&
                    evento[:created_at].is_a?(String) && evento.key?(:data)
      evento
    rescue ErroAssinatura
      raise
    rescue StandardError
      falhar
    end

    def falhar
      raise ErroAssinatura.new('Não foi possível verificar a autenticidade do webhook.',
                              codigo: 'assinatura_invalida'), cause: nil
    end
  end
end
