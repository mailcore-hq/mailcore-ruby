# frozen_string_literal: true

require 'rake'

desc 'Executa cada suíte em um processo para isolar o boot da aplicação Rails.'
task :testes do
  Dir['testes/testes_*.rb'].sort.each do |arquivo|
    ruby '-Ilib', arquivo
  end
end
task default: :testes
