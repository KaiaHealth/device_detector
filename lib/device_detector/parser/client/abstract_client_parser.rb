# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Client
      module AbstractClientParser
        include AbstractParser

        TV_CLIENT_NAMES = [
          'Kylo', 'Espial TV Browser', 'LUJO TV Browser', 'LogicUI TV Browser', 'Open TV Browser', 'Seraphic Sraf',
          'Opera Devices', 'Crow Browser', 'Vewd Browser', 'TiviMate', 'Quick Search TV', 'QJY TV Browser', 'TV Bro'
        ].freeze

        def parser_type
          :client
        end

        def parse
          return unless pre_match_overall?

          regexes.detect do |regex|
            matches = match_user_agent(regex['regex'])

            next unless matches

            return {
              'type' => parser_name,
              'name' => build_by_match(regex['name'], matches),
              'version' => build_version(regex['version'].to_s, matches)
            }
          end
        end
      end
    end
  end
end
