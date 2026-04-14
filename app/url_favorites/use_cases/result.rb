# frozen_string_literal: true

module UrlFavorites
  module UseCases
    Result = Struct.new(:ok, :value, :error, keyword_init: true) do
      def ok? = ok

      def self.ok(value:)
        new(ok: true, value: value, error: nil)
      end

      def self.fail(error:)
        new(ok: false, value: nil, error: error)
      end
    end
  end
end
