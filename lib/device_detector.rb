# frozen_string_literal: true

require 'yaml'

require 'device_detector/version'
require 'device_detector/metadata_extractor'
require 'device_detector/version_extractor'
require 'device_detector/model_extractor'
require 'device_detector/name_extractor'
require 'device_detector/memory_cache'
require 'device_detector/parser'
require 'device_detector/bot'
require 'device_detector/client'
require 'device_detector/device'
require 'device_detector/os'
require 'device_detector/browser'
require 'device_detector/client_hint'
require 'device_detector/vendor_fragment'

class DeviceDetector
  attr_reader :client_hint, :user_agent

  def initialize(user_agent, headers = nil)
    @client_hint = ClientHint.new(headers)
    utf8_user_agent = encode_user_agent_if_needed(user_agent)
    @user_agent = build_user_agent(utf8_user_agent)
  end

  # https://github.com/matomo-org/device-detector/blob/a2535ff3b63e4187f1d3440aed24ff43d74fb7f1/Parser/Device/AbstractDeviceParser.php#L2065-L2073
  def build_user_agent(user_agent)
    return user_agent if client_hint.model.nil?

    ua = user_agent

    if ua =~ build_regex('Android (?:10[.\d]*; K|1[1-5])')
      version = client_hint.os_version || '10'
      ua = ua.gsub(/Android (?:10[.\d]*; K|1[1-5])/, "Android #{version}; #{client_hint.model}")
    end

    if ua =~ build_regex('X11; Linux x86_64')
      ua = ua.gsub('X11; Linux x86_64', "X11; Linux x86_64; #{client_hint.model}")
    end

    ua
  end

  def encode_user_agent_if_needed(user_agent)
    return if user_agent.nil?
    return user_agent if user_agent.encoding.name == 'UTF-8'

    user_agent.encode('utf-8', 'binary', undef: :replace)
  end

  def name
    user_agent_name = client.name
    hinted_name = client_hint.browser_name
    hinted_version = client_hint.browser_version

    merged_name = if hinted_name && hinted_version && !hinted_version.empty?
                    hinted_name
                  else
                    user_agent_name
                  end

    # If CH reports a generic Chromium/WebView browser, prefer a specific UA-detected browser.
    if ['Chromium', 'Chrome Webview'].include?(merged_name) &&
       user_agent_name && !%w[Chromium Chrome\ Webview Android\ Browser Chrome\ Mobile].include?(user_agent_name)
      merged_name = user_agent_name
    end

    # Fix mobile browser names e.g. "Chrome" => "Chrome Mobile".
    if hinted_name && "#{hinted_name} Mobile" == user_agent_name
      merged_name = user_agent_name
    end

    # Requested app id hints should override when available.
    app_name = client_hint.app_name
    merged_name = app_name if app_name && app_name != merged_name

    merged_name
  end

  def full_version
    client_hint.browser_version || client.full_version
  end

  def os_family
    return 'GNU/Linux' if linux_fix?

    merged_os_family
  end

  def os_name
    return 'GNU/Linux' if linux_fix?

    merged_os_name
  end

  def os_full_version
    return if skip_os_version?
    return os.full_version if pico_os_fix?
    return fire_os_version if fire_os_fix?

    client_hint.os_version || os.full_version
  end

  def device_name
    return if fake_ua?

    name = device.name || client_hint.model || fix_for_x_music
    name = philips_tv_model if (name.nil? || name =~ /^TPM[0-9A-Z]+$/) && philips_tv_model
    name = aoc_tv_model if name.nil? && aoc_tv_model
    name = whale_tv_model if name.nil? && !projector_fragment? && whale_tv_model
    name
  end

  def device_brand
    return if fake_ua?

    # Assume all devices running iOS / Mac OS are from Apple
    brand = device.brand
    brand = brand_from_tv_signature if brand.nil? || brand == 'Vestel'
    if brand.nil? && vestel_fragment?
      # Keep unknown/ambiguous TV signatures unbranded; non-TV Vestel fragments
      # (e.g. VTab family) should still resolve to Vestel.
      if device_type == 'tv'
        brand = 'Vestel' unless vestel_placeholder_signature?
      else
        brand = 'Vestel'
      end
    end
    brand = 'Apple' if brand.nil? && DeviceDetector::OS::APPLE_OS_NAMES.include?(os_name)
    brand = 'coocaa' if brand.nil? && os_name == 'Coolita OS'

    brand
  end

  def device_type
    t = device.type

    t = nil if fake_ua?
    t = device_type_from_form_factors if t.nil?
    t = 'peripheral' if projector_fragment? && (t.nil? || t == 'tv')

    # Chrome on Android passes the device type based on the keyword 'Mobile'
    # If it is present the device should be a smartphone, otherwise it's a tablet
    # See https://developer.chrome.com/multidevice/user-agent#chrome_for_android_user_agent
    # Note: We do not check for browser (family) here, as there might be mobile apps using Chrome,
    # that won't have a detected browser, but can still be detected. So we check the useragent for
    # Chrome instead.
    if t.nil? && os_family == 'Android' && user_agent =~ build_regex('Chrome\/[\.0-9]*')
      t = user_agent =~ build_regex('(?:Mobile|eliboM)') ? 'smartphone' : 'tablet'
    end

    # Some UA contain the fragment 'Pad/APad', so we assume those devices as tablets
    t = 'tablet' if t == 'smartphone' && user_agent =~ build_regex('Pad\/APad')

    # Some UA contain the fragment 'Android; Tablet;' or 'Opera Tablet', so we assume those devices
    # as tablets
    t = 'tablet' if t.nil? && (android_tablet_fragment? || opera_tablet?)

    # Some user agents simply contain the fragment 'Android; Mobile;', so we assume those devices
    # as smartphones
    t = 'smartphone' if t.nil? && android_mobile_fragment?

    # Some UA contains the 'Android; Mobile VR;' fragment
    t = 'wearable' if t.nil? && android_vr_fragment?

    # Android up to 3.0 was designed for smartphones only. But as 3.0,
    # which was tablet only, was published too late, there were a
    # bunch of tablets running with 2.x With 4.0 the two trees were
    # merged and it is for smartphones and tablets
    #
    # So were are expecting that all devices running Android < 2 are
    # smartphones Devices running Android 3.X are tablets. Device type
    # of Android 2.X and 4.X+ are unknown
    if t.nil? && os_name == 'Android' && os.full_version && !os.full_version.empty?
      full_version = Gem::Version.new(os.full_version)
      if full_version < VersionExtractor::MAJOR_VERSION_2
        t = 'smartphone'
      elsif full_version >= VersionExtractor::MAJOR_VERSION_3 && \
            full_version < VersionExtractor::MAJOR_VERSION_4
        t = 'tablet'
      end
    end

    # All detected feature phones running android are more likely a smartphone
    t = 'smartphone' if t == 'feature phone' && os_family == 'Android'

    # All unknown devices under running Java ME are more likely a features phones
    t = 'feature phone' if t.nil? && os_name == 'Java ME'

    # All devices running KaiOS are more likely feature phones.
    t = 'feature phone' if os_name == 'KaiOS'

    # According to http://msdn.microsoft.com/en-us/library/ie/hh920767(v=vs.85).aspx
    # Internet Explorer 10 introduces the "Touch" UA string token. If this token is present at the
    # end of the UA string, the computer has touch capability, and is running Windows 8 (or later).
    # This UA string will be transmitted on a touch-enabled system running Windows 8 (RT)
    #
    # As most touch enabled devices are tablets and only a smaller part are desktops/notebooks we
    # assume that all Windows 8 touch devices are tablets.
    if t.nil? && touch_enabled? &&
       (os_name == 'Windows RT' ||
        (os_name == 'Windows' && os_full_version &&
         Gem::Version.new(os_full_version) >= VersionExtractor::MAJOR_VERSION_8))
      t = 'tablet'
    end

    # Puffin desktop/smartphone/tablet suffix hints.
    t = 'desktop' if t.nil? && user_agent =~ /Puffin\/(?:\d+[.\d]+)[LMW]D/i
    t = 'smartphone' if t.nil? && user_agent =~ /Puffin\/(?:\d+[.\d]+)[AIFLW]P/i
    t = 'tablet' if t.nil? && user_agent =~ /Puffin\/(?:\d+[.\d]+)[AILW]T/i

    # All devices running Opera TV Store are assumed to be a tv
    t = 'tv' if opera_tv_store?

    # All devices running Coolita OS are assumed to be a tv.
    t = 'tv' if os_name == 'Coolita OS'

    # All devices that contain Andr0id in string are assumed to be a tv
    has_tv_fragment = user_agent =~ /Andr0id|(?:Android(?: UHD)?|Google) TV|\(lite\) TV|BRAVIA|Firebolt| TV$/i
    if has_tv_fragment && !%w[tv peripheral].include?(t)
      t = 'tv'
    end

    # All devices running Tizen TV or SmartTV are assumed to be a tv
    t = 'tv' if t.nil? && tizen_samsung_tv?

    # Devices running those clients are assumed to be a TV
    t = 'tv' if ['Kylo', 'Espial TV Browser', 'LUJO TV Browser', 'LogicUI TV Browser',
                 'Open TV Browser', 'Seraphic Sraf', 'Opera Devices', 'Crow Browser',
                 'Vewd Browser', 'TiviMate', 'Quick Search TV', 'QJY TV Browser',
                 'TV Bro', 'Redline'].include?(name)

    # All devices containing TV fragment are assumed to be a tv
    t = 'tv' if t.nil? && user_agent =~ build_regex('\(TV;')

    has_desktop = t != 'desktop' && desktop_string? && desktop_fragment?
    t = 'desktop' if has_desktop

    # set device type to desktop for all devices running a desktop os that were not detected as
    # another device type
    return t if t || !desktop?

    'desktop'
  end

  def known?
    client.known?
  end

  def bot?
    bot.bot?
  end

  def bot_name
    bot.name
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

  def bot
    @bot ||= Bot.new(user_agent)
  end

  def client
    @client ||= Client.new(user_agent)
  end

  def device
    @device ||= Device.new(user_agent)
  end

  def os
    @os ||= OS.new(user_agent)
  end

  # https://github.com/matomo-org/device-detector/blob/67ae11199a5129b42fa8b985d372ea834104fe3a/DeviceDetector.php#L931-L938
  def fake_ua?
    device.brand == 'Apple' && !DeviceDetector::OS::APPLE_OS_NAMES.include?(os_name)
  end

  def linux_fix?
    client_hint.platform == 'Linux' &&
      %w[iOS Android].include?(os.name) &&
      client_hint.mobile == false
  end

  def merged_os_name
    hinted_name = hinted_os_name
    user_agent_name = os.name

    if hinted_name
      user_agent_family = os.family || inferred_os_family(user_agent_name)

      # If CH provides a family name (e.g. Android, GNU/Linux) and UA provides a
      # more specific OS inside that family (e.g. Fire OS, Fedora), prefer UA.
      if user_agent_name && user_agent_name != hinted_name && user_agent_family == hinted_name
        return user_agent_name
      end

      # Meta Horizon is often reported as Linux in Client Hints.
      return user_agent_name if hinted_name == 'GNU/Linux' && user_agent_name == 'Meta Horizon'

      # Chrome OS may be reported as Linux in Client Hints.
      if hinted_name == 'GNU/Linux' &&
         user_agent_name == 'Chrome OS' &&
         !client_hint.os_version.nil? &&
         client_hint.os_version == os.full_version
        return user_agent_name
      end

      # Chrome OS may be reported as Android in Client Hints.
      return user_agent_name if hinted_name == 'Android' && user_agent_name == 'Chrome OS'

      return hinted_name
    end

    user_agent_name || client_hint.platform
  end

  def merged_os_family
    os_name = merged_os_name

    family = family_for_os_name(os_name) || inferred_os_family(os_name)
    return family if family

    hinted_family = family_for_os_name(hinted_os_name) || inferred_os_family(hinted_os_name)
    hinted_family || os.family || client_hint.platform
  end

  def hinted_os_name
    return client_hint.os_name if client_hint.os_name

    case client_hint.platform
    when 'Android'
      'Android'
    when 'Linux'
      'GNU/Linux'
    when 'MacOS'
      'Mac'
    else
      nil
    end
  end

  def family_for_os_name(os_name)
    return if os_name.nil?

    short = DeviceDetector::OS::DOWNCASED_OPERATING_SYSTEMS[os_name.downcase]
    return if short.nil?

    DeviceDetector::OS::FAMILY_TO_OS[short]
  end

  def inferred_os_family(os_name)
    return if os_name.nil?

    {
      'ArcaOS' => 'IBM',
      'Azure Linux' => 'GNU/Linux',
      'blackPanther OS' => 'GNU/Linux',
      'BSD' => 'Unix',
      'Contiki' => 'Other Mobile',
      'Coolita OS' => 'GNU/Linux',
      'elementary OS' => 'GNU/Linux',
      'GhostBSD' => 'Unix',
      'KolibriOS' => 'Real-time OS',
      'LeafOS' => 'Android',
      'Linpus' => 'GNU/Linux',
      'Meta Horizon' => 'Android',
      'MINIX' => 'Unix',
      'Mocor OS' => 'Real-time OS',
      'NuttX' => 'Real-time OS',
      'openSUSE' => 'GNU/Linux',
      'OpenHarmony' => 'Android',
      'Orsay' => 'Other Smart TV',
      'Plan 9' => 'Unix',
      'Puffin OS' => 'Android',
      'risingOS' => 'Android',
      'RTOS & Next' => 'Real-time OS',
      'Smartisan OS' => 'Android',
      'Titan OS' => 'Other Smart TV',
      'ViziOS' => 'GNU/Linux'
    }[os_name]
  end

  def brand_from_tv_signature
    token = user_agent[/\(Vestel MB[0-9A-Z]+\s+([A-Z0-9_+\-]+)\)/i, 1]
    token ||= user_agent[/FVC\/[0-9.]+\s+\(([A-Z0-9_+\-]+);\s*MB[0-9A-Z]+;/i, 1]
    token ||= user_agent[/HbbTV\/[0-9.]+\s+\((?:\+DRM;\s*)?([A-Z0-9_+\-]+);\s*MB[0-9A-Z]+;/i, 1]
    token ||= user_agent[/MB9[78]\/[0-9.]+\s+\(([^,;()]+),/i, 1]
    token ||= user_agent[/\((Hotack)[0-9A-Z]*;/i, 1]
    token ||= user_agent[/Model\/[A-Z0-9]+\s+\(([A-Za-z0-9_+\-]+);WHALEOS/i, 1]
    return if token.nil?

    normalized = token.strip
    return 'HOTACK' if normalized.casecmp('hotack').zero?
    return 'VOX Electronics' if normalized.casecmp('vox').zero?
    return 'elit' if normalized.casecmp('elit').zero?
    return 'Top-Tech' if normalized.downcase.start_with?('toptech')
    return 'HIGH1ONE' if normalized.casecmp('high_one').zero? || normalized.casecmp('highone').zero?
    normalized = normalized.sub(/[0-9]+$/, '')

    normalized_key = normalized.gsub(/[^a-z0-9]/i, '').downcase
    known_brand = DeviceDetector::Device::DEVICE_BRANDS.values.find do |value|
      value.gsub(/[^a-z0-9]/i, '').downcase == normalized_key
    end

    known_brand || normalized
  end

  def philips_tv_model
    user_agent[/;Philips;([^;]+);TPM/i, 1]
  end

  def aoc_tv_model
    user_agent[/\(AOC,\s*([^,()]+),/i, 1] || user_agent[/\(AOC;([^;()]+);/i, 1]
  end

  def whale_tv_model
    year = user_agent[/LaTivu_(?:\d+[.\d]+)_([0-9]{4})/, 1]
    return if year.nil?

    "Smart TV (#{year})"
  end

  # Related to issue mentionned in device.rb#1562
  def fix_for_x_music
    user_agent&.include?('X-music Ⅲ') ? 'X-Music III' : nil
  end

  def pico_os_fix?
    client_hint.os_name == 'Pico OS'
  end

  # https://github.com/matomo-org/device-detector/blob/323629cb679c8572a9745cba9c3803fee13f3cf6/Parser/OperatingSystem.php#L398-L403
  def fire_os_fix?
    !client_hint.platform.nil? && os.name == 'Fire OS'
  end

  def fire_os_version
    DeviceDetector::OS
      .mapped_os_version(client_hint.os_version, DeviceDetector::OS::FIRE_OS_VERSION_MAPPING)
  end

  # https://github.com/matomo-org/device-detector/blob/323629cb679c8572a9745cba9c3803fee13f3cf6/Parser/OperatingSystem.php#L378-L383
  def skip_os_version?
    hinted_family = family_for_os_name(hinted_os_name) || inferred_os_family(hinted_os_name) || client_hint.os_family
    !hinted_family.nil? &&
      client_hint.os_version.nil? &&
      hinted_family != os.family
  end

  def projector_fragment?
    user_agent =~ /_Projector_|Projector/i
  end

  def vestel_fragment?
    user_agent =~ /\bVESTEL\b|\bVestel\b|Vestel_|VSTVB MB|Venus[_ -]|V[_ ]TAB|\bVTAB[0-9A-Z]+\b|\bVT[0-9]{2,}[A-Z0-9]*\b|\bVP[0-9]{2,}[A-Z0-9]*\b|VSP[0-9A-Z]+|V3_[0-9]+/i
  end

  def vestel_placeholder_signature?
    user_agent =~ /HbbTV\/[0-9.]+\s+\(\s*;\s*TEST;\s*MB[0-9A-Z]+;/i
  end

  def device_type_from_form_factors
    mapping = {
      'automotive' => 'car browser',
      'xr' => 'wearable',
      'watch' => 'wearable',
      'mobile' => 'smartphone',
      'tablet' => 'tablet',
      'desktop' => 'desktop',
      'eink' => 'tablet'
    }

    form_factors = Array(client_hint.form_factors).map { |form_factor| form_factor.to_s.downcase }

    mapping.each do |form_factor, device_type|
      return device_type if form_factors.include?(form_factor)
    end

    nil
  end

  def android_tablet_fragment?
    user_agent =~ build_regex('Android( [\.0-9]+)?; Tablet;|Tablet(?! PC)|.*\-tablet$')
  end

  def android_mobile_fragment?
    user_agent =~ build_regex('Android( [\.0-9]+)?; Mobile;|.*\-mobile$')
  end

  def android_vr_fragment?
    user_agent =~ build_regex('Android( [\.0-9]+)?; Mobile VR;| VR ')
  end

  def desktop_fragment?
    user_agent =~ build_regex('Desktop(?: (x(?:32|64)|WOW64))?;')
  end

  def touch_enabled?
    user_agent =~ build_regex('Touch')
  end

  def opera_tv_store?
    user_agent =~ build_regex('Opera TV Store|OMI/')
  end

  def opera_tablet?
    user_agent =~ build_regex('Opera Tablet')
  end

  def tizen_samsung_tv?
    user_agent =~ build_regex('SmartTV|Tizen.+ TV .+$')
  end

  def uses_mobile_browser?
    client.browser? && client.mobile_only_browser?
  end

  # This is a workaround until we support detecting mobile only browsers
  def desktop_string?
    user_agent =~ /Desktop/
  end

  def desktop?
    return false if os_name.nil? || os_name == '' || os_name == 'UNK'

    # Check for browsers available for mobile devices only
    return false if uses_mobile_browser?

    DeviceDetector::OS::DESKTOP_OSS.include?(os_family)
  end

  def build_regex(src)
    Regexp.new('(?:^|[^A-Z0-9\_\-])(?:' + src + ')', Regexp::IGNORECASE)
  end
end
