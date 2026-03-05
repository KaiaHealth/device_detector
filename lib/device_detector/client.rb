# frozen_string_literal: true

class DeviceDetector
  class Client < Parser
    def known?
      regex_meta.any?
    end

    def browser?
      regex_meta[:path] == :"client/browsers.yml"
    end

    def mobile_only_browser?
      DeviceDetector::Browser.mobile_only_browser?(name)
    end

    private

    # https://github.com/matomo-org/device-detector/blob/5fef894/Parser/Client/Browser.php#L1145-L1147
    # Browser parser explicitly ignores these UAs so that Library parser can detect them.
    def matching_regex
      from_cache([self.class.name, user_agent]) do
        regexes.find do |regex|
          next false unless user_agent =~ regex[:regex]
          next false if skip_browser_match?(regex)

          true
        end
      end
    end

    def skip_browser_match?(regex)
      regex[:path] == :"client/browsers.yml" && user_agent =~ /Cypress|PhantomJS/
    end

    def filenames
      [
        'client/feed_readers.yml',
        'client/mobile_apps.yml',
        'client/mediaplayers.yml',
        'client/pim.yml',
        'client/browsers.yml',
        'client/libraries.yml'
      ]
    end
  end
end
