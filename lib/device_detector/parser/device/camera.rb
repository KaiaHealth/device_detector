# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class Camera
        include AbstractDeviceParser

        def parse
          return nil unless pre_match_overall?

          super
        end

        protected

        def fixture_file
          'regexes/device/cameras.yml'
        end

        def parser_name
          'camera'
        end
      end
    end
  end
end
