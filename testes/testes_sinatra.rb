# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/mock'
require_relative '../exemplos/sinatra'

class ClienteSinatraSintetico
  attr_reader :pedidos, :tentativas
  attr_accessor :falha, :dados

  def initialize
    @pedidos = []
    @tentativas = 0
    @dados = { id: 'email-sinatra-sintetico', estado: 'aceita', privado: 'nao-publicar' }
  end

  def emails
    self
  end

  def enviar(pedido, **opcoes)
    @tentativas += 1
    raise falha if falha

    @pedidos << [pedido, opcoes]
    Mailcore::Resposta.new(dados: dados, status: 202, cabecalhos: { 'x-privado' => 'nao-publicar' })
  end
end

class TestesSinatra < Minitest::Test
  TOKEN = 'token_aplicacao_sintetico_1234567890_abc'
  CHAVE = 'mc_chave_api_sintetica_1234567890_abc'
  URL = 'https://aplicacao.example.test/enviar'

  def setup
    @ambiente = {
      'TOKEN_APLICACAO' => TOKEN, 'MAILCORE_API_KEY' => CHAVE,
      'MAILCORE_REMETENTE' => 'Equipe <origem@example.test>',
      'MAILCORE_DESTINATARIO' => 'destino@example.test'
    }
    @cliente = ClienteSinatraSintetico.new
    @aplicacao = ExemploMailcoreSinatra.construir(ambiente: @ambiente, cliente: @cliente)
    @http = Rack::MockRequest.new(@aplicacao)
    @erros = StringIO.new
  end

  def chamar(**opcoes)
    @http.post(URL, {
      'HTTP_AUTHORIZATION' => "Bearer #{TOKEN}", 'HTTP_IDEMPOTENCY_KEY' => 'pedido-sintetico-1',
      'CONTENT_TYPE' => 'application/json', 'rack.errors' => @erros, input: '{}'
    }.merge(opcoes))
  end

  def assert_sem_segredos(resposta)
    [TOKEN, CHAVE, 'nao-publicar'].each do |segredo|
      refute_includes resposta.body, segredo
      refute_includes resposta.headers.inspect, segredo
      refute_includes @erros.string, segredo
    end
  end

  def test_roteamento_sinatra_real_e_aceitacao_sanitizada
    resposta = chamar
    assert_equal 202, resposta.status
    assert_equal({ 'id' => 'email-sinatra-sintetico', 'estado' => 'aceita' }, JSON.parse(resposta.body))
    assert_match 'application/json', resposta.content_type
    assert_equal 'no-store', resposta['cache-control']
    assert_sem_segredos resposta
  end

  def test_corpo_e_query_nao_mudam_destino_conteudo_ou_cliente
    corpo = JSON.generate(remetente: 'invasor@example.test', destinatarios: ['terceiro@example.test'],
                          texto: 'Não usar', cliente: {}, chave_api: 'outra-chave', url_base: 'https://example.invalid')
    resposta = chamar(input: corpo, 'QUERY_STRING' => 'destinatario=terceiro%40example.test')
    assert_equal 202, resposta.status
    pedido, opcoes = @cliente.pedidos.first
    assert_equal 'Equipe <origem@example.test>', pedido[:remetente]
    assert_equal ['destino@example.test'], pedido[:destinatarios]
    assert_equal 'Integração Mailcore com Sinatra.', pedido[:texto]
    assert_equal({ chave_idempotencia: 'pedido-sintetico-1' }, opcoes)
  end

  def test_repeticao_explicita_preserva_a_chave_fornecida
    2.times { assert_equal 202, chamar.status }
    assert_equal 2, @cliente.tentativas
    assert_equal ['pedido-sintetico-1', 'pedido-sintetico-1'],
                 @cliente.pedidos.map { |_pedido, opcoes| opcoes[:chave_idempotencia] }
  end

  def test_auth_invalida_nunca_chama_o_sdk
    [nil, '', 'Bearer curta', "Bearer #{CHAVE}", "Bearer #{TOKEN},Bearer #{TOKEN}", "Bearer #{TOKEN}\r\nX-Teste: sim"].each do |valor|
      resposta = chamar('HTTP_AUTHORIZATION' => valor)
      assert_equal 401, resposta.status
      assert_sem_segredos resposta
    end
    assert_equal 0, @cliente.tentativas
  end

  def test_chaves_idempotentes_invalidas_sao_recusadas
    [nil, '', 'com espaco', 'a,b', "injetar\r\nX-Outro: sim", 'a' * 257].each do |valor|
      assert_equal 400, chamar('HTTP_IDEMPOTENCY_KEY' => valor).status
    end
    assert_equal 0, @cliente.tentativas
  end

  def test_json_e_tipo_de_conteudo_sao_validados_antes_do_envio
    ['', '{', '[]', 'true', "{\"texto\":\"\xff\"}".b].each do |corpo|
      assert_equal 400, chamar(input: corpo).status
    end
    assert_equal 413, chamar(input: 'x' * 4097).status
    assert_equal 415, chamar('CONTENT_TYPE' => 'application/x-www-form-urlencoded').status
    assert_equal 0, @cliente.tentativas
  end

  def test_erros_api_preservam_status_sem_mensagem_privada_ou_repeticao
    @cliente.falha = Mailcore::ErroApi.new(codigo: 'validacao', mensagem: "Falha #{CHAVE}", status: 422,
                                         cabecalhos: { 'authorization' => "Bearer #{CHAVE}" })
    resposta = chamar
    assert_equal 422, resposta.status
    assert_equal 1, @cliente.tentativas
    assert_sem_segredos resposta
  end

  def test_falha_de_transporte_e_redirecionamento_nao_confirmam_aceitacao
    @cliente.falha = Mailcore::ErroTransporte.new("Falha #{TOKEN}")
    resposta = chamar
    assert_equal 502, resposta.status
    assert_sem_segredos resposta
    @cliente.falha = Mailcore::ErroApi.new(codigo: 'redirecionamento_recusado', mensagem: CHAVE, status: 302)
    resposta = chamar
    assert_equal 502, resposta.status
    assert_sem_segredos resposta
    assert_equal 2, @cliente.tentativas
  end

  def test_resposta_incompleta_nao_produz_sucesso
    @cliente.dados = { id: nil, estado: 'aceita' }
    resposta = chamar
    assert_equal 502, resposta.status
    assert_sem_segredos resposta
  end

  def test_rotas_e_metodos_nao_previstos_nao_enviam
    assert_equal 404, @http.get(URL).status
    assert_equal 404, @http.post('https://aplicacao.example.test/outra').status
    assert_equal 0, @cliente.tentativas
  end

  def test_configuracao_incompleta_ou_credenciais_iguais_falham_no_boot
    [nil, 'curto', 123, TOKEN + ',duplicado', CHAVE].each do |valor|
      assert_raises(ArgumentError) do
        ExemploMailcoreSinatra.construir(ambiente: @ambiente.merge('TOKEN_APLICACAO' => valor), cliente: @cliente)
      end
    end
    assert_raises(ArgumentError) do
      ExemploMailcoreSinatra.construir(ambiente: @ambiente.merge('MAILCORE_REMETENTE' => "origem\r\nX-Injetado: sim"), cliente: @cliente)
    end
    assert_equal 0, @cliente.tentativas
  end
end
