# frozen_string_literal: true

class DeviceDetector
  module Parser
    module AbstractParser
      @@overall_regex = nil

      REGEX_CACHE = ::DeviceDetector::MemoryCache.new({})
      private_constant :REGEX_CACHE

      def initialize
        @result = nil
      end

      def use(uas, hints)
        @user_agent = uas
        @client_hints = hints
      end

      def user_agent=(uas)
        @user_agent = uas
      end

      def client_hints=(hints)
        @client_hints = hints
      end

      protected

      def fuzzy_compare(val1, val2)
        val1.to_s.downcase.gsub(' ', '') == val2.to_s.downcase.gsub(' ', '')
      end

      def build_version(version_string, matches)
        version_string = build_by_match(version_string, matches)
        version_string = version_string.gsub('_', '.')

        version_string.chomp(' .')
      end

      def build_by_match(item, matches)
        result = item
        matches.each.with_index do |match, index|
          result = result.gsub("$#{index + 1}", match.to_s)
        end
        result.strip
      end

      def restore_user_agent_from_client_hints
        return if @client_hints.nil?

        device_model = @client_hints.model

        return if device_model == ''

        # Restore Android User Agent
        # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/AbstractParser.php#L144
        if user_agent_client_hints_fragment?
          os_version = @client_hints.operating_system_version
          self.user_agent = @user_agent.sub(
            /(Android (?:10[.\d]*; K|1[1-5]))/,
            "Android #{os_version == '' ? 10 : os_version}; #{device_model}"
          )
        end

        return unless desktop_fragment?

        self.user_agent = @user_agent.sub(
          /(X11; Linux x86_64)/,
          "'X11; Linux x86_64; #{device_model}"
        )
      end

      def user_agent_client_hints_fragment?
        @user_agent.match?(%r{Android (?:10[.\d]*; K(?: Build/|[;)])|1[1-5]\)) AppleWebKit}i)
      end

      def desktop_fragment?
        regex =
          [
            'CE-HTML',
            ' Mozilla/|Andr[o0]id|Tablet|Mobile|iPhone|Windows Phone|ricoh|OculusBrowser',
            'PicoBrowser|Lenovo|compatible; MSIE|Trident/|Tesla/|XBOX|FBMD/|ARM; ?([^)]+)'
          ].join('|')

        match_user_agent('(?:Windows (?:NT|IoT)|X11; Linux x86_64)') &&
          match_user_agent(regex)
      end

      def fixture_file
        ''
      end

      def parser_name
        ''
      end

      def regexes
        REGEX_CACHE.get_or_set(fixture_file) do
          object = YAML.load_file(fixture_file)
          unless object.is_a?(Array) || object.is_a?(Hash)
            raise "Invalid fixture loaded from #{fixture_file}: #{object.class}"
            object = []
          end
          object
        end
      end

      def pre_match_overall?
        overall_regex = REGEX_CACHE.get_or_set("overall-#{fixture_file}") do
          puts fixture_file

          # e.g. consoles.yml is a Hash
          regex_list = regexes
          regex_list = regex_list.values if regex_list.is_a?(Hash)

          regex_list.reduce('') do |res, regex|
            if regex
              "#{res}|#{regex['regex']}"
            else
              res
            end
          end.delete_prefix('|')
        end

        match_user_agent(overall_regex)
      end

      def match_user_agent(regex)
        src = regex.gsub('/', '\/')
        regexp = Regexp.new("(?:^|[^A-Z0-9_-]|[^A-Z0-9-]_|sprd-|MZ-)(?:#{src})", Regexp::IGNORECASE)

        # only match if useragent begins with given regex or there is no letter before it
        match = @user_agent.match(regexp)
        return unless match

        match.captures || []

        # result.size == 0 ? nil : result
      end
    end
  end
end
