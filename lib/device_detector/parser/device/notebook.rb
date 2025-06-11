# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class Notebook
        include AbstractDeviceParser

        def parse
          unless match_user_agent('FBMD/')
            return nil
          end

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
