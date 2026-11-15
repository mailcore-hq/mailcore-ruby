# frozen_string_literal: true

require 'sinatra/base'
require 'mailcore'
require 'openssl'
require 'digest'

class ExemploMailcoreSinatra < Sinatra::Base
  disable :show_exceptions, :dump_errors, :logging, :sessions, :static
  set :raise_errors, false

  def self.construir(ambiente: ENV, cliente: nil)
    chave, token = ambiente.values_at('MAILCORE_API_KEY', 'TOKEN_APLICACAO')
    remetente, destinatario = ambiente.values_at('MAILCORE_REMETENTE', 'MAILCORE_DESTINATARIO')
    valido = chave.is_a?(String) && chave.match?(/\A[\x21-\x7e]{1,512}\z/) &&
             token.is_a?(String) && token.match?(/\A[A-Za-z0-9_-]{32,256}\z/) &&
             [remetente, destinatario].all? { |valor| valor.is_a?(String) && valor.match?(/\A[^\r\n\x00]{1,320}\z/) }
    raise ArgumentError, 'Configure as credenciais e os endereços fixos da aplicação.' unless valido
    resumo = Digest::SHA256.digest(token)
    if OpenSSL.fixed_length_secure_compare(resumo, Digest::SHA256.digest(chave))
      raise ArgumentError, 'Use credenciais diferentes para a aplicação e a API.'
    end
    sdk = cliente || Mailcore::Cliente.new(chave_api: chave, url_base: ambiente.fetch('MAILCORE_API_URL', Mailcore.configuracao.url_base))
    Class.new(self) do
      set :cliente_mailcore, sdk
      set :resumo_token, resumo
      set :pedido_mailcore, { remetente: remetente, destinatarios: [destinatario].freeze,
                             assunto: 'Mensagem de exemplo', texto: 'Integração Mailcore com Sinatra.' }.freeze
    end
  end

  before do
    content_type :json
    headers 'cache-control' => 'no-store'
  end

  post '/enviar' do
    autorizacao = request.env['HTTP_AUTHORIZATION'].to_s.match(/\ABearer ([A-Za-z0-9_-]{32,256})\z/)
    halt 401, JSON.generate(erro: 'Acesso não autorizado.') unless autorizacao &&
      OpenSSL.fixed_length_secure_compare(Digest::SHA256.digest(autorizacao[1]), settings.resumo_token)
    chave = request.env['HTTP_IDEMPOTENCY_KEY'].to_s
    halt 400, JSON.generate(erro: 'Informe uma chave de idempotência válida.') unless chave.match?(/\A[\x21-\x7e]{1,256}\z/) && !chave.include?(',')
    halt 415, JSON.generate(erro: 'Envie um objeto JSON.') unless request.media_type == 'application/json'
    corpo = request.body.read(4097).to_s.dup
    halt 413, JSON.generate(erro: 'Corpo da requisição excede o limite.') if corpo.bytesize > 4096
    corpo.force_encoding(Encoding::UTF_8)
    halt 400, JSON.generate(erro: 'Envie um objeto JSON válido.') unless corpo.valid_encoding?
    halt 400, JSON.generate(erro: 'Envie um objeto JSON válido.') unless JSON.parse(corpo).is_a?(Hash)
    resposta = settings.cliente_mailcore.emails.enviar(settings.pedido_mailcore.dup, chave_idempotencia: chave)
    dados = resposta.dados
    halt 502, JSON.generate(erro: 'Resposta de aceitação inválida.') unless dados.is_a?(Hash) &&
      dados[:id].is_a?(String) && !dados[:id].empty? && dados[:estado].is_a?(String)
    status 202
    JSON.generate(id: dados[:id], estado: dados[:estado])
  rescue JSON::ParserError
    halt 400, JSON.generate(erro: 'Envie um objeto JSON válido.')
  rescue Mailcore::ErroApi => erro
    halt(erro.status.to_i.between?(400, 599) ? erro.status : 502, JSON.generate(erro: 'Não foi possível aceitar a mensagem.'))
  rescue Mailcore::Erro, Mailcore::ErroConfiguracao
    halt 502, JSON.generate(erro: 'Não foi possível confirmar a aceitação da mensagem.')
  end

  not_found { JSON.generate(erro: 'Rota não encontrada.') }
  error { JSON.generate(erro: 'Não foi possível concluir a operação.') }
end
