# frozen_string_literal: true

module Seguros
  module Providers
    class Disabled < Base
      def quote(_payload, timeout: 8)
        { status: "aguardando_cotacao", external: false, timeout: }
      end
    end
  end
end
