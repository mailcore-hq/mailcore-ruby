# frozen_string_literal: true

require 'minitest/autorun'
require 'mailcore'

class TestesCore < Minitest::Test
  # Vetor fixo produzido independentemente com node:crypto; inclui UTF-8 no corpo.
  SEGREDO = 'whsec_Y2hhdmUtc2ludGV0aWNhLTMyLWJ5dGVzLXRlc3RlLTEyMw=='
  CORPO = '{"type":"email.received","created_at":"2026-11-14T12:00:00Z","data":{"email_id":"sintetico","texto":"Olá"}}'
  CABECALHOS = { 'svix-id' => 'evento-sintetico', 'svix-timestamp' => '1794657600',
                 'svix-signature' => 'v1,m9hOSHQVO80Rb70GMzUg63QIVu/RqjtC5MC5rCjISXM=' }.freeze

  def verificar(corpo = CORPO, cabecalhos = CABECALHOS, segredo = SEGREDO, agora = Time.at(1_794_657_600))
    Mailcore.verificar_assinatura(corpo_bruto: corpo, cabecalhos: cabecalhos,
                                 segredo: segredo, agora: agora)
  end

  def test_vetor_interoperavel_e_rotacao
    assert_equal 'sintetico', verificar[:data][:email_id]
    assert_equal 'Olá', verificar[:data][:texto]
    novos = CABECALHOS.merge('svix-signature' => "v1,AAAA v0,ignorada #{CABECALHOS['svix-signature']}")
    assert_equal 'email.received', verificar(CORPO, novos)[:type]
    rack = CABECALHOS.transform_keys { |nome| 'HTTP_' + nome.upcase.tr('-', '_') }
    assert_equal verificar, verificar(CORPO, rack)
    assert_equal verificar, verificar(CORPO.b)
  end

  def test_corpo_e_envelope_nao_podem_ser_alterados
    [CORPO + ' ', CORPO.sub('sintetico', 'outro'), CORPO.sub('Olá', 'Ola')].each do |corpo|
      assert_raises(Mailcore::ErroAssinatura) { verificar(corpo) }
    end
    assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, {}, SEGREDO) }
    assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, CABECALHOS, 'whsec_invalido') }
    duplicados = CABECALHOS.merge('Svix-Id' => CABECALHOS['svix-id'])
    assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, duplicados) }
    assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, CABECALHOS.merge('svix-id' => "id\r\n")) }
  end

  def test_janela_temporal_limites_inclusivos_e_timestamps_malformados
    [-300, 300].each { |desvio| assert_equal 'email.received', verificar(CORPO, CABECALHOS, SEGREDO, Time.at(1_794_657_600 + desvio))[:type] }
    [-301, 301].each { |desvio| assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, CABECALHOS, SEGREDO, Time.at(1_794_657_600 + desvio)) } }
    ['1794657600x', '0', '-1794657600', '1794657600.0', ' 1794657600'].each do |valor|
      assert_raises(Mailcore::ErroAssinatura) { verificar(CORPO, CABECALHOS.merge('svix-timestamp' => valor)) }
    end
  end

  def test_inspecao_e_falha_nao_revelam_credenciais
    chave = 'mc_segredo_sintetico'
    cliente = Mailcore::Cliente.new(chave_api: chave)
    refute_includes cliente.inspect, chave
    refute_includes cliente.emails.inspect, chave
    configuracao = Mailcore::Configuracao.new
    configuracao.chave_api = chave
    refute_includes configuracao.inspect, chave
    resposta = Mailcore::Resposta.new(dados: { email: chave }, status: 200)
    refute_includes resposta.inspect, chave
    erro = assert_raises(Mailcore::ErroAssinatura) { verificar('invalido', {}, chave) }
    refute_includes erro.message, chave
    assert_nil erro.cause
  end

  def test_configuracao_isolada_e_todos_recursos
    cliente_a = Mailcore::Cliente.new(chave_api: 'mc_a')
    cliente_b = Mailcore::Cliente.new(chave_api: 'mc_b')
    Mailcore::Cliente::RECURSOS.each_key do |nome|
      refute_same cliente_a.public_send(nome), cliente_b.public_send(nome)
      assert_instance_of Mailcore::Cliente::RECURSOS[nome], cliente_a.public_send(nome)
    end
    assert_equal 'sintetico', Mailcore::Resposta.new(dados: { id: 'sintetico' }, status: 202)[:id]
  end
end
