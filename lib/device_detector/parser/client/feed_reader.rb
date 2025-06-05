# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Client
      class FeedReader
        include AbstractClientParser

        protected

        def fixture_file
          'regexes/client/feed_readers.yml'
        end

        def parser_name
          'feed reader'
        end
      end
    end
  end
end
