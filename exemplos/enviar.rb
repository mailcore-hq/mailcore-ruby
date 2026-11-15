# frozen_string_literal: true

require 'mailcore'

cliente = Mailcore::Cliente.new(chave_api: ENV.fetch('MAILCORE_API_KEY'))
pedido = {
  remetente: ENV.fetch('MAILCORE_REMETENTE'),
  destinatarios: [ENV.fetch('MAILCORE_DESTINATARIO')],
  assunto: 'Integração Ruby Mailcore',
  texto: 'Sua integração Ruby está pronta.',
  html: '<p>Sua integração Ruby está pronta.</p>'
}
resposta = cliente.emails.enviar(pedido, chave_idempotencia: ENV.fetch('CHAVE_IDEMPOTENCIA'))
puts resposta[:id]
