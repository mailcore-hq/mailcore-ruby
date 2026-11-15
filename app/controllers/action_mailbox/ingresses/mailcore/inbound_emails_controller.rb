# frozen_string_literal: true

module ActionMailbox
  module Ingresses
    module Mailcore
      class InboundEmailsController < ::ActionMailbox::BaseController
        LIMITE_EVENTO_BYTES = ::Mailcore::LimiteIngress::LIMITE_BYTES
        class_attribute :cliente_mailcore, instance_accessor: false, default: nil

        def create
          return head :content_too_large if request.content_length.to_i > LIMITE_EVENTO_BYTES

          corpo = request.body.read(LIMITE_EVENTO_BYTES + 1).to_s
          return head :content_too_large if corpo.bytesize > LIMITE_EVENTO_BYTES

          segredo = segredo_assinatura
          return head :service_unavailable unless segredo.is_a?(String) && !segredo.empty?

          evento = ::Mailcore.verificar_assinatura(
            corpo_bruto: corpo,
            cabecalhos: {
              'svix-id' => request.headers['svix-id'],
              'svix-timestamp' => request.headers['svix-timestamp'],
              'svix-signature' => request.headers['svix-signature']
            },
            segredo: segredo
          )
          return head :no_content unless evento[:type] == 'email.received'

          dados = evento[:data]
          unless dados.is_a?(Hash) && dados[:email_id].is_a?(String) && !dados[:email_id].empty?
            return head :unprocessable_entity
          end

          fonte = ::Mailcore::MensagemActionMailbox.new(
            email_id: dados[:email_id], destinatarios: dados[:to],
            cliente: self.class.cliente_mailcore || ::Mailcore.cliente
          ).original
          ::ActionMailbox::InboundEmail.create_and_extract_message_id!(fonte)
          head :no_content
        rescue ::Mailcore::ErroAssinatura
          head :unauthorized
        rescue ::Mailcore::ErroEnvelopeActionMailbox
          head :unprocessable_entity
        rescue ::Mailcore::Erro
          head :service_unavailable
        end

        private

        def segredo_assinatura
          segredo = Rails.application.credentials.dig(:action_mailbox, :mailcore_segredo) ||
                    ::Mailcore.configuracao.segredo_webhook
          segredo.respond_to?(:call) ? segredo.call : segredo
        end
      end
    end
  end
end
