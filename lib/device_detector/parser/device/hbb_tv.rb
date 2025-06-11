# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class HbbTv
        include AbstractDeviceParser

        def parse
          return nil unless hbb_tv?

          super

          @device_type = 'tv' if @device_type.nil?

          result
        end

        protected

        def fixture_file
          'regexes/device/televisions.yml'
        end

        def parser_name
          'tv'
        end

        def hbb_tv?
          regex = '(?:HbbTV|SmartTvA)/([1-9]{1}(?:\.[0-9]{1}){1,2})'
          match_user_agent(regex)
        end
      end
    end
  end
end
