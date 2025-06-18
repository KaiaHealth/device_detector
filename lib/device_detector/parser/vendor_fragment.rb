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
            # perf: the additional suffex needed here will be added in
            # prepare_definition_for_cache already
            if match_user_agent_r(regex)
              @matched_regex = regex
              return brand
            end
          end
        end

        nil
      end

      protected

      # overriden from AbstractParser
      def prepare_definition_for_cache(definition)
        definition.map { |s| build_regex_for_ua(s + '[^a-z0-9]+') }
      end

      def fixture_file
        'regexes/vendorfragments.yml'
      end

      def parser_name
        'vendorfragments'
      end
    end
  end
end
