# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      class ShellTv
        include AbstractDeviceParser

        def parse
          return nil unless shell_tv?

          super

          @device_type = 'tv'

          result
        end

        protected

        def fixture_file
          'regexes/device/shell_tv.yml'
        end

        def parser_name
          'shelltv'
        end

        def shell_tv?
          regex = '[a-z]+[ _]Shell[ _]\w{6}|tclwebkit(\d+[.\d]*)'
          match_user_agent(regex)
        end
      end
    end
  end
end
