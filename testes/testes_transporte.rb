# frozen_string_literal: true

require 'minitest/autorun'
require 'mailcore'
require 'bigdecimal'
require_relative 'servidor_https'

class TestesTransporte < Minitest::Test
  CHAVE = 'mc_sintetica_123'.freeze

  def com_servidor(atender = nil)
    servidor = ServidorHttpsSintetico.new(&atender)
    yield servidor
  ensure
    servidor&.encerrar
  end

  def transporte(servidor, **opcoes)
    Mailcore::Transporte.new(
      chave_api: CHAVE, url_base: servidor.url_base, certificado_ca: servidor.certificado_ca,
      tempo_limite: 3, tempo_conexao: 1, **opcoes,
    )
  end

  def test_https_real_envia_json_idempotencia_e_cabecalhos_sem_perder_null_ou_false
    com_servidor do |servidor|
      cliente = transporte(servidor)
      dados = {
        remetente: 'origem@example.test', destinatarios: ['destino@example.test'],
        assunto: 'Ação', texto: 'Olá', tags: { negocio: 'pedido-123' },
        responder_para: nil, rastrear: false,
      }
      copia = Marshal.load(Marshal.dump(dados))
      resposta = cliente.executar('POST', '/emails', corpo: dados, chave_idempotencia: 'pedido-123',
                                 cabecalhos: { 'X-Correlacao' => 'sintetica' })
      assert_equal({ id: 'email-sintetico', estado: 'aceita' }, resposta.dados)
      assert_equal 200, resposta.status
      registro = servidor.registros.fetch(0)
      assert_equal 'POST', registro[:metodo]
      assert_equal '/v1/emails', registro[:alvo]
      assert_equal "Bearer #{CHAVE}", registro[:cabecalhos]['authorization'].first
      assert_equal 'pedido-123', registro[:cabecalhos]['idempotency-key'].first
      assert_equal 'sintetica', registro[:cabecalhos]['x-correlacao'].first
      assert_equal 'application/json', registro[:cabecalhos]['content-type'].first
      assert_equal 'identity', registro[:cabecalhos]['accept-encoding'].first
      assert_match(/\Amailcore-ruby\//, registro[:cabecalhos]['user-agent'].first)
      assert_equal copia, JSON.parse(registro[:corpo], symbolize_names: true)
      assert_equal copia, dados
      refute registro[:cabecalhos].key?('cookie')
    end
  end

  def test_filtros_e_identificadores_usam_escaping_sem_mudar_a_origem_ou_criar_outro_caminho
    com_servidor do |servidor|
      emails = Mailcore::Recursos::Emails.new(transporte(servidor))
      emails.obter('parte/ação+?@example.test')
      transporte(servidor).executar('GET', '/receiving', consulta: {
        busca: 'ação+teste & assunto=?', ativo: false, limite: 2, omitido: nil,
      })
      assert_equal '/v1/emails/parte%2Fa%C3%A7%C3%A3o%2B%3F%40example.test', servidor.registros[0][:alvo]
      uri = URI(servidor.registros[1][:alvo])
      assert_equal '/v1/receiving', uri.path
      assert_equal({ 'busca' => 'ação+teste & assunto=?', 'ativo' => 'false', 'limite' => '2' },
                   URI.decode_www_form(uri.query).to_h)
    end
  end

  def test_proc_e_resolvida_por_requisicao_inclusive_em_threads_com_identidades_distintas
    com_servidor do |servidor|
      cliente = transporte(servidor, chave_api: -> { Thread.current[:chave_mailcore_teste] })
      threads = 8.times.map do |indice|
        Thread.new do
          ator = "ator-#{indice}"
          Thread.current[:chave_mailcore_teste] = "mc_#{ator}"
          2.times do
            cliente.executar('GET', '/domains', cabecalhos: { 'X-Ator' => ator })
          end
        ensure
          Thread.current[:chave_mailcore_teste] = nil
        end
      end
      threads.each(&:value)
      assert_equal 16, servidor.registros.length
      servidor.registros.each do |registro|
        ator = registro[:cabecalhos]['x-ator'].first
        assert_equal "Bearer mc_#{ator}", registro[:cabecalhos]['authorization'].first
      end
    end
  end

  def test_chave_estatica_e_copiada_e_nao_aparece_em_inspect_ou_erro_de_resolucao
    com_servidor do |servidor|
      chave = 'mc_original'.dup
      cliente = transporte(servidor, chave_api: chave)
      chave.replace('mc_alterada')
      cliente.executar('GET', '/domains')
      assert_equal 'Bearer mc_original', servidor.registros.first[:cabecalhos]['authorization'].first
      refute_includes cliente.inspect, 'mc_original'
      refute_includes cliente.inspect, 'mc_alterada'
      segredo = 'credencial-sintetica-na-excecao'
      invalido = transporte(servidor, chave_api: -> { raise segredo })
      erro = assert_raises(Mailcore::ErroConfiguracao) { invalido.executar('GET', '/domains') }
      refute_includes erro.message, segredo
      assert_nil erro.cause
      assert_equal 1, servidor.registros.length
    end
  end

  [301, 302, 307, 308].each do |codigo|
    define_method("test_redirecionamento_#{codigo}_e_recusado_sem_seguir_ou_vazar_credenciais") do
      destino = ServidorHttpsSintetico.new
      origem = ServidorHttpsSintetico.new do |_pedido, resposta|
        resposta.status = codigo
        resposta['Location'] = "#{destino.url_base}/capturar"
        resposta.body = 'redirecionado'
      end
      erro = assert_raises(Mailcore::ErroApi) do
        transporte(origem).executar('POST', '/emails', corpo: { texto: 'sintetico' })
      end
      assert_equal 'redirecionamento_recusado', erro.codigo
      assert_equal codigo, erro.status
      assert_equal 1, origem.registros.length
      assert_empty destino.registros
    ensure
      origem&.encerrar
      destino&.encerrar
    end
  end

  %w[GET POST].each do |metodo|
    define_method("test_queda_de_conexao_#{metodo.downcase}_nao_provoca_retry_automatico") do
      atender = lambda do |pedido, resposta|
        resposta.keep_alive = false
        pedido.instance_variable_get(:@socket).close
      end
      com_servidor(atender) do |servidor|
        erro = assert_raises(Mailcore::ErroTransporte) do
          transporte(servidor).executar(metodo, '/emails', corpo: metodo == 'POST' ? { texto: 'teste' } : nil)
        end
        assert_equal 'falha_de_rede', erro.codigo
        assert_equal 1, servidor.registros.length
      end
    end
  end

  def test_tls_exige_confianca_da_ca_e_nao_entrega_autorizacao_ao_servidor_na_falha
    com_servidor do |servidor|
      erro = assert_raises(Mailcore::ErroTransporte) do
        transporte(servidor, certificado_ca: nil).executar('GET', '/domains')
      end
      assert_equal 'falha_de_rede', erro.codigo
      assert_empty servidor.registros
      refute_includes erro.inspect, CHAVE
      assert_nil erro.cause
      assert_equal 200, transporte(servidor).executar('GET', '/domains').status
    end
  end

  def test_tls_ca_confiada_incorreta_tambem_recusa_a_conexao
    com_servidor do |servidor|
      _chave, outra_ca = ServidorHttpsSintetico.identidade
      arquivo = Tempfile.new(['mailcore-outra-ca-', '.pem'])
      arquivo.write(outra_ca.to_pem)
      arquivo.flush
      erro = assert_raises(Mailcore::ErroTransporte) do
        transporte(servidor, certificado_ca: arquivo.path).executar('GET', '/domains')
      end
      assert_equal 'falha_de_rede', erro.codigo
      assert_empty servidor.registros
    ensure
      arquivo&.close!
    end
  end

  def test_tls_verifica_hostname_mesmo_quando_o_certificado_e_confiavel
    com_servidor do |servidor|
      erro = assert_raises(Mailcore::ErroTransporte) do
        transporte(servidor, url_base: servidor.url_base(host: 'localhost')).executar('GET', '/domains')
      end
      assert_equal 'falha_de_rede', erro.codigo
      assert_empty servidor.registros
    end
  end

  def test_https_e_obrigatorio_e_url_nao_aceita_credenciais_query_ou_fragmento
    [
      'http://127.0.0.1:9999/v1', 'http://api.example.test/v1', 'ftp://example.test/v1',
      'https://usuario:senha@example.test/v1', 'https://example.test/v1?chave=valor',
      'https://example.test/v1#segredo',
    ].each do |url|
      assert_raises(Mailcore::ErroConfiguracao) { Mailcore::Transporte.new(chave_api: CHAVE, url_base: url) }
    end
    assert_raises(Mailcore::ErroConfiguracao) do
      Mailcore::Transporte.new(chave_api: CHAVE, url_base: 'http://api.example.test/v1', permitir_http_local: true)
    end
  end

  def test_proxies_de_ambiente_nao_recebem_a_credencial_da_api
    nomes = %w[http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY]
    antigos = nomes.to_h { |nome| [nome, ENV[nome]] }
    nomes.each { |nome| ENV[nome] = 'http://127.0.0.1:1' }
    com_servidor do |servidor|
      assert_equal 200, transporte(servidor).executar('GET', '/domains').status
      assert_equal 1, servidor.registros.length
    end
  ensure
    antigos&.each { |nome, valor| valor.nil? ? ENV.delete(nome) : ENV[nome] = valor }
  end

  def test_cabecalhos_reservados_ou_com_injecao_sao_recusados_antes_do_http
    com_servidor do |servidor|
      cliente = transporte(servidor)
      %w[Authorization Proxy-Authorization Host Cookie Content-Length Content-Type Idempotency-Key Accept Accept-Encoding User-Agent].each do |nome|
        assert_raises(Mailcore::ErroConfiguracao) do
          cliente.executar('GET', '/domains', cabecalhos: { nome => 'valor' })
        end
      end
      [ { 'X-Teste' => "valor\r\nAuthorization: teste" }, { "X\nTeste" => 'valor' } ].each do |cabecalhos|
        assert_raises(Mailcore::ErroConfiguracao) { cliente.executar('GET', '/domains', cabecalhos: cabecalhos) }
      end
      ['', 'com espaco', "quebra\nlinha", 'a' * 257].each do |chave|
        assert_raises(Mailcore::ErroConfiguracao) { cliente.executar('GET', '/domains', chave_idempotencia: chave) }
      end
      assert_empty servidor.registros
    end
  end

  [401, 403, 409, 422, 429, 500, 503].each do |codigo|
    define_method("test_erro_http_#{codigo}_preserva_codigo_status_e_cabecalhos_sem_retry") do
      atender = lambda do |_pedido, resposta|
        resposta.status = codigo
        resposta['Content-Type'] = 'application/json'
        resposta['Retry-After'] = '7'
        resposta['X-Request-Id'] = 'requisicao-sintetica'
        resposta['Set-Cookie'] = 'sessao=sintetica; HttpOnly'
        resposta.body = JSON.generate(erro: { codigo: 'recusada', mensagem: 'Pedido sintético recusado.' })
      end
      com_servidor(atender) do |servidor|
        erro = assert_raises(Mailcore::ErroApi) { transporte(servidor).executar('POST', '/emails', corpo: { texto: 'teste' }) }
        assert_equal codigo, erro.status
        assert_equal 'recusada', erro.codigo
        assert_equal 'Pedido sintético recusado.', erro.message
        assert_equal '7', erro.cabecalhos['retry-after']
        assert_equal 'requisicao-sintetica', erro.cabecalhos['x-request-id']
        refute erro.cabecalhos.key?('set-cookie')
        assert erro.cabecalhos.frozen?
        assert_equal 1, servidor.registros.length
      end
    end
  end

  def test_erro_html_ou_envelope_invalido_nao_reflete_o_corpo_na_excecao
    ['<html>detalhe-privado-sintetico</html>', '[]', '{"erro": "detalhe-privado-sintetico"}'].each do |corpo|
      atender = lambda do |_pedido, resposta|
        resposta.status = 502
        resposta.body = corpo
      end
      com_servidor(atender) do |servidor|
        erro = assert_raises(Mailcore::ErroApi) { transporte(servidor).executar('GET', '/domains') }
        assert_equal 'erro_http', erro.codigo
        assert_equal 502, erro.status
        refute_includes erro.message, 'detalhe-privado-sintetico'
        assert_equal 1, servidor.registros.length
      end
    end
  end

  def test_json_malformado_na_resposta_de_sucesso_e_um_erro_de_protocolo
    atender = lambda do |_pedido, resposta|
      resposta['Content-Type'] = 'application/json'
      resposta.body = '{"id":'
    end
    com_servidor(atender) do |servidor|
      erro = assert_raises(Mailcore::ErroResposta) { transporte(servidor).executar('GET', '/emails') }
      assert_equal 'resposta_invalida', erro.codigo
      assert_equal 200, erro.status
      assert_nil erro.cause
    end
  end

  def test_resposta_204_e_200_vazia_tem_semanticas_distintas
    atender = lambda do |pedido, resposta|
      resposta.status = pedido.path.end_with?('/sem-conteudo') ? 204 : 200
      resposta.body = ''
    end
    com_servidor(atender) do |servidor|
      cliente = transporte(servidor)
      resposta = cliente.executar('DELETE', '/sem-conteudo')
      assert_equal 204, resposta.status
      assert_nil resposta.dados
      assert_raises(Mailcore::ErroResposta) { cliente.executar('GET', '/vazio') }
      resposta_vazia = cliente.executar('POST', '/vazio', aceitar_vazio: true)
      assert_nil resposta_vazia.dados
      assert_equal 200, resposta_vazia.status
      contato = Mailcore::Recursos::Contatos.new(cliente)
      assert_nil contato.segmentos.adicionar('contato', 'segmento').dados
    end
  end

  def test_bytes_preservam_conteudo_binario_e_metadados_de_download
    dados = "\x00\xff\xfe\n\r".b
    atender = lambda do |_pedido, resposta|
      resposta['Content-Type'] = 'application/octet-stream'
      resposta['Content-Disposition'] = 'attachment; filename="teste.bin"'
      resposta.body = dados
    end
    com_servidor(atender) do |servidor|
      resposta = Mailcore::Recursos::Recebimento.new(transporte(servidor)).baixar_original('email')
      assert_equal dados, resposta.dados
      assert_equal Encoding::BINARY, resposta.dados.encoding
      assert_equal 'application/octet-stream', resposta.cabecalhos['content-type']
      assert_equal 'attachment; filename="teste.bin"', resposta.cabecalhos['content-disposition']
    end
  end

  def test_texto_html_preserva_utf8_sem_tentar_interpretar_json
    atender = lambda do |_pedido, resposta|
      resposta['Content-Type'] = 'text/html; charset=utf-8'
      resposta.body = '<p>Ação e revisão</p>'
    end
    com_servidor(atender) do |servidor|
      resposta = Mailcore::Recursos::Modelos.new(transporte(servidor)).obter_previa('organizacao', 'previa')
      assert_equal '<p>Ação e revisão</p>', resposta.dados
      assert_equal Encoding::UTF_8, resposta.dados.encoding
    end
  end

  def test_prazo_total_interrompe_resposta_lenta_ainda_que_cada_parte_chegue_antes_do_timeout
    atender = lambda do |_pedido, resposta|
      resposta.chunked = true
      resposta['Content-Type'] = 'application/octet-stream'
      resposta.body = proc do |saida|
        20.times do
          saida.write('parte')
          sleep 0.025
        end
      end
    end
    com_servidor(atender) do |servidor|
      inicio = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      erro = assert_raises(Mailcore::ErroTransporte) do
        transporte(servidor).executar('GET', '/lento', formato: :bytes, tempo_limite: 0.15)
      end
      decorrido = Process.clock_gettime(Process::CLOCK_MONOTONIC) - inicio
      assert_equal 'prazo_excedido', erro.codigo
      assert_operator decorrido, :>=, 0.10
      assert_operator decorrido, :<, 0.8
      assert_equal 1, servidor.registros.length
    end
  end

  def test_content_length_maior_que_limite_e_recusado_antes_de_entregar_bytes_ao_consumidor
    atender = lambda do |_pedido, resposta|
      resposta.body = 'a' * 128
    end
    com_servidor(atender) do |servidor|
      partes = []
      erro = assert_raises(Mailcore::ErroResposta) do
        transporte(servidor).executar('GET', '/grande', formato: :fluxo, limite_resposta_bytes: 16) { |parte| partes << parte }
      end
      assert_equal 'resposta_excedida', erro.codigo
      assert_empty partes
    end
  end

  def test_fluxo_respeita_limite_real_mesmo_sem_content_length
    atender = lambda do |_pedido, resposta|
      resposta.chunked = true
      resposta.body = proc do |saida|
        3.times { saida.write('12345') }
      end
    end
    com_servidor(atender) do |servidor|
      partes = []
      erro = assert_raises(Mailcore::ErroResposta) do
        transporte(servidor).executar('GET', '/fluxo', formato: :fluxo, limite_resposta_bytes: 10) { |parte| partes << parte }
      end
      assert_equal 'resposta_excedida', erro.codigo
      assert_operator partes.join.bytesize, :<=, 10
      assert partes.all? { |parte| parte.encoding == Encoding::BINARY }
    end
  end

  def test_fluxo_entrega_partes_sem_acumular_e_devolve_contagem_total
    atender = lambda do |_pedido, resposta|
      resposta.chunked = true
      resposta.body = proc do |saida|
        3.times do |indice|
          saida.write("parte-#{indice}\n")
          sleep 0.01
        end
      end
    end
    com_servidor(atender) do |servidor|
      partes = []
      resposta = Mailcore::Recursos::ExportacoesContatos.new(transporte(servidor)).baixar_fluxo('exportacao') do |parte|
        partes << parte
      end
      assert_equal "parte-0\nparte-1\nparte-2\n", partes.join
      assert_equal partes.join.bytesize, resposta.dados
      assert_operator partes.length, :>=, 2
    end
  end

  def test_excecao_do_consumidor_cancela_leitura_sem_mascarar_a_excecao_original
    atender = lambda do |_pedido, resposta|
      resposta.chunked = true
      resposta.body = proc do |saida|
        20.times do
          saida.write('parte')
          sleep 0.005
        end
      end
    end
    com_servidor(atender) do |servidor|
      cancelamento = Class.new(StandardError).new('cancelamento do consumidor')
      lidas = 0
      erro = assert_raises(cancelamento.class) do
        transporte(servidor).executar('GET', '/fluxo', formato: :fluxo) do |_parte|
          lidas += 1
          raise cancelamento
        end
      end
      assert_same cancelamento, erro
      assert_equal 1, lidas
      assert_equal 1, servidor.registros.length
    end
  end

  def test_fluxo_entrega_a_primeira_parte_antes_de_o_servidor_concluir_a_resposta
    liberar = Queue.new
    atender = lambda do |_pedido, resposta|
      resposta.chunked = true
      resposta.body = proc do |saida|
        saida.write('primeira')
        Timeout.timeout(1) { liberar.pop }
        saida.write('segunda')
      end
    end
    com_servidor(atender) do |servidor|
      partes = []
      resposta = transporte(servidor).executar('GET', '/fluxo', formato: :fluxo) do |parte|
        partes << parte
        liberar << true if partes.length == 1
      end
      assert_equal 'primeirasegunda', partes.join
      assert_equal partes.join.bytesize, resposta.dados
      assert_equal 2, partes.length
    end
  end

  %i[json bytes fluxo].each do |formato|
    define_method("test_resposta_truncada_#{formato}_nao_e_anunciada_como_completa") do
      atender = lambda do |_pedido, resposta|
        resposta.keep_alive = false
        resposta['Content-Length'] = '500'
        resposta['Content-Type'] = formato == :json ? 'application/json' : 'application/octet-stream'
        resposta.body = proc { |saida| saida.write('{"id":"parcial"}') }
      end
      com_servidor(atender) do |servidor|
        erro = assert_raises(Mailcore::ErroTransporte) do
          transporte(servidor).executar('GET', '/truncada', formato: formato) { |_parte| nil }
        end
        assert_includes %w[resposta_incompleta falha_de_rede], erro.codigo
        assert_equal 1, servidor.registros.length
      end
    end
  end

  def test_importacao_com_json_escapado_maior_que_o_csv_nao_esbarra_em_teto_de_8_mib
    atender = lambda do |_pedido, resposta|
      resposta.status = 202
      resposta['Content-Type'] = 'application/json'
      resposta.body = JSON.generate(id: 'importacao-sintetica', estado: 'pendente')
    end
    com_servidor(atender) do |servidor|
      # O CSV permanece abaixo de 8 MiB; aspas no campo aumentam seu JSON serializado.
      conteudo = "email,primeiro_nome\nusuario@example.test,\"" + ('""' * (2 * 1024 * 1024 + 64)) + "\"\n"
      assert_operator conteudo.bytesize, :<, 8 * 1024 * 1024
      importacoes = Mailcore::Recursos::ImportacoesContatos.new(transporte(servidor, tempo_limite: 10))
      resposta = importacoes.criar({ arquivo_nome: 'contatos.csv', conteudo: conteudo, mapeamento: { '0' => 'email', '1' => 'primeiro_nome' } })
      assert_equal 202, resposta.status
      registro = servidor.registros.fetch(0)
      assert_operator registro[:corpo].bytesize, :>, 8 * 1024 * 1024
      assert_equal conteudo, JSON.parse(registro[:corpo]).fetch('conteudo')
      assert_equal 'importacao-sintetica', resposta[:id]
    end
  end

  def test_json_recusa_valores_que_mudariam_de_tipo_ou_seriam_invalidos
    com_servidor do |servidor|
      cliente = transporte(servidor)
      [Float::NAN, Float::INFINITY, Complex(1, 2), Rational(1, 2), BigDecimal('1.5'), Object.new].each do |valor|
        assert_raises(Mailcore::ErroConfiguracao) { cliente.executar('POST', '/events/send', corpo: { valor: valor }) }
      end
      assert_raises(Mailcore::ErroConfiguracao) do
        cliente.executar('POST', '/events/send', corpo: { 'chave' => 1, chave: 2 })
      end
      assert_empty servidor.registros
    end
  end

  def test_string_json_invalida_e_recusada_com_erro_sanitizado
    com_servidor do |servidor|
      cliente = transporte(servidor)
      ["\xff".b.force_encoding(Encoding::UTF_8), "\xff".b].each do |valor|
        erro = assert_raises(Mailcore::ErroConfiguracao) do
          cliente.executar('POST', '/events/send', corpo: { texto: valor })
        end
        assert_nil erro.cause
      end
      assert_empty servidor.registros
    end
  end

  def test_chave_json_com_encoding_invalido_e_recusada_sem_expor_bytes
    com_servidor do |servidor|
      cliente = transporte(servidor)
      ["\xff".b.force_encoding(Encoding::UTF_8), "\xff".b].each do |chave|
        erro = assert_raises(Mailcore::ErroConfiguracao) do
          cliente.executar('POST', '/events/send', corpo: { chave => 'valor' })
        end
        assert_equal 'Texto JSON deve usar UTF-8 válido.', erro.message
        assert_nil erro.cause
      end
      assert_empty servidor.registros
    end
  end

  def test_chaves_que_seriam_duplicadas_apos_transcodificacao_sao_recusadas
    com_servidor do |servidor|
      dados = { 'ação' => 1, 'ação'.encode(Encoding::ISO_8859_1) => 2 }
      assert_raises(Mailcore::ErroConfiguracao) do
        transporte(servidor).executar('POST', '/events/send', corpo: dados)
      end
      assert_empty servidor.registros
    end
  end
end
