# frozen_string_literal: true

class DeviceDetector
  module Parser
    class VendorFragment < AbstractParser
      def initialize(uas)
        self.user_agent = uas
      end

      def parse
        regexes.each do |brand, many_regexes|
          many_regexes.each do |regex|
            if match_user_agent(regex + '[^a-z0-9]+')
              @matched_regex = regex
              return brand
            end
          end
        end

        nil
      end

      protected

      def fixture_file
        'regexes/vendorfragments.yml'
      end

      def parser_name
        'vendorfragments'
      end
    end
  end
end
