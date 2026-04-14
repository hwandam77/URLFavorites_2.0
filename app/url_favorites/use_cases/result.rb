# frozen_string_literal: true

module UrlFavorites
  module UseCases
    Result = Struct.new(:ok?, :value, :error, keyword_init: true)
  end
end

