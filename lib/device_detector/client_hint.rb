# frozen_string_literal: true

class DeviceDetector
  class ClientHint
    def initialize(headers)
      return if headers.nil?
      return if headers.empty?

      @architecture = ''
      @bitness = ''
      @mobile = ''
      @model = ''
      @ua_full_version = ''
      @platform = ''
      @platform_version = ''

      parse_headers(headers)
    end

    attr_reader :architecture, :bitness, :mobile, :model, :ua_full_version, :platform,
                :platform_version, :app

    def operating_system
      platform
    end

    def operating_system_version
      platform_version
    end

    def brand_list
      if @full_version_list.is_a?(Array) && @full_version_list.size.positive?
        return @full_version_list
      end

      []
    end

    def brand_version
      return @ua_full_version if @ua_full_version

      nil
    end

    private

    # https://github.com/matomo-org/device-detector/blob/6.4.5/ClientHints.php#L253
    def parse_headers(headers)
      @mobile = false

      headers.each do |name, value|
        next if value.nil? || value == ''

        name = name.downcase.gsub('_', '')

        case name
        when 'http-sec-ch-ua-arch', 'sec-ch-ua-arch', 'arch', 'architecture'
          @architecture = clean_header_value(value)
        when 'http-sec-ch-ua-bitness', 'sec-ch-ua-bitness', 'bitness'
          @bitness = clean_header_value(value)
        when 'http-sec-ch-ua-mobile', 'sec-ch-ua-mobile', 'mobile'
          @mobile = clean_header_value(value).in?([true, 'true', '1', 1, '?1'])
        when 'http-sec-ch-ua-model', 'sec-ch-ua-model', 'model'
          @model = clean_header_value(value)
        when 'http-sec-ch-ua-full-version', 'sec-ch-ua-full-version', 'uafullversion'
          @ua_full_version = clean_header_value(value)
        when 'http-sec-ch-ua-platform', 'sec-ch-ua-platform', 'platform'
          @platform = clean_header_value(value)
        when 'http-sec-ch-ua-platform-version', 'sec-ch-ua-platform-version', 'platformversion'
          @platform_version = clean_header_value(value)
        when 'brands'
          next unless @full_version_list.nil?

          self.full_version_list = value
        when 'fullversionlist'
          self.full_version_list = value
        when 'http-sec-ch-ua', 'http-sec-ch-ua-full-version-list', 'sec-ch-ua-full-version-list'
          parse_full_version_list(value)
        when 'sec-ch-ua'
          next unless @full_version_list.nil?

          parse_full_version_list(value)
        when 'http-x-requested-with', 'x-requested-with'
          @app = value if value.downcase == 'xmlhttprequest'
        when 'formfactors', 'http-sec-ch-ua-form-factors', 'sec-ch-ua-form-factors'
          if value.is_a?(Array)
            @form_factors = value.map(&:downcase)
          else
            hits = value.scan(/"([a-z]+)"/i)
            @form_factors = hits[1] unless hits.nil?
          end
        end
      end
    end

    def clean_header_value(str)
      str.delete_prefix!('"')
      str.delete_suffix!('"')
      str
    end

    def full_version_list=(value)
      @full_version_list = value.is_a?(Array) ? value : @full_version_list
    end

    def parse_full_version_list(value)
      list = []
      while hit = value.match(/^"([^"]+)"; ?v="([^"]+)"(?:, )?/)
        list << { 'brand' => hit[1], 'version' => hit[2] }
        value.slice!(hit[0].size, -1)
      end

      @full_version_list = list if list.size.positive?
    end
  end
end
