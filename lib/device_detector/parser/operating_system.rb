# frozen_string_literal: true

class DeviceDetector
  module Parser
    class OperatingSystem
      include AbstractParser

      def parser_type
        :os
      end

      def parse
        name = nil
        version = nil
        short = nil

        restore_user_agent_from_client_hints

        os_from_client_hints = parse_os_from_client_hints
        os_from_ua = parse_os_from_user_agent

        if os_from_client_hints['name']
          name = os_from_client_hints['name']
          version = os_from_client_hints['version']

          if version.nil? && os_family(name) == os_family(os_from_ua['name'])
            version = os_from_ua['version']
          end

          if name == 'Windows' && version == '0.0.0'
            version = os_from_ua['version'] == '10' ? nil : os_from_ua['version']
          end

          if os_family(os_from_ua['name']) && os_from_ua['name'] != name
            name = os_from_ua['name']

            version = nil if %w[LeafOS HarmonyOS].include?(name)

            version = os_from_ua['version'] if name == 'PICO OS'

            if name == 'Fire OS' && os_from_client_hints['version']
              major_version = version.split('.').first || 0
              version = FIRE_OS_MAPPING[version] || FIRE_OS_MAPPING[major_version] || ''
            end
          end

          short = os_from_client_hints['short_name']

          if name == 'GNU/Linux' && os_from_ua['name'] == 'Chrome OS' && os_from_client_hints['version'] == os_from_ua['version']
            name = os_from_ua['name']
            short = os_from_ua['short']
          end

          if name == 'Android' && os_from_ua['name'] == 'Chrome OS'
            name = os_from_ua['name']
            version = nil
            short = os_from_ua['short_name']
          end

          if name == 'GNU/Linux' && os_from_ua['name'] == 'Meta Horizon'
            name = os_from_ua['name']
            short = os_from_ua['short_name']
          end
        elsif os_from_ua['name']
          name = os_from_ua['name']
          version = os_from_ua['version']
          short = os_from_ua['short_name']
        else
          return {}
        end

        platform = parse_platform
        family = os_family(short)

        if @client_hints
          if ANDROID_APPS.include?(@client_hints.app) && name != 'Android'
            name = 'Android'
            family = 'Android'
            short = 'ADR'
            version = ''
          end

          if @client_hints.app == 'org.lineageos.jelly' && name != 'Lineage OS'
            major_version = version.split('.').first || '0'

            name = 'Lineage OS'
            family = 'Android'
            short = 'LEN'
            version = LINEAGE_OS_VERSION_MAPPING[version] || LINEAGE_OS_VERSION_MAPPING[major_version] || ''
          end

          if @client_hints.app == 'org.mozilla.tv.firefox' && name != 'Fire OS'
            major_version = version.split('.').first || '0'

            name = 'Fire OS'
            family = 'Android'
            short = 'FIR'
            version = FIRE_OS_MAPPING[version] || FIRE_OS_MAPPING[major_version] || ''
          end
        end

        result = {
          'name' => name,
          'short_name' => short,
          'version' => version,
          'platform' => platform,
          'family' => family
        }

        if OPERATING_SYSTEMS.key?(result['name'])
          result['short_name'], result['name'] = short_os_data(result['name'])
        end

        result
      end

      protected

      def fixture_file
        'regexes/oss.yml'
      end

      def parser_name
        'os'
      end

      ANDROID_APPS = [
        'com.hisense.odinbrowser', 'com.seraphic.openinet.pre', 'com.appssppa.idesktoppcbrowser',
        'every.browser.inc'
      ].freeze

      APPLE_OS_NAMES = %w[iPadOS tvOS watchOS iOS Mac].freeze

      OPERATING_SYSTEMS = {
        'AIX' => 'AIX',
        'AND' => 'Android',
        'ADR' => 'Android TV',
        'ALP' => 'Alpine Linux',
        'AMZ' => 'Amazon Linux',
        'AMG' => 'AmigaOS',
        'ARM' => 'Armadillo OS',
        'ARO' => 'AROS',
        'ATV' => 'tvOS',
        'ARL' => 'Arch Linux',
        'AOS' => 'AOSC OS',
        'ASP' => 'ASPLinux',
        'AZU' => 'Azure Linux',
        'BTR' => 'BackTrack',
        'SBA' => 'Bada',
        'BYI' => 'Baidu Yi',
        'BEO' => 'BeOS',
        'BLB' => 'BlackBerry OS',
        'QNX' => 'BlackBerry Tablet OS',
        'PAN' => 'blackPanther OS',
        'BOS' => 'Bliss OS',
        'BMP' => 'Brew',
        'BSN' => 'BrightSignOS',
        'CAI' => 'Caixa Mágica',
        'CES' => 'CentOS',
        'CST' => 'CentOS Stream',
        'CLO' => 'Clear Linux OS',
        'CLR' => 'ClearOS Mobile',
        'COS' => 'Chrome OS',
        'CRS' => 'Chromium OS',
        'CHN' => 'China OS',
        'COL' => 'Coolita OS',
        'CYN' => 'CyanogenMod',
        'DEB' => 'Debian',
        'DEE' => 'Deepin',
        'DFB' => 'DragonFly',
        'DVK' => 'DVKBuntu',
        'ELE' => 'ElectroBSD',
        'EUL' => 'EulerOS',
        'FED' => 'Fedora',
        'FEN' => 'Fenix',
        'FOS' => 'Firefox OS',
        'FIR' => 'Fire OS',
        'FOR' => 'Foresight Linux',
        'FRE' => 'Freebox',
        'BSD' => 'FreeBSD',
        'FRI' => 'FRITZ!OS',
        'FYD' => 'FydeOS',
        'FUC' => 'Fuchsia',
        'GNT' => 'Gentoo',
        'GNX' => 'GENIX',
        'GEO' => 'GEOS',
        'GNS' => 'gNewSense',
        'GRI' => 'GridOS',
        'GTV' => 'Google TV',
        'HPX' => 'HP-UX',
        'HAI' => 'Haiku OS',
        'IPA' => 'iPadOS',
        'HAR' => 'HarmonyOS',
        'HAS' => 'HasCodingOS',
        'HEL' => 'HELIX OS',
        'IRI' => 'IRIX',
        'INF' => 'Inferno',
        'JME' => 'Java ME',
        'JOL' => 'Joli OS',
        'KOS' => 'KaiOS',
        'KAL' => 'Kali',
        'KAN' => 'Kanotix',
        'KIN' => 'KIN OS',
        'KNO' => 'Knoppix',
        'KTV' => 'KreaTV',
        'KBT' => 'Kubuntu',
        'LIN' => 'GNU/Linux',
        'LEA' => 'LeafOS',
        'LND' => 'LindowsOS',
        'LNS' => 'Linspire',
        'LEN' => 'Lineage OS',
        'LIR' => 'Liri OS',
        'LOO' => 'Loongnix',
        'LBT' => 'Lubuntu',
        'LOS' => 'Lumin OS',
        'LUN' => 'LuneOS',
        'VLN' => 'VectorLinux',
        'MAC' => 'Mac',
        'MAE' => 'Maemo',
        'MAG' => 'Mageia',
        'MDR' => 'Mandriva',
        'SMG' => 'MeeGo',
        'MET' => 'Meta Horizon',
        'MCD' => 'MocorDroid',
        'MON' => 'moonOS',
        'EZX' => 'Motorola EZX',
        'MIN' => 'Mint',
        'MLD' => 'MildWild',
        'MOR' => 'MorphOS',
        'NBS' => 'NetBSD',
        'MTK' => 'MTK / Nucleus',
        'MRE' => 'MRE',
        'NXT' => 'NeXTSTEP',
        'NWS' => 'NEWS-OS',
        'WII' => 'Nintendo',
        'NDS' => 'Nintendo Mobile',
        'NOV' => 'Nova',
        'OS2' => 'OS/2',
        'T64' => 'OSF1',
        'OBS' => 'OpenBSD',
        'OVS' => 'OpenVMS',
        'OVZ' => 'OpenVZ',
        'OWR' => 'OpenWrt',
        'OTV' => 'Opera TV',
        'ORA' => 'Oracle Linux',
        'ORD' => 'Ordissimo',
        'PAR' => 'Pardus',
        'PCL' => 'PCLinuxOS',
        'PIC' => 'PICO OS',
        'PLA' => 'Plasma Mobile',
        'PSP' => 'PlayStation Portable',
        'PS3' => 'PlayStation',
        'PVE' => 'Proxmox VE',
        'PUF' => 'Puffin OS',
        'PUR' => 'PureOS',
        'QTP' => 'Qtopia',
        'PIO' => 'Raspberry Pi OS',
        'RAS' => 'Raspbian',
        'RHT' => 'Red Hat',
        'RST' => 'Red Star',
        'RED' => 'RedOS',
        'REV' => 'Revenge OS',
        'RIS' => 'risingOS',
        'ROS' => 'RISC OS',
        'ROC' => 'Rocky Linux',
        'ROK' => 'Roku OS',
        'RSO' => 'Rosa',
        'ROU' => 'RouterOS',
        'REM' => 'Remix OS',
        'RRS' => 'Resurrection Remix OS',
        'REX' => 'REX',
        'RZD' => 'RazoDroiD',
        'RXT' => 'RTOS & Next',
        'SAB' => 'Sabayon',
        'SSE' => 'SUSE',
        'SAF' => 'Sailfish OS',
        'SCI' => 'Scientific Linux',
        'SEE' => 'SeewoOS',
        'SER' => 'SerenityOS',
        'SIR' => 'Sirin OS',
        'SLW' => 'Slackware',
        'SOS' => 'Solaris',
        'SBL' => 'Star-Blade OS',
        'SYL' => 'Syllable',
        'SYM' => 'Symbian',
        'SYS' => 'Symbian OS',
        'S40' => 'Symbian OS Series 40',
        'S60' => 'Symbian OS Series 60',
        'SY3' => 'Symbian^3',
        'TEN' => 'TencentOS',
        'TDX' => 'ThreadX',
        'TIZ' => 'Tizen',
        'TIV' => 'TiVo OS',
        'TOS' => 'TmaxOS',
        'TUR' => 'Turbolinux',
        'UBT' => 'Ubuntu',
        'ULT' => 'ULTRIX',
        'UOS' => 'UOS',
        'VID' => 'VIDAA',
        'VIZ' => 'ViziOS',
        'WAS' => 'watchOS',
        'WER' => 'Wear OS',
        'WTV' => 'WebTV',
        'WHS' => 'Whale OS',
        'WIN' => 'Windows',
        'WCE' => 'Windows CE',
        'WIO' => 'Windows IoT',
        'WMO' => 'Windows Mobile',
        'WPH' => 'Windows Phone',
        'WRT' => 'Windows RT',
        'WPO' => 'WoPhone',
        'XBX' => 'Xbox',
        'XBT' => 'Xubuntu',
        'YNS' => 'YunOS',
        'ZEN' => 'Zenwalk',
        'ZOR' => 'ZorinOS',
        'IOS' => 'iOS',
        'POS' => 'palmOS',
        'WEB' => 'Webian',
        'WOS' => 'webOS'
      }.freeze

      DOWNCASED_OPERATING_SYSTEMS = OPERATING_SYSTEMS.each_with_object({}) do |(short, long), h|
        h[long.downcase] = short
      end.freeze

      OS_FAMILIES = {
        'Android' => %w[
          AND CYN FIR REM RZD MLD MCD YNS GRI HAR
          ADR CLR BOS REV LEN SIR RRS WER PIC ARM
          HEL BYI RIS PUF LEA MET
        ],
        'AmigaOS' => %w[AMG MOR ARO],
        'BlackBerry' => %w[BLB QNX],
        'Brew' => ['BMP'],
        'BeOS' => %w[BEO HAI],
        'Chrome OS' => %w[COS CRS FYD SEE],
        'Firefox OS' => %w[FOS KOS],
        'Gaming Console' => %w[WII PS3],
        'Google TV' => ['GTV'],
        'IBM' => ['OS2'],
        'iOS' => %w[IOS ATV WAS IPA],
        'RISC OS' => ['ROS'],
        'GNU/Linux' => %w[
          LIN ARL DEB KNO MIN UBT KBT XBT LBT FED
          RHT VLN MDR GNT SAB SLW SSE CES BTR SAF
          ORD TOS RSO DEE FRE MAG FEN CAI PCL HAS
          LOS DVK ROK OWR OTV KTV PUR PLA FUC PAR
          FOR MON KAN ZEN LND LNS CHN AMZ TEN CST
          NOV ROU ZOR RED KAL ORA VID TIV BSN RAS
          UOS PIO FRI LIR WEB SER ASP AOS LOO EUL
          SCI ALP CLO ROC OVZ PVE RST EZX GNS JOL
          TUR QTP WPO PAN VIZ AZU COL
        ],
        'Mac' => ['MAC'],
        'Mobile Gaming Console' => %w[PSP NDS XBX],
        'OpenVMS' => ['OVS'],
        'Real-time OS' => %w[MTK TDX MRE JME REX RXT],
        'Other Mobile' => %w[WOS POS SBA TIZ SMG MAE LUN GEO],
        'Symbian' => %w[SYM SYS SY3 S60 S40],
        'Unix' => %w[
          SOS AIX HPX BSD NBS OBS DFB SYL IRI T64
          INF ELE GNX ULT NWS NXT SBL
        ],
        'WebTV' => ['WTV'],
        'Windows' => ['WIN'],
        'Windows Mobile' => %w[WPH WMO WCE WRT WIO KIN],
        'Other Smart TV' => ['WHS']
      }.freeze

      FAMILY_TO_OS = OS_FAMILIES.each_with_object({}) do |(family, oss), h|
        oss.each { |os| h[os] = family }
      end.freeze

      # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/OperatingSystem.php#L376
      def short_os_data(name)
        short = DOWNCASED_OPERATING_SYSTEMS.fetch(name.downcase, 'UNK')
        name = OPERATING_SYSTEMS[short]
        [short, name]
      end

      # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/OperatingSystem.php#L687
      def parse_platform
        arch = @client_hints&.architecture&.downcase

        if arch
          return 'ARM' if arch.include?('arm')
          return 'LoongArch64' if arch.include?('loongarch64')
          return 'MIPS' if arch.include?('mips')
          return 'SuperH' if arch.include?('sh4')
          return 'SPARC64' if arch.include?('sparc64')
          if arch.include?('x64') || (arch.include?('x86') && @client_hints.bitness == '64')
            return 'x64'
          end

          return 'x86' if arch.include?('x86')

        end

        if match_user_agent('arm[ _;)ev]|.*arm$|.*arm64|aarch64|Apple ?TV|Watch ?OS|Watch1,[12]')
          return 'ARM'
        end

        return 'LoongArch64' if match_user_agent('loongarch64')
        return 'MIPS' if match_user_agent('mips')
        return 'SuperH' if match_user_agent('sh4')
        return 'SPARC64' if match_user_agent('sparc64')
        return 'SPARC64' if match_user_agent('sparc64')

        if match_user_agent('64-?bit|WOW64|(?:Intel)?x64|WINDOWS_64|win64|.*amd64|.*x86_?64')
          return 'x64'
        end

        'x86' if match_user_agent('.*32bit|.*win32|(?:i[0-9]|x)86|i86pc')
      end

      # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/OperatingSystem.php#L582
      def parse_os_from_client_hints
        name = ''
        short = ''
        version = ''
        hint_name = @client_hints&.operating_system

        if hint_name
          OPERATING_SYSTEMS.each do |os_short, os_name|
            next unless fuzzy_compare(hint_name, os_name)

            name = os_name
            short = os_short
            break
          end

          version = @client_hints.operating_system_version

          if name == 'Windows'
            major_version = (version.split('.', 1)[0] || 0).to_i
            minor_version = (version.split('.', 2)[1] || 0).to_i

            if major_version.zero?
              minor_mapping = { 1 => '7', 2 => '8', 3 => '8.1' }
              version = minor_mapping[minor_version] || version
            elsif major_version > 0 && major_version < 11
              version = '10'
            elsif major_version > 10
              version = '11'
            end

            # On Windows, version 0.0.0 can be either 7, 8 or 8.1, so we return 0.0.0
            version = '' if name != 'Windows' && version != '0.0.0' && version.to_i.zero?
          end
        end

        {
          name: name,
          short_name: short,
          version: build_version(version, [])
        }
      end

      # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/OperatingSystem.php#L634
      def parse_os_from_user_agent
        name = ''
        version = ''
        short = ''
        matches = nil

        os_regex = regexes.detect do |regex|
          matches = match_user_agent(regex['regex'])
        end

        if matches
          name = build_by_match(os_regex['name'], matches)
          short, name = short_os_data(name)
          version = os_regex.key?('version') ? build_version(os_regex['version'], matches) : ''

          os_regex.fetch('versions', []).each do |regex|
            matches = match_user_agent(regex['regex'])
            next unless matches

            if regex.key?('name')
              name = build_by_match(regex['name'], matches)
              short, name = short_os_data(name)
            end

            version = build_version(regex['version'], matches) if regex.key?('version')
          end
        end

        {
          'name' => name,
          'short_name' => short,
          'version' => version
        }
      end

      def os_family(os_label)
        FAMILY_TO_OS[os_label]
      end
    end
  end
end
