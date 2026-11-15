# frozen_string_literal: true

module Mailcore
  module Recursos
    class Base
      def initialize(transporte)
        @transporte = transporte
      end

      private

      def executar(metodo, caminho, **opcoes, &bloco)
        @transporte.executar(metodo, caminho, **opcoes, &bloco)
      end

      # Percent-encoding por byte evita transformar identificadores em caminhos.
      def segmento(valor)
        unless valor.is_a?(String) && !valor.empty? && !['.', '..'].include?(valor) &&
               valor.valid_encoding? && !valor.match?(/[\x00-\x1f\x7f]/)
          raise ErroConfiguracao, 'Informe um identificador não vazio e sem controles.'
        end
        valor.encode(Encoding::UTF_8).bytes.map do |byte|
          caractere = byte.chr
          caractere.match?(/[A-Za-z0-9_.~!-]/) ? caractere : format('%%%02X', byte)
        end.join
      end
    end
  end
end
