# frozen_string_literal: true

module Seguros
  module Providers
    class Base
      class Unavailable < StandardError; end

      def quote(_payload, timeout: 8)
        raise NotImplementedError, "O provider deve implementar #quote"
      end
    end
  end
end
