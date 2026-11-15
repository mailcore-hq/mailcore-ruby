# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
ENV['DATABASE_URL'] = 'sqlite3::memory:'
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'rails'
require 'active_record/railtie'
require 'active_job/railtie'
require 'active_storage/engine'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'mailcore'
require 'mailcore/railtie'
require 'mailcore/engine'

PASTA_ARMAZENAMENTO_MAILCORE_TESTE = Dir.mktmpdir('mailcore-action-mailbox-')

class AplicacaoIngressMailcoreTeste < Rails::Application
  config.load_defaults 8.1
  config.eager_load = false
  config.secret_key_base = 'chave-exclusiva-sintetica-para-testes-locais-' * 3
  config.hosts = []
  config.logger = Logger.new(File::NULL)
  config.active_job.queue_adapter = :test
  config.action_mailbox.ingress = :mailcore
  config.active_storage.service = :teste_mailcore
  config.active_storage.service_configurations = {
    teste_mailcore: { service: 'Disk', root: PASTA_ARMAZENAMENTO_MAILCORE_TESTE }
  }
end

Rails.application.initialize!
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:active_storage_blobs) do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index :key, unique: true
  end
  create_table(:active_storage_attachments) do |t|
    t.string :name, null: false
    t.references :record, null: false, polymorphic: true
    t.references :blob, null: false
    t.datetime :created_at, null: false
    t.index %i[record_type record_id name blob_id], unique: true, name: :indice_anexos_teste_unicos
  end
  create_table(:action_mailbox_inbound_emails) do |t|
    t.integer :status, default: 0, null: false
    t.string :message_id, null: false
    t.string :message_checksum, null: false
    t.timestamps
    t.index %i[message_id message_checksum], unique: true, name: :indice_emails_teste_unicos
  end
end

require 'action_dispatch/testing/integration'

Minitest.after_run { FileUtils.remove_entry(PASTA_ARMAZENAMENTO_MAILCORE_TESTE) }

class ClienteOriginalSintetico
  attr_reader :consultas
  attr_accessor :falha

  ORIGINAL = "From: origem@example.test\r\nTo: publico@example.test\r\n" \
             "Subject: Recebido\r\nMessage-ID: <mensagem-local@example.test>\r\n" \
             "Content-Type: text/plain; charset=UTF-8\r\n\r\nCorpo preservado\r\n".b.freeze

  def initialize
    @consultas = []
  end

  def recebimento
    self
  end

  def baixar_original(id)
    @consultas << id
    raise falha if falha

    Mailcore::Resposta.new(dados: ORIGINAL, status: 200)
  end
end

class LeitorGigabytesVirtualMailcore
  attr_reader :leituras

  def initialize
    @leituras = []
  end

  def read(tamanho = nil)
    raise 'Leitura sem limite proibida no ensaio.' unless tamanho.is_a?(Integer) && tamanho.positive?

    leituras << tamanho
    'x' * [tamanho, 4 * 1024 * 1024 * 1024].min
  end
end

class TestesActionMailbox < ActionDispatch::IntegrationTest
  SEGREDO_BYTES = 'segredo-sintetico-local-com-32-bytes'.b.freeze
  CAMINHO = '/rails/action_mailbox/mailcore/inbound_emails'

  def setup
    ActionMailbox::InboundEmail.delete_all
    @cliente = ClienteOriginalSintetico.new
    ActionMailbox.ingress = :mailcore
    ActionMailbox::Ingresses::Mailcore::InboundEmailsController.cliente_mailcore = @cliente
    @segredo_anterior = Mailcore.configuracao.segredo_webhook
    Mailcore.configuracao.segredo_webhook = "whsec_#{Base64.strict_encode64(SEGREDO_BYTES)}"
  end

  def teardown
    Mailcore.configuracao.segredo_webhook = @segredo_anterior
    ActionMailbox::Ingresses::Mailcore::InboundEmailsController.cliente_mailcore = nil
  end

  def evento(tipo: 'email.received', destinatarios: ['oculto@example.test'])
    JSON.generate(type: tipo, created_at: '2026-11-14T12:00:00Z', data: { email_id: 'recebido-sintetico', to: destinatarios })
  end

  def entregar(corpo = evento, assinatura: true)
    instante = Time.now.to_i.to_s
    id = 'evento-sintetico'
    resumo = OpenSSL::HMAC.digest('SHA256', SEGREDO_BYTES, "#{id}.#{instante}.".b + corpo.b)
    cabecalhos = {
      'CONTENT_TYPE' => 'application/json', 'svix-id' => id, 'svix-timestamp' => instante,
      'svix-signature' => assinatura ? "v1,#{Base64.strict_encode64(resumo)}" : 'v1,aW52YWxpZGE='
    }
    post CAMINHO, params: corpo, headers: cabecalhos
  end

  def test_ingress_assinado_usa_original_autenticado_e_preserva_envelope
    entregar
    assert_response :no_content
    assert_equal ['recebido-sintetico'], @cliente.consultas
    registro = ActionMailbox::InboundEmail.last
    assert registro.source.b.end_with?(ClienteOriginalSintetico::ORIGINAL)
    assert_equal 'oculto@example.test', registro.mail['X-Original-To'].decoded
    assert_includes registro.mail.recipients, 'oculto@example.test'
  end

  def test_replay_nao_cria_nova_mensagem
    entregar
    assert_response :no_content
    entregar
    assert_response :no_content
    assert_equal 1, ActionMailbox::InboundEmail.count
  end

  def test_assinatura_invalida_nao_busca_conteudo
    entregar(evento, assinatura: false)
    assert_response :unauthorized
    assert_empty @cliente.consultas
    assert_equal 0, ActionMailbox::InboundEmail.count
  end

  def test_evento_irrelevante_e_ignorado_apos_assinatura
    entregar(evento(tipo: 'email.delivered'))
    assert_response :no_content
    assert_empty @cliente.consultas
  end

  def test_envelope_invalido_nao_injeta_cabecalhos
    entregar(evento(destinatarios: ["oculto@example.test\r\nX-Injetado: sim"]))
    assert_response :unprocessable_entity
    assert_empty @cliente.consultas
  end

  def test_falha_da_api_nao_confirma_recebimento
    @cliente.falha = Mailcore::Erro.new('Falha de teste sem detalhes privados.')
    entregar
    assert_response :service_unavailable
    assert_equal 0, ActionMailbox::InboundEmail.count
  end

  def test_ingress_desativado_e_segredo_ausente_fecham_acesso
    ActionMailbox.ingress = :relay
    entregar
    assert_response :not_found
    ActionMailbox.ingress = :mailcore
    Mailcore.configuracao.segredo_webhook = nil
    entregar
    assert_response :service_unavailable
    assert_empty @cliente.consultas
  end

  def test_corpo_grande_sem_content_length_e_recusado_antes_da_assinatura
    limite = ActionMailbox::Ingresses::Mailcore::InboundEmailsController::LIMITE_EVENTO_BYTES
    post CAMINHO, params: JSON.generate(preenchimento: 'x' * limite),
                  headers: { 'CONTENT_TYPE' => 'application/json' },
                  env: { 'CONTENT_LENGTH' => nil, 'HTTP_TRANSFER_ENCODING' => 'chunked' }

    assert_response :content_too_large
    assert_empty @cliente.consultas
    assert_equal 0, ActionMailbox::InboundEmail.count
  end

  def test_fluxo_virtual_de_gigabytes_e_lido_uma_vez_com_limite_antes_do_rails
    entrada = LeitorGigabytesVirtualMailcore.new
    ambiente = Rack::MockRequest.env_for(CAMINHO, method: 'POST', 'CONTENT_TYPE' => 'application/json')
    ambiente.delete('CONTENT_LENGTH')
    ambiente['HTTP_TRANSFER_ENCODING'] = 'chunked'
    ambiente['rack.input'] = entrada
    status, _cabecalhos, corpo = Rails.application.call(ambiente)

    assert_equal 413, status
    assert_equal [Mailcore::LimiteIngress::LIMITE_BYTES + 1], entrada.leituras
    assert_equal Mailcore::LimiteIngress, Rails.application.middleware.first.klass
    assert_empty @cliente.consultas
    assert_equal 0, ActionMailbox::InboundEmail.count
  ensure
    corpo.close if corpo.respond_to?(:close)
  end

  def test_middleware_reinjeta_bytes_exatos_e_preserva_filtros_da_aplicacao
    original = "{\n  \"exemplo\": \"bytes preservados\"\n}\r\n".b
    filtros = [:senha]
    restante = lambda do |ambiente|
      assert_equal original, ambiente['rack.input'].read
      assert_equal original, ambiente['RAW_POST_DATA']
      assert_equal original.bytesize.to_s, ambiente['CONTENT_LENGTH']
      refute ambiente.key?('HTTP_TRANSFER_ENCODING')
      assert_equal({}, ambiente['action_dispatch.request.request_parameters'])
      assert_includes ambiente['action_dispatch.parameter_filter'], :senha
      assert_includes ambiente['action_dispatch.parameter_filter'], :data
      [204, {}, []]
    end
    ambiente = { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => CAMINHO,
                 'rack.input' => StringIO.new(original), 'HTTP_TRANSFER_ENCODING' => 'chunked',
                 'action_dispatch.parameter_filter' => filtros }
    assert_equal 204, Mailcore::LimiteIngress.new(restante).call(ambiente).first
    assert_equal [:senha], filtros
  end

  def test_middleware_nao_le_ou_altera_requisicoes_fora_do_ingress
    [['POST', '/outra'], ['GET', CAMINHO]].each do |metodo, caminho|
      entrada = LeitorGigabytesVirtualMailcore.new
      filtros = [:senha]
      ambiente = { 'REQUEST_METHOD' => metodo, 'PATH_INFO' => caminho, 'rack.input' => entrada,
                   'action_dispatch.parameter_filter' => filtros }
      restante = lambda do |recebido|
        assert_same ambiente, recebido
        assert_same entrada, recebido['rack.input']
        assert_same filtros, recebido['action_dispatch.parameter_filter']
        [204, {}, []]
      end
      assert_equal 204, Mailcore::LimiteIngress.new(restante).call(ambiente).first
      assert_empty entrada.leituras
    end
  end

  def test_assinatura_do_corpo_com_espacos_e_quebras_e_preservada_sem_pii_nos_parametros
    corpo = "{\n  \"type\": \"email.received\",\n  \"created_at\": \"2026-11-14T12:00:00Z\",\n" \
            "  \"data\": {\"email_id\": \"recebido-sintetico\", \"to\": [\"oculto@example.test\"]}\n}\r\n"
    parametros = []
    inscricao = ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |*argumentos|
      parametros << argumentos.last[:params]
    end
    entregar(corpo)

    assert_response :no_content
    refute_empty parametros
    refute_includes parametros.inspect, 'oculto@example.test'
    refute_includes parametros.inspect, 'recebido-sintetico'
    assert_equal ['recebido-sintetico'], @cliente.consultas
  ensure
    ActiveSupport::Notifications.unsubscribe(inscricao) if inscricao
  end

  def test_middleware_nao_converte_falha_io_do_armazenamento_em_erro_do_cliente
    restante = ->(_ambiente) { raise IOError, 'Falha sintética posterior à leitura.' }
    ambiente = { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => CAMINHO, 'rack.input' => StringIO.new('{}') }
    assert_raises(IOError) { Mailcore::LimiteIngress.new(restante).call(ambiente) }
  end
end
