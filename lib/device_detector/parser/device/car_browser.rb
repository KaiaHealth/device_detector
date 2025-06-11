# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class CarBrowser
        include AbstractDeviceParser

        def parse
          return nil unless pre_match_overall?

          super
        end

        protected

        def fixture_file
          'regexes/device/car_browsers.yml'
        end

        def parser_name
          'car browser'
        end
      end
    end
  end
end
