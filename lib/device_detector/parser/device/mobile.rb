# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class Mobile
        include AbstractDeviceParser

        protected

        def fixture_file
          'regexes/device/mobiles.yml'
        end

        def parser_name
          'mobile'
        end
      end
    end
  end
end
