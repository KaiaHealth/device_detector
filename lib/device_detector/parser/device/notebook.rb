# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class Notebook
        include AbstractDeviceParser

        def parse
          return nil unless match_user_agent('FBMD/')

          super
        end

        protected

        def fixture_file
          'regexes/device/notebooks.yml'
        end

        def parser_name
          'notebook'
        end
      end
    end
  end
end
