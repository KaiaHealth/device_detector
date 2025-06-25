# frozen_string_literal: true

class DeviceDetector
  module Parser
    class Bot < AbstractParser
      def parser_type
        :bot
      end

      def parse
        return nil unless pre_match_overall?

        regex_from_user_agent_cache do
          regexes.detect do |regex|
            match_user_agent_r(regex['regex'])
          end
        end
      end

      protected

      def fixture_file
        'regexes/bots.yml'
      end

      def parser_name
        'bot'
      end
    end
  end
end
