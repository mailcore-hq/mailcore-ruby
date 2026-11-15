# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require 'time'

relatorio = {
  data_utc: Time.now.utc.iso8601, ruby: RUBY_VERSION, plataforma: RUBY_PLATFORM,
  imagem: ENV.fetch('MAILCORE_IMAGEM_TESTE'), resultado: 'aprovado', suites: []
}
http_padrao = ARGV.delete('--http-padrao')
abort 'Opção de verificação desconhecida.' unless ARGV.empty?
relatorio[:perfil] = http_padrao ? 'net_http_padrao_do_ruby' : 'dependencias_lockfile'
arquivos = http_padrao ? ['testes/testes_transporte.rb'] : Dir['testes/testes_*.rb'].sort
arquivos.each do |arquivo|
  comando = [RbConfig.ruby, '-Ilib']
  if http_padrao
    codigo = 'spec=Gem::Specification.find_all_by_name("net-http").find(&:default_gem?);' \
             'gem "net-http",spec.version.to_s;gem "json","<3";require "net/http";' \
             'puts "net_http="+Net::HTTP::VERSION;load ARGV.shift'
    comando += ['-e', codigo, arquivo]
  else
    comando << arquivo
  end
  saida, erros, estado = Open3.capture3(*comando)
  relatorio[:net_http] = saida[/^net_http=(.+)$/, 1] if http_padrao
  resumo = saida.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/)
  dados = { arquivo: arquivo, aprovado: estado.success? && !resumo.nil? }
  if resumo
    %i[testes assercoes falhas erros ignorados].zip(resumo.captures.map(&:to_i)).each { |nome, valor| dados[nome] = valor }
    dados[:aprovado] &&= dados[:falhas].zero? && dados[:erros].zero? && dados[:ignorados].zero?
  end
  relatorio[:suites] << dados
  relatorio[:resultado] = 'falhou' unless dados[:aprovado]
  puts JSON.generate(dados)
  warn(saida + erros) unless dados[:aprovado]
end
relatorio[:total_testes] = relatorio[:suites].sum { |suite| suite.fetch(:testes, 0) }
relatorio[:total_assercoes] = relatorio[:suites].sum { |suite| suite.fetch(:assercoes, 0) }
sufixo = http_padrao ? '-http-padrao' : ''
destino = File.join(ENV.fetch('MAILCORE_RELATORIOS', '/relatorios'), "ruby-#{RUBY_VERSION}#{sufixo}.json")
temporario = "#{destino}.#{Process.pid}.tmp"
File.write(temporario, JSON.pretty_generate(relatorio) + "\n")
File.rename(temporario, destino)
abort 'A verificação falhou; consulte o relatório sanitizado.' unless relatorio[:resultado] == 'aprovado'
