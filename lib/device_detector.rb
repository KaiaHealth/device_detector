# frozen_string_literal: true

require 'yaml'

require 'device_detector/version'
require 'device_detector/memory_cache'

require 'device_detector/client_hint'

require 'device_detector/parser/abstract_parser'
require 'device_detector/parser/bot'
require 'device_detector/parser/operating_system'
require 'device_detector/parser/vendor_fragment'
require 'device_detector/parser/client/abstract_client_parser'
require 'device_detector/parser/client/feed_reader'
require 'device_detector/parser/client/mobile_app'
require 'device_detector/parser/client/media_player'
require 'device_detector/parser/client/pim'
require 'device_detector/parser/client/browser'
require 'device_detector/parser/client/library'
require 'device_detector/parser/device/abstract_device_parser'
require 'device_detector/parser/device/hbb_tv'
require 'device_detector/parser/device/shell_tv'
require 'device_detector/parser/device/notebook'
require 'device_detector/parser/device/console'
require 'device_detector/parser/device/car_browser'
require 'device_detector/parser/device/camera'
require 'device_detector/parser/device/portable_media_player'
require 'device_detector/parser/device/mobile'

class DeviceDetector
  MAJOR_VERSION_2 = Gem::Version.new('2.0')
  MAJOR_VERSION_3 = Gem::Version.new('3.0')
  MAJOR_VERSION_4 = Gem::Version.new('4.0')
  MAJOR_VERSION_8 = Gem::Version.new('8.0')

  attr_reader :client_hint, :user_agent

  def initialize(user_agent, headers = nil)
    self.user_agent = user_agent
    self.headers = headers

    @parsers = {}

    add_parser(Parser::Client::FeedReader.new)
    add_parser(Parser::Client::MobileApp.new)
    add_parser(Parser::Client::MediaPlayer.new)
    add_parser(Parser::Client::Pim.new)
    add_parser(Parser::Client::Browser.new)
    add_parser(Parser::Client::Library.new)

    add_parser(Parser::Device::HbbTv.new)
    add_parser(Parser::Device::ShellTv.new)
    add_parser(Parser::Device::Notebook.new)
    add_parser(Parser::Device::Console.new)
    add_parser(Parser::Device::CarBrowser.new)
    add_parser(Parser::Device::Camera.new)
    add_parser(Parser::Device::PortableMediaPlayer.new)
    add_parser(Parser::Device::Mobile.new)

    add_parser(Parser::Bot.new)

    reset
    parse
  end

  def name
    return unless @client

    @client['name']
  end

  def full_version
    return unless @client

    @client['version']
  end

  def os_family
    presence(@os&.fetch('family', nil))
  end

  def os_name
    presence(@os&.fetch('name', nil))
  end

  def os_full_version
    presence(@os&.fetch('version', nil))
  end

  def device_name
    presence(@model)
  end

  def device_brand
    presence(@brand)
  end

  def device_type
    presence(@device)
  end

  def known?
    !@client.nil?
  end

  def bot?
    @bot ? true : false
  end

  def bot_name
    @bot&.fetch('name', nil)
  end

  class << self
    class Configuration
      attr_accessor :max_cache_keys

      def to_hash
        {
          max_cache_keys: max_cache_keys
        }
      end
    end

    def config
      @config ||= Configuration.new
    end

    def cache
      @cache ||= MemoryCache.new(config.to_hash)
    end

    def configure
      @config = Configuration.new
      yield(config)
    end
  end

  private

  def parse
    return if @parsed

    @parsed = true

    return if (@user_agent.empty? || @user_agent !~ /[a-z]/i) && @client_hints.nil?

    parse_bot
    return if bot?

    parse_os
    parse_client
    parse_device
  end

  # COPY_COMPLETE
  def parse_bot
    @parsers.fetch(:bot, []).each do |parser|
      parser.use(@user_agent, @client_hints)

      bot = parser.parse

      if bot
        @bot = bot
        break
      end
    end
  end

  def parse_os
    parser = Parser::OperatingSystem.new
    parser.use(@user_agent, @client_hints)

    @os = parser.parse
  end

  def parse_client
    @parsers.fetch(:client, []).each do |parser|
      parser.use(@user_agent, @client_hints)

      client = parser.parse

      if client
        @client = client
        break
      end
    end
  end

  def parse_device
    @parsers.fetch(:device, []).each do |parser|
      parser.use(@user_agent, @client_hints)

      device = parser.parse

      next unless device

      @device = device['device_type']
      @model = presence(device['model'])
      @brand = presence(device['brand'])
      break
    end

    @model = @client_hints.model if !@model && @client_hints

    unless @brand
      vendor_parser = DeviceDetector::Parser::VendorFragment.new(@user_agent)
      @brand = presence(vendor_parser.parse || nil)
    end

    if @brand == 'Apple' && !DeviceDetector::Parser::OperatingSystem::APPLE_OS_NAMES.include?(os_name)
      @device = nil
      @brand = nil
      @model = nil
    end

    if !@brand && DeviceDetector::Parser::OperatingSystem::APPLE_OS_NAMES.include?(os_name)
      @brand = 'Apple'
    end

    @device = 'wearable' if @device.nil? && android_vr_fragment?

    if @device.nil? && os_family == 'Android' \
      && match_user_agent('Chrome/[.0-9]*')

      @device = if match_user_agent('(?:Mobile|eliboM)')
                  'smartphone'
                else
                  'tablet'
                end
    end

    @device = 'tablet' if @device == 'smartphone' && match_user_agent('Pad/APad')

    if @device.nil? && (android_tablet_fragment? \
      || match_user_agent('Opera Tablet'))
      @device = 'tablet'
    end

    @device = 'smartphone' if @device.nil? && android_mobile_fragment?

    if @device.nil? && os_name == 'Android' && presence(os_full_version)
      full_version = Gem::Version.new(os_full_version)
      if full_version < MAJOR_VERSION_2
        @device = 'smartphone'
      elsif full_version >= MAJOR_VERSION_3 &&
            full_version < MAJOR_VERSION_4
        @device = 'tablet'
      end
    end

    @device = 'smartphone' if @device == 'feature phone' && os_family == 'Android'

    @device = 'feature phone' if @device.nil? && os_name == 'Java ME'

    @device = 'feature phone' if os_name == 'KaiOS'

    if @device.nil? && touch_enabled? &&
       (os_name == 'Windows RT' ||
        (os_name == 'Windows' && os_full_version &&
         Gem::Version.new(os_full_version) >= MAJOR_VERSION_8))
      @device = 'tablet'
    end

    @device = 'desktop' if @device.nil? && match_user_agent('Puffin/(?:\d+[.\d]+)[LMW]D')

    @device = 'smartphone' if @device.nil? && match_user_agent('Puffin/(?:\d+[.\d]+)[AIFLW]P')

    @device = 'tablet' if @device.nil? && match_user_agent('Puffin/(?:\d+[.\d]+)[AILW]T')

    @device = 'tv' if match_user_agent('Opera TV Store| OMI/')

    @device = 'tv' if os_name == 'Coolita OS'

    if !%w[tv periphereal].include?(@device) &&
       match_user_agent('Andr0id|(?:Android(?: UHD)?|Google) TV|\(lite\) TV|BRAVIA| TV$')
      @device = 'tv'
    end

    @device = 'tv' if @device.nil? && match_user_agent('SmartTV|Tizen.+ TV .+$')

    if DeviceDetector::Parser::Client::AbstractClientParser::TV_CLIENT_NAMES.include?(name)
      @device = 'tv'
    end

    @device = 'tv' if @device.nil? && match_user_agent('\(TV;')

    if @device != 'desktop' && @user_agent.to_s.include?('Desktop') && desktop_fragment?
      @device = 'desktop'
    end

    return if !@device.nil? || !desktop?

    @device = 'desktop'
  end

  # Sets the useragent to be parsed
  # https://github.com/matomo-org/device-detector/blob/6.4.5/DeviceDetector.php#L245
  def user_agent=(user_agent)
    reset if @user_agent != user_agent

    @user_agent = user_agent || ''
  end

  def headers=(headers)
    @headers = headers
    @headers ||= {}

    @client_hints = ClientHint.new(@headers)
  end

  # Resets all detected data
  def reset
    @bot    = nil
    @client = nil
    @device = nil
    @os     = nil
    @brand  = nil
    @model  = nil
    @parsed = false
  end

  def add_parser(parser)
    type = parser.parser_type

    @parsers[type] ||= []
    @parsers[type] << parser
  end

  def match_user_agent(regex)
    src = regex.gsub('/', '\/')
    regexp = Regexp.new("(?:^|[^A-Z_-])(?:#{src})", Regexp::IGNORECASE)
    match = @user_agent.match(regexp)
    return unless match

    match.captures || []
  end

  def android_vr_fragment?
    match_user_agent('Android( [.0-9]+)?; Mobile VR;| VR ')
  end

  def android_tablet_fragment?
    match_user_agent('Android( [.0-9]+)?; Tablet;|Tablet(?! PC)|.*\-tablet$')
  end

  def android_mobile_fragment?
    match_user_agent('Android( [.0-9]+)?; Mobile;|.*\-mobile$')
  end

  def desktop_fragment?
    match_user_agent('Desktop(?: (x(?:32|64)|WOW64))?;')
  end

  def desktop?
    return false if os_name.nil? || os_name.empty? || os_name == 'UNK'

    return false if uses_mobile_browser?

    DeviceDetector::Parser::OperatingSystem.desktop_os?(os_name)
  end

  def uses_mobile_browser?
    @client&.fetch('type') == 'browser' && DeviceDetector::Parser::Client::Browser.mobile_only_browser?(name)
  end

  def touch_enabled?
    match_user_agent('Touch')
  end

  def presence(var)
    return nil if var.nil?
    return nil if var.empty?
    return nil if var == ''

    var
  end
end
