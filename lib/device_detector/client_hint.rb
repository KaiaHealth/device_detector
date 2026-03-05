# frozen_string_literal: true

class DeviceDetector
  class ClientHint
    ROOT = File.expand_path('../..', __dir__)

    REGEX_CACHE = ::DeviceDetector::MemoryCache.new({})
    private_constant :REGEX_CACHE

    class HintBrowser < Struct.new(:name, :version)
    end

    def initialize(headers)
      return if headers.nil?

      @headers = headers
      @normalized_headers = normalize_headers(headers)
      @full_version = extract_full_version
      @browser_list = extract_browser_list
      @app_name = extract_app_name
      @platform = extract_platform
      @platform_version = extract_platform_version
      @mobile = extract_mobile
      @model = extract_model
      @form_factors = extract_form_factors
    end

    attr_reader :app_name, :browser_list, :full_version, :headers, :mobile, :model, :platform,
                :platform_version, :form_factors

    def browser_name
      return 'Iridium' if iridium?
      return '360 Secure Browser' if secure_browser?

      browser_name_from_list || app_name
    end

    def browser_version
      browser_version_from_list || full_version
    end

    def os_version
      return windows_version if platform == 'Windows'
      return lineage_version if lineage_os_app?
      return fire_os_version if fire_os_app?

      platform_version
    end

    def os_name
      return 'Android' if android_app?
      return 'Lineage OS' if lineage_os_app?
      return 'Fire OS' if fire_os_app?
      return unless ['Windows', 'Chromium OS'].include?(platform)

      platform
    end

    def os_short_name
      return if os_name.nil?

      DeviceDetector::OS::DOWNCASED_OPERATING_SYSTEMS[os_name.downcase]
    end

    def os_family
      return if os_short_name.nil?

      DeviceDetector::OS::FAMILY_TO_OS[os_short_name]
    end

    private

    # https://github.com/matomo-org/device-detector/blob/28211c6f411528abf41304e07b886fdf322a49b7/Parser/OperatingSystem.php#L330
    def android_app?
      %w[com.hisense.odinbrowser com.seraphic.openinet.pre
         com.appssppa.idesktoppcbrowser every.browser.inc].include?(app_name_from_headers)
    end

    # https://github.com/matomo-org/device-detector/blob/67ae11199a5129b42fa8b985d372ea834104fe3a/Parser/OperatingSystem.php#L449-L456
    def fire_os_app?
      app_name_from_headers == 'org.mozilla.tv.firefox'
    end

    # https://github.com/matomo-org/device-detector/blob/67ae11199a5129b42fa8b985d372ea834104fe3a/Parser/OperatingSystem.php#L439-L447
    def lineage_os_app?
      app_name_from_headers == 'org.lineageos.jelly'
    end

    # https://github.com/matomo-org/device-detector/blob/75d88bbefb0182f9207c9f48dc39b1bc8c7cc43f/Parser/Client/Browser.php#L1076-L1079
    def browser_name_from_list
      browser_from_list[:name]
    end

    def browser_version_from_list
      browser_from_list[:version]
    end

    # https://github.com/matomo-org/device-detector/blob/5fef894/Parser/Client/Browser.php#L1181-L1214
    def browser_from_list
      @browser_from_list ||= begin
        name = version = nil

        Array(browser_list).each do |browser|
          detected_name = name_from_known_browsers(browser.name)
          next if detected_name.nil?

          name = detected_name
          version = browser.version

          # Prefer the first detected brand that isn't generic Chromium/Edge.
          break unless ['Chromium', 'Microsoft Edge'].include?(name)
        end

        { name: name, version: (full_version || version) }
      end
    end

    def available_browsers
      DeviceDetector.cache.get_or_set('available_browsers') do
        browsers_path = File.join(ROOT, 'regexes', 'client', 'browsers.yml')
        names_from_regexes = YAML.load_file(browsers_path).map { |entry| entry['name'] }.compact
        (DeviceDetector::Browser::AVAILABLE_BROWSERS.values + names_from_regexes).uniq
      end
    end

    def available_osses
      DeviceDetector::OS::OPERATING_SYSTEMS.values
    end

    # https://github.com/matomo-org/device-detector/blob/28211c6f411528abf41304e07b886fdf322a49b7/Parser/OperatingSystem.php#L434
    def windows_version
      return if platform_version.nil?

      major_version = platform_version.split('.').first.to_i
      return if major_version < 1

      major_version < 11 ? '10' : '11'
    end

    def lineage_version
      DeviceDetector::OS
        .mapped_os_version(platform_version, DeviceDetector::OS::LINEAGE_OS_VERSION_MAPPING)
    end

    def fire_os_version
      DeviceDetector::OS
        .mapped_os_version(platform_version, DeviceDetector::OS::FIRE_OS_VERSION_MAPPING)
    end

    # https://github.com/matomo-org/device-detector/blob/67ae11199a5129b42fa8b985d372ea834104fe3a/Parser/Client/Browser.php#L923-L929
    # If the version reported from the client hints is YYYY or YYYY.MM (e.g., 2022 or 2022.04),
    # then it is the Iridium browser
    # https://iridiumbrowser.de/news/
    def iridium?
      return if browser_list.nil?

      !browser_list.find do |browser|
        browser.name == 'Chromium' && browser.version =~ /^202[0-4]/
      end.nil?
    end

    # https://github.com/matomo-org/device-detector/blob/67ae11199a5129b42fa8b985d372ea834104fe3a/Parser/Client/Browser.php#L931-L937
    # https://bbs.360.cn/thread-16096544-1-1.html
    def secure_browser?
      return if browser_list.nil?

      !browser_list.find do |browser|
        browser.name == 'Chromium' && browser.version =~ /^15/
      end.nil?
    end

    def app_name_from_headers
      app = extract_from_header('http-x-requested-with', 'x-requested-with')
      return if app.nil?
      return if app.to_s.downcase == 'xmlhttprequest'

      app
    end

    def extract_app_name
      requested_with = app_name_from_headers
      return if requested_with.nil?

      hint_app_names[requested_with]
    end

    def hint_app_names
      DeviceDetector.cache.get_or_set('hint_app_names') do
        load_hint_app_names.flatten.reduce({}, :merge)
      end
    end

    def hint_filenames
      %w[client/hints/browsers.yml client/hints/apps.yml]
    end

    def hint_filepaths
      hint_filenames.map do |filename|
        [filename.to_sym, File.join(ROOT, 'regexes', filename)]
      end
    end

    def load_hint_app_names
      hint_filepaths.map { |_, full_path| YAML.load_file(full_path) }
    end

    def extract_browser_list
      extract_browser_list_from_full_version_list ||
        extract_browser_list_from_header('Sec-CH-UA', 'Sec-CH-UA-Full-Version-List')
    end

    def extract_browser_list_from_header(*headers)
      value = extract_from_header(*headers)
      return if value.nil?

      value.split(', ').map do |component|
        name_and_version = extract_browser_name_and_version(component)
        next if name_and_version[:name].nil?

        HintBrowser.new(name_and_version[:name], name_and_version[:version])
      end.compact
    end

    def extract_browser_name_and_version(component)
      component_and_version = component.gsub('"', '').split("\;v=")
      name = name_from_known_browsers(component_and_version.first)
      browser_version = full_version || component_and_version.last
      { name: name, version: browser_version }
    end

    def extract_browser_list_from_full_version_list
      full_version_list = extract_from_header('brands', 'fullVersionList', 'fullversionlist')
      return unless full_version_list.is_a?(Array)

      full_version_list.map do |item|
        name = name_from_known_browsers(item['brand'])
        next if name.nil?

        HintBrowser.new(name, full_version || item['version'])
      end.compact
    end

    # https://github.com/matomo-org/device-detector/blob/be1c9ef486c247dc4886668da5ed0b1c49d90ba8/Parser/Client/Browser.php#L865
    def name_from_known_browsers(name)
      DeviceDetector::Browser::KNOWN_BROWSER_TO_NAME.fetch(name) do
        available_browsers.find do |i|
          i == name ||
            i.gsub(' ', '') == name.gsub(' ', '') ||
            i == name.gsub('Browser', '') ||
            i == name.gsub(' Browser', '') ||
            i == "#{name} Browser"
        end
      end
    end

    def extract_from_header(*header_names)
      return if @normalized_headers.nil?

      header_names.each do |header_name|
        normalized_name = normalize_header_name(header_name)
        value = @normalized_headers[normalized_name]
        next if value.nil? || value == ''

        return value
      end

      nil
    end

    def extract_full_version
      value = extract_from_header('Sec-CH-UA-Full-Version', 'uaFullVersion')
      value&.to_s&.delete_prefix('"')&.delete_suffix('"')
    end

    def extract_platform
      value = extract_from_header('Sec-CH-UA-Platform', 'platform')
      value&.to_s&.delete_prefix('"')&.delete_suffix('"')
    end

    def extract_platform_version
      value = extract_from_header('Sec-CH-UA-Platform-Version', 'platformVersion')
      value&.to_s&.delete_prefix('"')&.delete_suffix('"')
    end

    def extract_mobile
      value = extract_from_header('Sec-CH-UA-Mobile', 'mobile')
      return if value.nil?

      %w[?1 1 true].include?(value.to_s.downcase)
    end

    def extract_model
      value = extract_from_header('Sec-CH-UA-Model', 'model')
      value&.to_s&.delete_prefix('"')&.delete_suffix('"')
    end

    def extract_form_factors
      value = extract_from_header('formFactors', 'Sec-CH-UA-Form-Factors')
      return [] if value.nil?

      return value.map(&:to_s).map(&:downcase) if value.is_a?(Array)

      value.to_s.downcase.scan(/"([a-z]+)"/).flatten
    end

    def normalize_headers(headers)
      headers.each_with_object({}) do |(name, value), normalized|
        normalized[normalize_header_name(name)] = value
      end
    end

    def normalize_header_name(name)
      name.to_s.downcase.tr('_', '-')
    end
  end
end
