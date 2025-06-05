# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Client
      class MobileApp
        include AbstractClientParser

        def parse
          # TODO: https://github.com/matomo-org/device-detector/blob/master/Parser/Client/MobileApp.php#L104
          super
        end

        protected

        def fixture_file
          'regexes/client/mobile_apps.yml'
        end

        def parser_name
          'mobile app'
        end
      end
    end
  end
end
