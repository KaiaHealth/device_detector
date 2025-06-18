# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Client
      class Library < AbstractClientParser
        protected

        def fixture_file
          'regexes/client/libraries.yml'
        end

        def parser_name
          'library'
        end
      end
    end
  end
end
