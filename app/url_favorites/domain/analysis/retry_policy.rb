module UrlFavorites
  module Domain
    module Analysis
      class RetryPolicy
        MAX_RETRIES = 3
        BACKOFF_SECONDS = [ 30, 60, 120 ].freeze

        def self.next_wait_seconds(execution_index)
          BACKOFF_SECONDS.fetch(execution_index, BACKOFF_SECONDS.last)
        end
      end
    end
  end
end
