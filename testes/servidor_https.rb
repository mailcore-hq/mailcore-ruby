# frozen_string_literal: true

require 'webrick'
require 'webrick/https'
require 'openssl'
require 'tempfile'
require 'json'

# API HTTPS sintética confinada ao loopback do container de testes.
class ServidorHttpsSintetico
  attr_reader :porta, :certificado_ca

  class Atendimento < WEBrick::HTTPServlet::AbstractServlet
    def initialize(servidor, atender)
      super(servidor)
      @atender = atender
    end

    def service(pedido, resposta)
      @atender.call(pedido, resposta)
    end
  end

  def self.identidade
    chave = OpenSSL::PKey::RSA.new(2048)
    certificado = OpenSSL::X509::Certificate.new
    certificado.version = 2
    certificado.serial = Random.rand(1..2**63)
    certificado.subject = OpenSSL::X509::Name.parse('/CN=API sintetica Mailcore')
    certificado.issuer = certificado.subject
    certificado.public_key = chave.public_key
    certificado.not_before = Time.now - 60
    certificado.not_after = Time.now + 3600
    extensoes = OpenSSL::X509::ExtensionFactory.new
    extensoes.subject_certificate = certificado
    extensoes.issuer_certificate = certificado
    certificado.add_extension(extensoes.create_extension('basicConstraints', 'CA:TRUE', true))
    certificado.add_extension(extensoes.create_extension('keyUsage', 'digitalSignature,keyEncipherment,keyCertSign', true))
    certificado.add_extension(extensoes.create_extension('extendedKeyUsage', 'serverAuth'))
    certificado.add_extension(extensoes.create_extension('subjectAltName', 'IP:127.0.0.1'))
    certificado.sign(chave, OpenSSL::Digest::SHA256.new)
    [chave, certificado]
  end

  IDENTIDADE = identidade.freeze

  def initialize(&atender)
    @registros = []
    @mutex = Mutex.new
    chave, certificado = IDENTIDADE
    @arquivo_ca = Tempfile.new(['mailcore-ca-', '.pem'])
    @arquivo_ca.write(certificado.to_pem)
    @arquivo_ca.flush
    @certificado_ca = @arquivo_ca.path
    @servidor = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1', Port: 0, MaxClients: 32,
      SSLEnable: true, SSLCertificate: certificado, SSLPrivateKey: chave,
      SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
      Logger: WEBrick::Log.new(File::NULL, WEBrick::Log::FATAL), AccessLog: [],
    )
    atendimento = proc do |pedido, resposta|
      registro = {
        metodo: pedido.request_method, alvo: pedido.unparsed_uri,
        cabecalhos: pedido.header.transform_values(&:dup), corpo: pedido.body,
      }
      @mutex.synchronize { @registros << registro }
      if atender
        atender.call(pedido, resposta)
      else
        resposta['Content-Type'] = 'application/json'
        resposta.body = JSON.generate(id: 'email-sintetico', estado: 'aceita')
      end
    end
    @servidor.mount('/', Atendimento, atendimento)
    @porta = @servidor.listeners.first.addr[1]
    @thread = Thread.new { @servidor.start }
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 3
    until @servidor.status == :Running
      raise 'O servidor HTTPS sintético não iniciou.' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= limite
      sleep 0.001
    end
  end

  def url_base(host: '127.0.0.1')
    "https://#{host}:#{porta}/v1"
  end

  def registros
    @mutex.synchronize { @registros.dup }
  end

  def encerrar
    @servidor.shutdown
    @thread.join(3)
    @arquivo_ca.close!
    raise 'O servidor HTTPS sintético não encerrou.' if @thread.alive?
  end
end
