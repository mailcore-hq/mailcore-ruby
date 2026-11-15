# frozen_string_literal: true

require 'rails/railtie'
require 'mailcore/action_mailer'

module Mailcore
  class Railtie < ::Rails::Railtie
    initializer 'mailcore.action_mailer' do
      ActiveSupport.on_load(:action_mailer) do
        add_delivery_method :mailcore, ::Mailcore::EntregaActionMailer
      end
    end
  end
end

require 'mailcore/engine' if defined?(::ActionMailbox::Engine)
