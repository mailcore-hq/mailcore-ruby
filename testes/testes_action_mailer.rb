# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/mock'
require 'action_mailer'
require 'active_job'
require 'mailcore/action_mailer'

class ClienteEntregaSintetica
  attr_reader :pedidos, :tentativas
  attr_accessor :falha

  def initialize
    @pedidos = []
    @tentativas = 0
  end

  def emails
    self
  end

  def enviar(pedido, **opcoes)
    @tentativas += 1
    raise falha if falha

    pedidos << [pedido, opcoes]
    Mailcore::Resposta.new(dados: { id: 'email-sintetico', estado: 'aceita' }, status: 202)
  end
end

class CorreioActionMailerSintetico < ActionMailer::Base
  def aviso
    mail(from: 'Equipe <origem@example.test>', to: 'destino@example.test', subject: 'Olá') do |formato|
      formato.text { render plain: 'Bem-vindo' }
      formato.html { render html: '<p>Bem-vindo</p>'.html_safe }
    end
  end
end

class TestesActionMailer < Minitest::Test
  def setup
    @cliente = ClienteEntregaSintetica.new
    @entrega = Mailcore::EntregaActionMailer.new(cliente: @cliente)
  end

  def mensagem
    Mail.new do
      from 'Equipe <origem@example.test>'
      to ['destino@example.test']
      subject 'Olá, equipe'
      body 'Texto original'
    end
  end

  def test_entrega_real_action_mailer
    ActionMailer::Base.add_delivery_method :mailcore, Mailcore::EntregaActionMailer
    CorreioActionMailerSintetico.delivery_method = :mailcore
    CorreioActionMailerSintetico.mailcore_settings = { cliente: @cliente }
    resultado = CorreioActionMailerSintetico.aviso.deliver_now

    pedido = @cliente.pedidos.first.first
    assert_equal 'email-sintetico', resultado.message_id
    assert_equal 'Bem-vindo', pedido[:texto]
    assert_equal '<p>Bem-vindo</p>', pedido[:html]
  end

  def test_mapeia_envelope_cabecalhos_e_opcoes_sem_expor_metadados
    email = mensagem
    email.cc = ['copia@example.test']
    email.bcc = ['oculto@example.test']
    email.reply_to = ['resposta@example.test']
    email['X-Pedido'] = 'pedido-1'
    email['mailcore_opcoes'] = { chave_idempotencia: 'pedido-1', tags: { pedido: '1' }, agendada_em: '2026-12-01T12:00:00Z' }
    resposta = @entrega.deliver!(email)
    pedido, opcoes = @cliente.pedidos.first

    assert_equal 202, resposta.status
    assert_equal 'Equipe <origem@example.test>', pedido[:remetente]
    assert_equal ['copia@example.test'], pedido[:cc]
    assert_equal ['oculto@example.test'], pedido[:cco]
    assert_equal 'resposta@example.test', pedido[:responder_para]
    assert_equal({ 'X-Pedido' => 'pedido-1' }, pedido[:cabecalhos])
    assert_equal({ pedido: '1' }, pedido[:tags])
    assert_equal '2026-12-01T12:00:00Z', pedido[:agendada_em]
    assert_equal({ chave_idempotencia: 'pedido-1' }, opcoes)
  end

  def test_anexos_preservam_bytes_mime_e_cid
    email = mensagem
    email.html_part = Mail::Part.new(content_type: 'text/html; charset=UTF-8', body: '<img src="cid:imagem">')
    bytes = "\x00\xff\x80PNG".b
    email.attachments.inline['imagem.png'] = { mime_type: 'image/png', content: bytes }
    email.attachments['imagem.png'].content_id = '<imagem>'
    email.attachments['dados.bin'] = { mime_type: 'application/octet-stream', content: bytes }
    @entrega.deliver!(email)
    anexos = @cliente.pedidos.first.first[:anexos]

    assert_equal 2, anexos.length
    imagem = anexos.find { |item| item[:nome] == 'imagem.png' }
    assert_equal bytes, Base64.strict_decode64(imagem[:conteudo_base64])
    assert_equal 'image/png', imagem[:tipo_conteudo]
    assert_equal 'imagem', imagem[:id_conteudo]
    refute anexos.find { |item| item[:nome] == 'dados.bin' }.key?(:id_conteudo)
  end

  def test_nao_reutiliza_cabecalhos_entre_mensagens
    primeira = mensagem
    primeira['X-Primeira'] = 'privado'
    @entrega.deliver!(primeira)
    @entrega.deliver!(mensagem)

    refute @cliente.pedidos.last.first.key?(:cabecalhos)
    refute_includes @entrega.inspect, 'privado'
  end

  def test_converte_charset_do_corpo_para_json_utf8
    email = mensagem
    email.content_type = 'text/plain; charset=ISO-8859-1'
    email.body = "Ol\xe1, equipe".b
    @entrega.deliver!(email)
    texto = @cliente.pedidos.first.first[:texto]

    assert_equal 'Olá, equipe', texto
    assert_equal Encoding::UTF_8, texto.encoding
  end

  def test_falha_preserva_id_e_nao_repete
    email = mensagem
    email.message_id = 'original@example.test'
    @cliente.falha = Mailcore::ErroApi.new(codigo: 'indisponivel', mensagem: 'Falha sintética', status: 503)
    assert_raises(Mailcore::ErroApi) { @entrega.deliver!(email) }
    assert_equal 'original@example.test', email.message_id
    assert_empty @cliente.pedidos
    assert_equal 1, @cliente.tentativas
  end

  def test_opcoes_desconhecidas_e_reply_to_ambiguo_sao_recusados
    email = mensagem
    email['mailcore_opcoes'] = { inventada: true }
    assert_raises(ArgumentError) { @entrega.deliver!(email) }
    email = mensagem
    email.reply_to = ['um@example.test', 'dois@example.test']
    assert_raises(ArgumentError) { @entrega.deliver!(email) }
    assert_empty @cliente.pedidos
  end

  def test_deliver_later_usa_o_active_job_da_aplicacao
    anterior = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.add_delivery_method :mailcore, Mailcore::EntregaActionMailer
    CorreioActionMailerSintetico.delivery_method = :mailcore
    CorreioActionMailerSintetico.mailcore_settings = { cliente: @cliente }
    CorreioActionMailerSintetico.aviso.deliver_later

    fila = ActiveJob::Base.queue_adapter.enqueued_jobs
    assert_equal 1, fila.length
    assert_equal ActionMailer::MailDeliveryJob, fila.first[:job]
    assert_empty @cliente.pedidos
  ensure
    ActiveJob::Base.queue_adapter = anterior
  end

  def test_opcoes_da_entrega_preservam_a_configuracao_padrao
    anterior = Mailcore.configuracao.chave_api
    chave = -> { 'mc_chave_sintetica' }
    Mailcore.configuracao.chave_api = chave
    recebidas = nil
    construir = lambda do |**opcoes|
      recebidas = opcoes
      @cliente
    end
    Mailcore::Cliente.stub(:new, construir) do
      Mailcore::EntregaActionMailer.new(tempo_limite: 7).deliver!(mensagem)
    end

    assert_same chave, recebidas[:chave_api]
    assert_equal 7, recebidas[:tempo_limite]
  ensure
    Mailcore.configuracao.chave_api = anterior
  end
end
