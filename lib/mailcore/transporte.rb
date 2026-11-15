# frozen_string_literal: true

require 'net/http'
require 'json'
require 'openssl'
require 'timeout'
require 'uri'

module Mailcore
  # Sessão por operação: seguro entre threads e após fork, sem estado de requisição global.
  class Transporte
    RESERVADOS = %w[authorization proxy-authorization cookie host content-length content-type
                    accept connection transfer-encoding idempotency-key user-agent accept-encoding].freeze
    OMITIDOS = %w[set-cookie authorization proxy-authorization].freeze
    METODOS = { 'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'PUT' => Net::HTTP::Put,
                'PATCH' => Net::HTTP::Patch, 'DELETE' => Net::HTTP::Delete }.freeze
    class PrazoInterno < Timeout::Error; end
    class FalhaConsumidor < StandardError
      attr_reader :original

      def initialize(original)
        @original = original
      end
    end

    def initialize(chave_api:, url_base: 'https://mailcore.com.br/v1', tempo_limite: 30,
                   tempo_conexao: 10, limite_resposta_bytes: 16 * 1024 * 1024,
                   certificado_ca: nil, permitir_http_local: false)
      validar_chave(chave_api) unless chave_api.respond_to?(:call)
      @chave_api = chave_api.is_a?(String) ? chave_api.dup.freeze : chave_api
      @base = validar_base(url_base, permitir_http_local)
      @tempo_limite = validar_tempo(tempo_limite)
      @tempo_conexao = validar_tempo(tempo_conexao)
      @limite_resposta_bytes = validar_limite(limite_resposta_bytes)
      unless certificado_ca.nil? || (certificado_ca.is_a?(String) && File.file?(certificado_ca))
        raise ErroConfiguracao, 'O certificado da autoridade deve apontar para um arquivo acessível.'
      end
      @certificado_ca = certificado_ca&.dup&.freeze
    end

    def inspect
      '#<Mailcore::Transporte credenciais=protegidas>'
    end

    def executar(metodo, caminho, corpo: nil, consulta: nil, formato: :json, aceitar_vazio: false,
                 chave_idempotencia: nil, tempo_limite: @tempo_limite,
                 limite_resposta_bytes: @limite_resposta_bytes, cabecalhos: {}, &bloco)
      tempo = validar_tempo(tempo_limite)
      limite = validar_limite(limite_resposta_bytes)
      raise ErroConfiguracao, 'Formato de resposta inválido.' unless %i[json texto bytes fluxo].include?(formato)
      raise ErroConfiguracao, 'Forneça um bloco para consumir o fluxo.' if formato == :fluxo && !bloco
      classe = METODOS[metodo]
      raise ErroConfiguracao, 'Método HTTP não permitido.' unless classe
      url = criar_url(caminho, consulta)
      pedido = classe.new(url.request_uri)
      pedido['Accept'] = %i[bytes fluxo].include?(formato) ? 'application/octet-stream' : (formato == :texto ? 'text/html' : 'application/json')
      pedido['Accept-Encoding'] = 'identity'
      pedido['User-Agent'] = "mailcore-ruby/#{VERSAO}"
      preparar_cabecalhos(pedido, cabecalhos, chave_idempotencia)
      unless corpo.nil?
        validar_json(corpo)
        pedido.body = JSON.generate(corpo)
        # Importações CSV usam o limite JSON maior do servidor; cada rota valida seu próprio DTO.
        raise ErroConfiguracao, 'O corpo JSON ultrapassa 50 MiB.' if pedido.body.bytesize > 50 * 1024 * 1024
        pedido['Content-Type'] = 'application/json'
      end
      chave = resolver_chave
      pedido['Authorization'] = "Bearer #{chave}"
      recebidos = {}
      status = nil
      # Além dos prazos de socket, cobre o total da operação, inclusive respostas lentas em partes.
      Timeout.timeout(tempo, PrazoInterno) do
        limite_instante = Process.clock_gettime(Process::CLOCK_MONOTONIC) + tempo
        http = criar_http(url, tempo)
        http.start do
          http.request(pedido) do |resposta|
            status = resposta.code.to_i
            recebidos = resposta.each_header.reject { |nome, _| OMITIDOS.include?(nome) }.to_h.freeze
            if status.between?(300, 399)
              raise ErroApi.new(codigo: 'redirecionamento_recusado', mensagem: 'A API respondeu com um redirecionamento recusado.', status: status, cabecalhos: recebidos)
            end
            tamanho = resposta['content-length']
            excedida(status, recebidos) if tamanho && tamanho.to_i > limite
            bytes = String.new(encoding: Encoding::BINARY)
            total = 0
            resposta.read_body do |parte|
              restante = limite_instante - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              raise PrazoInterno if restante <= 0
              http.read_timeout = restante
              total += parte.bytesize
              excedida(status, recebidos) if total > limite
              if formato == :fluxo && status.between?(200, 299)
                begin
                  bloco.call(parte.b) unless parte.empty?
                rescue PrazoInterno
                  raise
                rescue StandardError => erro
                  raise FalhaConsumidor.new(erro)
                end
              else
                bytes << parte.b
              end
            end
            if tamanho && tamanho.match?(/\A[0-9]+\z/) && total != tamanho.to_i
              raise ErroTransporte.new('A resposta terminou antes do tamanho anunciado.', codigo: 'resposta_incompleta', status: status, cabecalhos: recebidos)
            end
            unless status.between?(200, 299)
              falha_http(bytes, status, recebidos)
            end
            dados = case formato
                    when :fluxo then total
                    when :bytes then bytes
                    when :texto then bytes.force_encoding(Encoding::UTF_8)
                    else
                      if bytes.empty? && (status == 204 || aceitar_vazio)
                        nil
                      else
                        begin
                          JSON.parse(bytes, symbolize_names: true)
                        rescue JSON::ParserError, EncodingError
                          raise ErroResposta.new('A API retornou JSON inválido.', codigo: 'resposta_invalida', status: status, cabecalhos: recebidos), cause: nil
                        end
                      end
                    end
            return Resposta.new(dados: dados, status: status, cabecalhos: recebidos)
          end
        end
      end
    rescue FalhaConsumidor => erro
      raise erro.original
    rescue PrazoInterno, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
      raise ErroTransporte.new('A operação excedeu o prazo configurado.', codigo: 'prazo_excedido', cabecalhos: recebidos || {}), cause: nil
    rescue SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
      raise ErroTransporte.new('Não foi possível concluir a comunicação com a API.', codigo: 'falha_de_rede', cabecalhos: recebidos || {}), cause: nil
    end

    private

    def validar_tempo(valor)
      unless valor.is_a?(Numeric) && valor.finite? && valor.positive? && valor <= 86_400
        raise ErroConfiguracao, 'O prazo deve ser positivo, em segundos, até 86400.'
      end
      valor
    end

    def validar_limite(valor)
      raise ErroConfiguracao, 'O limite deve ser um inteiro positivo em bytes.' unless valor.is_a?(Integer) && valor.positive?
      valor
    end

    def validar_chave(valor)
      unless valor.is_a?(String) && valor.match?(/\A[\x21-\x7e]+\z/)
        raise ErroConfiguracao, 'Informe a chave de API Mailcore ou configure MAILCORE_API_KEY.'
      end
      valor
    end

    def resolver_chave
      valor = @chave_api.respond_to?(:call) ? @chave_api.call : @chave_api
      validar_chave(valor)
    rescue StandardError
      raise ErroConfiguracao, 'Não foi possível obter uma chave de API válida.', cause: nil
    end

    def validar_base(valor, permitir_http_local)
      base = URI.parse(valor)
      local = %w[localhost 127.0.0.1 ::1].include?(base.hostname)
      unless base.is_a?(URI::HTTP) && base.host && !base.userinfo && !base.query && !base.fragment &&
             (base.scheme == 'https' || (base.scheme == 'http' && local && permitir_http_local == true))
        raise ErroConfiguracao, 'Use URL base HTTPS sem credenciais, parâmetros ou fragmentos.'
      end
      base.path = base.path.sub(%r{/+\z}, '')
      base.freeze
    rescue URI::InvalidURIError, TypeError, NoMethodError
      raise ErroConfiguracao, 'Use URL base HTTPS válida.', cause: nil
    end

    def criar_url(caminho, consulta)
      unless caminho.is_a?(String) && caminho.start_with?('/') && !caminho.start_with?('//') &&
             !caminho.match?(/[?#\\\x00-\x20]/) && !caminho.split('/').any? { |parte| ['.', '..'].include?(parte) }
        raise ErroConfiguracao, 'Caminho de recurso inválido.'
      end
      url = @base.dup
      url.path = @base.path + caminho
      unless consulta.nil? || consulta.is_a?(Hash)
        raise ErroConfiguracao, 'A consulta deve ser um Hash de valores simples.'
      end
      pares = (consulta || {}).filter_map do |nome, valor|
        next if valor.nil?
        unless [String, Symbol, Numeric, TrueClass, FalseClass].any? { |tipo| valor.is_a?(tipo) }
          raise ErroConfiguracao, 'A consulta deve conter apenas valores simples.'
        end
        [nome.to_s, valor.to_s]
      end
      url.query = URI.encode_www_form(pares) unless pares.empty?
      url
    end

    def preparar_cabecalhos(pedido, cabecalhos, chave_idempotencia)
      raise ErroConfiguracao, 'Cabeçalhos devem ser um Hash.' unless cabecalhos.is_a?(Hash)
      cabecalhos.each do |nome, valor|
        nome = nome.to_s
        unless nome.match?(/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/) && !RESERVADOS.include?(nome.downcase) &&
               valor.is_a?(String) && !valor.match?(/[\x00-\x1f\x7f]/)
          raise ErroConfiguracao, 'Cabeçalho inválido ou reservado pelo SDK.'
        end
        pedido[nome] = valor
      end
      return if chave_idempotencia.nil?
      unless chave_idempotencia.is_a?(String) && chave_idempotencia.match?(/\A[\x21-\x7e]{1,256}\z/)
        raise ErroConfiguracao, 'A chave de idempotência deve ter de 1 a 256 caracteres ASCII visíveis.'
      end
      pedido['Idempotency-Key'] = chave_idempotencia
    end

    def validar_json(valor, profundidade = 0)
      raise ErroConfiguracao, 'Corpo JSON profundo demais.' if profundidade > 100
      case valor
      when Hash
        nomes = {}
        valor.each do |nome, item|
          unless nome.is_a?(String) || nome.is_a?(Symbol)
            raise ErroConfiguracao, 'As chaves do JSON devem ser strings ou símbolos únicos.'
          end
          normalizado = validar_texto(nome.to_s)
          raise ErroConfiguracao, 'As chaves do JSON devem ser únicas em UTF-8.' if nomes.key?(normalizado)
          nomes[normalizado] = true
          validar_json(item, profundidade + 1)
        end
      when Array then valor.each { |item| validar_json(item, profundidade + 1) }
      when String
        validar_texto(valor)
      when Integer, Float
        raise ErroConfiguracao, 'Número JSON deve ser finito.' unless valor.finite?
      when TrueClass, FalseClass, NilClass then nil
      else raise ErroConfiguracao, 'O corpo deve conter somente valores JSON.'
      end
    end

    def validar_texto(valor)
      texto = valor.encode(Encoding::UTF_8)
      unless valor.valid_encoding? && texto.valid_encoding?
        raise ErroConfiguracao, 'Texto JSON deve usar UTF-8 válido.'
      end
      texto
    rescue EncodingError
      raise ErroConfiguracao, 'Texto JSON deve usar UTF-8 válido.', cause: nil
    end

    def criar_http(url, tempo)
      # Não herda proxies do ambiente nem repete GET automaticamente após desconexão.
      http = Net::HTTP.new(url.hostname, url.port, nil)
      http.max_retries = 0
      http.ignore_eof = false if http.respond_to?(:ignore_eof=)
      http.open_timeout = [@tempo_conexao, tempo].min
      http.read_timeout = tempo
      http.write_timeout = tempo
      http.use_ssl = url.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_hostname = true
        http.min_version = OpenSSL::SSL::TLS1_2_VERSION
        http.ca_file = @certificado_ca if @certificado_ca
      end
      http
    end

    def excedida(status, recebidos)
      raise ErroResposta.new('A resposta excedeu o limite de bytes configurado.', codigo: 'resposta_excedida', status: status, cabecalhos: recebidos)
    end

    def falha_http(bytes, status, recebidos)
      begin
        erro = JSON.parse(bytes, symbolize_names: true)[:erro]
        if erro.is_a?(Hash) && erro[:codigo].is_a?(String) && erro[:mensagem].is_a?(String)
          raise ErroApi.new(codigo: erro[:codigo], mensagem: erro[:mensagem], status: status, cabecalhos: recebidos)
        end
      rescue JSON::ParserError, TypeError, NoMethodError
        # Proxies podem responder texto/HTML; não reproduzir esse corpo na exceção.
      end
      raise ErroApi.new(codigo: 'erro_http', mensagem: 'A API retornou erro HTTP sem detalhes JSON válidos.', status: status, cabecalhos: recebidos)
    end
  end
end
