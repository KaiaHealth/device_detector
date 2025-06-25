# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Client
      class AbstractClientParser < AbstractParser
        TV_CLIENT_NAMES = [
          'Kylo', 'Espial TV Browser', 'LUJO TV Browser', 'LogicUI TV Browser', 'Open TV Browser', 'Seraphic Sraf',
          'Opera Devices', 'Crow Browser', 'Vewd Browser', 'TiviMate', 'Quick Search TV', 'QJY TV Browser', 'TV Bro'
        ].freeze

        def parser_type
          :client
        end

        def parse
          return unless pre_match_overall?

          regex, matches = regex_from_user_agent_cache do
            regexes.detect do |regex|
              match = match_user_agent_r(regex['regex'])
              match ? break [regex, match] : nil
            end
          end

          return nil unless regex

          {
            'type' => parser_name,
            'name' => build_by_match(regex['name'], matches),
            'version' => build_version(regex['version'].to_s, matches)
          }
        end
      end
    end
  end
end
