# frozen_string_literal: true

class DeviceDetector
  module Parser
    class Bot < AbstractParser
      def parser_type
        :bot
      end

      def parse
        return @result unless pre_match_overall?

        regexes.each do |regex|
          if match_user_agent(regex['regex'])
            @result = regex
            break
          end
        end

        @result
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
