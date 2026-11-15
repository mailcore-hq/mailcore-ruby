# frozen_string_literal: true

# Cliente do ensaio Docker: nenhuma credencial ou mensagem entra no relatório.
require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'tempfile'
require 'time'
require_relative '../lib/mailcore'

class FalhaIntegracao < StandardError; end

class IntegracaoApi
  def initialize(fixture, certificado)
    @fixture = fixture
    @certificado = certificado
    @cenarios = []
    @etapa = 'prontidao'
  end

  def exigir(condicao)
    raise FalhaIntegracao unless condicao
  end

  def etapa(nome)
    @etapa = nome
    yield
    @cenarios << nome
  end

  def esperar_erro(status)
    begin
      yield
    rescue Mailcore::ErroApi => erro
      exigir(erro.status == status)
      return erro
    end
    raise FalhaIntegracao
  end

  def cliente(chave)
    Mailcore::Cliente.new(chave_api: chave, url_base: 'https://mailcore-api:3443/v1',
                         certificado_ca: @certificado, tempo_limite: 10)
  end

  # Sessão e callback existem somente para preparar esta fixture sintética.
  # Todas as operações da biblioteca usam Bearer pelo transporte real da gem.
  def http(caminho, metodo: 'GET', cabecalhos: {}, corpo: nil)
    conexao = Net::HTTP.new('mailcore-api', 3443, nil)
    conexao.use_ssl = true
    conexao.verify_mode = OpenSSL::SSL::VERIFY_PEER
    conexao.verify_hostname = true
    conexao.ca_file = @certificado
    conexao.max_retries = 0
    conexao.ignore_eof = false if conexao.respond_to?(:ignore_eof=)
    conexao.open_timeout = 2
    conexao.read_timeout = 3
    conexao.write_timeout = 3
    pedido = (metodo == 'POST' ? Net::HTTP::Post : Net::HTTP::Get).new(caminho, cabecalhos)
    pedido.body = corpo unless corpo.nil?
    conexao.start { conexao.request(pedido) }
  end

  def executar
    fim = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    pronta = false
    until pronta || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= fim
      begin
        pronta = http('/health/ready').code == '200'
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError, Timeout::Error
        # A sonda de prontidão não aceita mensagens.
      end
      sleep 0.2 unless pronta
    end
    exigir(pronta)

    @etapa = 'criar_full_sessao_sintetica'
    criacao = http('/v1/api-keys', metodo: 'POST', cabecalhos: {
                    'Content-Type' => 'application/json', 'Origin' => 'https://localhost:17443',
                    'Cookie' => "__Host-mailcore=#{@fixture.delete(:token)}",
                    'X-CSRF-Token' => @fixture.delete(:csrf)
                  }, corpo: JSON.generate(nome: 'Fixture Ruby Full', permissao: 'full_access'))
    exigir(criacao.code == '201')
    full = JSON.parse(criacao.body, symbolize_names: true)
    @sdk = cliente(full.fetch(:chave))
    remetente = "avisos@#{@fixture.fetch(:nome_dominio)}"
    envio = nil
    chave_envio = nil

    etapa('chaves_full_sending_escopo_inspect') do
      chave_envio = @sdk.chaves_api.criar({ nome: 'Fixture Ruby Sending', permissao: 'sending_access',
                                          dominio_id: @fixture.fetch(:dominio) }).dados
      envio = cliente(chave_envio.fetch(:chave))
      esperar_erro(403) { envio.dominios.listar }
      exigir(!@sdk.inspect.include?(full.fetch(:chave)))
      exigir(@sdk.chaves_api.listar.dados.fetch(:dados).any? { |chave| chave[:id] == chave_envio[:id] })
    end

    pedido = { remetente: "Equipe Ruby <#{remetente}>", destinatarios: ['principal@example.test'],
               cc: ['copia@example.test'], cco: ['oculto@example.test'], assunto: 'Validação Ruby',
               texto: 'Dados sintéticos', html: '<p>Dados sintéticos<img src="cid:marca@example.test"></p>',
               cabecalhos: { 'X-Teste-SDK' => 'sintetico' }, agendada_em: (Time.now.utc + 3600).iso8601,
               anexos: [{ nome: 'marca.png', tipo_conteudo: 'image/png',
                          conteudo_base64: Base64.strict_encode64([137, 80, 78, 71].pack('C*')),
                          id_conteudo: 'marca@example.test' }] }
    etapa('envio_composto_idempotencia_409_download_cancelamento') do
      aceita = envio.emails.enviar(pedido, chave_idempotencia: 'ruby-composto').dados
      exigir(aceita[:estado] == 'agendada')
      exigir(envio.emails.enviar(pedido, chave_idempotencia: 'ruby-composto').dados == aceita)
      esperar_erro(409) do
        envio.emails.enviar(pedido.merge(assunto: 'Outra intenção'), chave_idempotencia: 'ruby-composto')
      end
      exigir(@sdk.emails.obter_por_idempotencia('ruby-composto').dados[:id] == aceita[:id])
      exigir(@sdk.emails.obter(aceita[:id]).dados.fetch(:destinatarios).length == 3)
      anexo = @sdk.emails.baixar_anexo(aceita[:id], 0).dados
      exigir(anexo.encoding == Encoding::BINARY && anexo.bytes == [137, 80, 78, 71])
      exigir(@sdk.emails.cancelar(aceita[:id]).dados[:estado] == 'cancelada')
    end

    etapa('lote_atomico_repeticao_conflito') do
      item = { remetente: remetente, destinatarios: ['lote@example.test'], assunto: 'Lote Ruby',
               texto: 'Dados sintéticos', agendada_em: (Time.now.utc + 3600).iso8601 }
      antes = @sdk.emails.listar({ limite: 100 }).dados.fetch(:dados).map { |email| email[:id] }.sort
      esperar_erro(422) do
        envio.lotes.enviar([item, item.merge(destinatarios: ['endereco-invalido'])], chave_idempotencia: 'ruby-lote-invalido')
      end
      depois = @sdk.emails.listar({ limite: 100 }).dados.fetch(:dados).map { |email| email[:id] }.sort
      exigir(antes == depois)
      lote = [item, item.merge(assunto: 'Segundo item Ruby')]
      aceita = envio.lotes.enviar(lote, chave_idempotencia: 'ruby-lote').dados
      exigir(aceita.fetch(:dados).length == 2)
      exigir(envio.lotes.enviar(lote, chave_idempotencia: 'ruby-lote').dados == aceita)
      exigir(@sdk.lotes.obter_por_idempotencia('ruby-lote').dados == aceita)
      esperar_erro(409) do
        envio.lotes.enviar([item.merge(assunto: 'Divergente'), lote.last], chave_idempotencia: 'ruby-lote')
      end
      exigir(@sdk.emails.listar({ limite: 100 }).dados.fetch(:dados).length == antes.length + 2)
      aceita.fetch(:dados).each { |email| @sdk.emails.cancelar(email.fetch(:id)) }
    end

    etapa('dominios_capacidades_tracking_crud') do
      dominio = @sdk.dominios.atualizar(@fixture.fetch(:dominio), {
                                         capacidades: { envio: 'enabled', recebimento: 'enabled' },
                                         rastreamento_aberturas: true, rastreamento_cliques: true
                                       }).dados
      exigir(dominio[:capacidades][:recebimento] == 'enabled' && dominio[:rastreamento_aberturas] == true)
      novo = @sdk.dominios.criar({ nome: "ruby-#{@fixture.fetch(:organizacao).delete('-')}.example.com",
                                  capacidades: { envio: 'enabled', recebimento: 'disabled' } }).dados
      exigir(@sdk.dominios.remover(novo.fetch(:id)).dados[:estado] == 'suspenso')
    end

    segmento = nil
    topico = nil
    contato = nil
    etapa('contatos_nulos_catalogos_exportacao_csv_fluxo') do
      segmento = @sdk.segmentos.criar({ nome: 'Segmento Ruby' }).dados
      topico = @sdk.topicos.criar({ nome: 'Tópico Ruby', visibilidade: 'publico', assinatura_padrao: 'opt_in' }).dados
      contato = @sdk.contatos.criar({ email: 'contato@example.test', primeiro_nome: 'Sintético',
                                     segmentos: [segmento.fetch(:id)],
                                     topicos: [{ id: topico.fetch(:id), assinatura: 'opt_in' }] }).dados
      exigir(@sdk.contatos.obter(contato.fetch(:id)).dados[:id] == contato[:id])
      exigir(@sdk.contatos.atualizar(contato.fetch(:id), { primeiro_nome: nil }).dados[:primeiro_nome].nil?)
      exportacao = @sdk.contatos.exportacoes.criar({}, chave_idempotencia: 'ruby-exportacao').dados
      exigir(exportacao[:estado] == 'concluida' && exportacao[:total] == 1)
      csv = String.new(encoding: Encoding::BINARY)
      resposta = @sdk.contatos.exportacoes.baixar_fluxo(exportacao.fetch(:id)) { |parte| csv << parte }
      exigir(csv.include?('contato@example.test') && resposta.dados == csv.bytesize)
      exigir(@sdk.contatos.exportacoes.listar.dados.fetch(:dados).any? { |item| item[:id] == exportacao[:id] })
    end

    modelo = nil
    pasta = nil
    etapa('modelos_pastas_versoes_previa_publicacao_cas') do
      pasta = @sdk.modelos.pastas.criar({ nome: 'Pasta Ruby' }).dados
      modelo = @sdk.modelos.criar({ nome: 'Modelo Ruby', html: '<p>Olá, {{{NOME}}}.</p>',
                                    pasta_id: pasta.fetch(:id), remetente: remetente, assunto: 'Modelo sintético',
                                    variaveis: [{ chave: 'NOME', tipo: 'string' }] }).dados
      versao = @sdk.modelos.versoes.listar(modelo.fetch(:id)).dados.fetch(:dados).first
      exigir(versao.is_a?(Hash))
      versao_obtida = @sdk.modelos.versoes.obter(modelo[:id], versao[:id]).dados
      exigir(versao_obtida[:versao_id] == versao[:id] && versao_obtida[:id] == modelo[:id])
      previa = @sdk.modelos.prever(modelo[:id], { revisao: modelo[:revisao], variaveis: { NOME: 'Ruby' } }).dados
      exigir(previa.fetch(:html).include?('Ruby'))
      previa_id = URI.parse(previa.fetch(:url)).path.split('/').last
      exigir(@sdk.modelos.obter_previa(@fixture.fetch(:organizacao), previa_id).dados.include?('Ruby'))
      antiga = modelo.fetch(:revisao)
      modelo = @sdk.modelos.atualizar(modelo[:id], { revisao: antiga, nome: 'Modelo editado' }).dados
      esperar_erro(409) { @sdk.modelos.atualizar(modelo[:id], { revisao: antiga, nome: 'Conflito' }) }
      modelo = @sdk.modelos.publicar(modelo[:id], { revisao: modelo[:revisao] }).dados
      exigir(modelo[:status] == 'published')
      modelo = @sdk.modelos.versoes.restaurar(modelo[:id], versao[:id], { revisao: modelo[:revisao] }).dados
    end

    etapa('marketing_crud_sem_disparo') do
      campanha = @sdk.campanhas.criar({ nome: 'Campanha Ruby' }).dados
      campanha = @sdk.campanhas.atualizar(campanha[:id], { revisao: campanha[:revisao], nome: 'Campanha editada' }).dados
      exigir(@sdk.campanhas.obter(campanha[:id]).dados[:id] == campanha[:id])
      @sdk.campanhas.remover(campanha[:id])
      evento = @sdk.eventos.criar({ nome: 'ruby.qa', esquema: { pontos: 'number', ativo: 'boolean' } }).dados
      exigir(@sdk.eventos.atualizar(evento[:id], { esquema: nil }).dados[:esquema].nil?)
      automacao = @sdk.automacoes.criar({ nome: 'Automação Ruby', estado: 'inativa' }).dados
      automacao = @sdk.automacoes.atualizar(automacao[:id], { revisao: automacao[:revisao], nome: 'Automação editada' }).dados
      exigir(@sdk.automacoes.obter(automacao[:id]).dados[:id] == automacao[:id])
      @sdk.automacoes.remover(automacao[:id])
      @sdk.eventos.remover(evento[:id])
    end

    etapa('caixas_etiquetas_rascunhos_cas_sem_envio') do
      caixa = @sdk.caixas.criar({ endereco: "suporte@#{@fixture.fetch(:nome_dominio)}", nome: 'Suporte Ruby' }).dados
      exigir(@sdk.caixas.obter(caixa[:id]).dados[:id] == caixa[:id])
      etiqueta = @sdk.caixas.etiquetas.criar(caixa[:id], { nome: 'Pedidos', cor: '#224466' }).dados
      rascunho = @sdk.caixas.rascunhos.criar(caixa[:id], { para: ['cliente@example.test'], assunto: 'Pedido',
                                                        texto: 'Olá' }).dados
      antiga = rascunho.fetch(:revisao)
      rascunho = @sdk.caixas.rascunhos.atualizar(caixa[:id], rascunho[:id], { revisao: antiga, texto: 'Atualizado' }).dados
      esperar_erro(409) do
        @sdk.caixas.rascunhos.atualizar(caixa[:id], rascunho[:id], { revisao: antiga, texto: 'Conflito' })
      end
      exigir(@sdk.caixas.rascunhos.obter(caixa[:id], rascunho[:id]).dados[:html].nil?)
      @sdk.caixas.rascunhos.remover(caixa[:id], rascunho[:id])
      @sdk.caixas.etiquetas.remover(caixa[:id], etiqueta[:id])
      @sdk.caixas.remover(caixa[:id])
    end

    etapa('recebimento_mime_real_pendente_bytes_fluxo') do
      exigir(@sdk.recebimento.listar.dados.fetch(:dados).empty?)
      mime = "From: origem@example.test\r\nTo: aparente@example.test\r\nMessage-ID: <ruby-fixture@example.test>\r\n" \
             "Subject: Fixture Ruby\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=iso-8859-1\r\n" \
             "Content-Transfer-Encoding: 8bit\r\n\r\nOl\xE1, dados sint\xE9ticos.\r\n".b
      callback = JSON.generate(id: 1, rcpt_to: "real@#{@fixture.fetch(:nome_dominio)}", mail_from: 'origem@example.test',
                               message: Base64.strict_encode64(mime), base64: true, size: mime.bytesize)
      chave = OpenSSL::PKey::RSA.new(@fixture.delete(:chave_postal))
      assinatura = Base64.strict_encode64(chave.sign(OpenSSL::Digest::SHA256.new, callback))
      caminho = "/interno/postal/recebidos/#{@fixture.fetch(:rota)}"
      cabecalhos = { 'Content-Type' => 'application/json', 'X-Postal-Signature-256' => assinatura }
      resposta = http(caminho, metodo: 'POST', cabecalhos: cabecalhos, corpo: callback)
      exigir(resposta.code == '200')
      recebido = JSON.parse(resposta.body, symbolize_names: true).fetch(:id)
      repetida = http(caminho, metodo: 'POST', cabecalhos: cabecalhos, corpo: callback)
      exigir(JSON.parse(repetida.body, symbolize_names: true)[:id] == recebido)
      detalhe = @sdk.recebimento.obter(recebido, { formato_html: 'cid' }).dados
      exigir(detalhe[:estado_processamento] == 'pendente' && detalhe[:para] == ["real@#{@fixture.fetch(:nome_dominio)}"])
      original = @sdk.recebimento.baixar_original(recebido)
      exigir(original.status == 200 && original.cabecalhos.fetch('content-type') == 'message/rfc822')
      exigir(original.dados.encoding == Encoding::BINARY && original.dados == mime)
      fluxo = String.new(encoding: Encoding::BINARY)
      resultado = @sdk.recebimento.baixar_original_fluxo(recebido) { |parte| fluxo << parte }
      exigir(fluxo == mime && resultado.dados == mime.bytesize)
      exigir(@sdk.recebimento.listar.dados.fetch(:dados).length == 1)
      esperar_erro(403) { envio.recebimento.listar }
    end

    etapa('cli_revogacao_e_limpeza_crud') do
      exigir(@sdk.cli.concessoes.listar({ limite: 1 }).dados.fetch(:dados).empty?)
      esperar_erro(403) { envio.cli.concessoes.listar }
      [@sdk.contatos.remover(contato[:id]), @sdk.segmentos.remover(segmento[:id]),
       @sdk.topicos.remover(topico[:id]), @sdk.modelos.remover(modelo[:id]),
       @sdk.modelos.pastas.remover(pasta[:id]), @sdk.chaves_api.revogar(chave_envio[:id])].each do |resposta|
        exigir(resposta.status.between?(200, 299))
      end
      esperar_erro(401) { envio.emails.enviar(pedido, chave_idempotencia: 'ruby-revogada') }
    end
    { resultado: 'aprovado', ruby: RUBY_VERSION, cenarios: @cenarios,
      recebimento_processado_por_worker: false, rails_real_exercitado: false }
  rescue StandardError => erro
    { resultado: 'falhou', ruby: RUBY_VERSION, etapa: @etapa, cenarios: @cenarios,
      erro_http: erro.is_a?(Mailcore::Erro) ? { codigo: erro.codigo, status: erro.status } : nil,
      falha: 'Contrato de integração não satisfeito; detalhes privados omitidos.' }
  end
end

begin
  dados = JSON.parse(STDIN.read, symbolize_names: true)
  Tempfile.create(['mailcore-ruby-ca-', '.crt']) do |arquivo|
    arquivo.write(dados.delete(:certificado_ca))
    arquivo.flush
    resultado = IntegracaoApi.new(dados, arquivo.path).executar
    STDOUT.write(JSON.generate(resultado) + "\n")
    exit(resultado[:resultado] == 'aprovado' ? 0 : 1)
  end
rescue StandardError
  STDOUT.write(JSON.generate(resultado: 'falhou', etapa: 'configuracao',
                             falha: 'Não foi possível iniciar o cliente sintético.') + "\n")
  exit 1
end
