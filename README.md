# DeviceDetector

[![CI](https://github.com/podigee/device_detector/workflows/CI/badge.svg)](https://github.com/podigee/device_detector/actions)

DeviceDetector is a precise and fast user agent parser and device detector written in Ruby, backed by the largest and most up-to-date user agent database.

DeviceDetector will parse any user agent and detect the browser, operating system, device used (desktop, tablet, mobile, tv, cars, console, etc.), brand and model. DeviceDetector detects thousands of user agent strings, even from rare and obscure browsers and devices.

The DeviceDetector is optimized for speed of detection, by providing optimized code and in-memory caching.

DeviceDetector is funded by the owners of [Podigee the podcast hosting, analytics & monetization SaaS for podcasters big and small.](https://www.podigee.com) and actively maintained by the development team.

This project originated as a Ruby port of the Universal Device Detection library written and maintained by Matomo Analytics.
You can find the original code here: [https://github.com/matomo-org/device-detector](https://github.com/matomo-org/device-detector).

## Disclaimer

This port does not aspire to be a one-to-one copy from the original code, but rather an adaptation for the Ruby language.

Still, our goal is to use the original, unchanged regex yaml files for user agent detection provided by the upstream version, in order to mutually benefit from updates and pull request to both the original and the ported versions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'device_detector'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install device_detector

## Usage

```ruby
user_agent = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36'
client = DeviceDetector.new(user_agent)

client.name # => 'Chrome'
client.full_version # => '30.0.1599.69'

client.os_name # => 'Windows'
client.os_full_version # => '8'

# For many devices, you can also query the device name (usually the model name)
client.device_name # => 'iPhone 5'
# Device types can be one of the following: desktop, smartphone, tablet,
# feature phone, console, tv, car browser, smart display, camera,
# portable media player, phablet, smart speaker, wearable, peripheral
client.device_type # => 'smartphone'
```

`DeviceDetector` will return `nil` on all attributes, if the `user_agent` is unknown.
You can make a check to ensure the client has been detected:

You can also re-use an instance of `DeviceDetector` by using `#use`, like in the following usage pattern:

```ruby
client = DeviceDetector.new

# ... later in the code
user_agent_list.each do |user_agent|
    client.use(user_agent, headers)

    if client.bot?
        # do something with it
    end
end

```

```ruby
client.known? # => will return false if user_agent is unknown
```

### Using Client hint

Optionally `DeviceDetector` is using the content of `Sec-CH-UA` stored in the headers to improve the accuracy of the detection :

```ruby
user_agent = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36'
headers = {"Sec-CH-UA"=>'"Chromium";v="106", "Brave";v="106", "Not;A=Brand";v="99"'}
client = DeviceDetector.new(user_agent, headers)

client.name # => 'Brave'
```

Same goes with `http-x-requested-with`/`x-requested-with` :

```ruby
user_agent = 'Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36'
headers = {"http-x-requested-with"=>"org.mozilla.focus"}
client = DeviceDetector.new(user_agent, headers)

client.name # => 'Firefox Focus'
```

### Memory cache

`DeviceDetector` will cache up 15,000 user agent strings to boost parsing performance.
You can tune the amount of keys that will get saved in the cache. You have to call this code **before** you initialize the Detector.

```ruby
DeviceDetector.configure do |config|
  config.max_cache_keys = 5_000 # increment this if you have enough RAM, proceed with care
end
```

If you have a Rails application, you can create an initializer, for example `config/initializers/device_detector.rb`.

## Benchmarks

We have measured the parsing speed of almost 550,000 non-unique user agent strings and compared the speed of DeviceDetector with the two most popular user agent parsers in the Ruby community, Browser and UserAgent.

### Testing machine specs

- MacBook M3 Pro
- 36 GB Memory

### Gem versions

- DeviceDetector - 0.5.1
- Browser - 5.3.1
- UserAgent - 0.16.11

### Code

```ruby
require 'device_detector'
require 'browser'
require 'useragent'
require 'benchmark'

user_agent_strings = File.read('./tmp/user-agents.txt').split("\n")

## Benchmarks

Benchmark.bm(2) do |x|
  x.report('device_detector') {
    user_agent_strings.each { |uas| DeviceDetector.new(uas).name }
  }
  x.report('browser') {
    user_agent_strings.each { |uas| Browser.new(ua: uas).name }
  }
  x.report('useragent') {
    user_agent_strings.each { |uas| ::UserAgent.parse(uas).browser }
  }
end
```

### Results

```
                     user     system      total        real
device_detector 17.252658   0.118754  17.371412 ( 17.371477)
browser          7.064591   0.014122   7.078713 (  7.078903)
useragent        5.777268   0.049343   5.826611 (  5.826663)

```

When re-using a `DeviceDetector` instance, using `#use`, the results show:

```
                     user     system      total        real
device_detector  5.640887   0.029967   5.670854 (  5.670738)
browser          6.753294   0.010817   6.764111 (  6.763942)
useragent        5.503468   0.043383   5.546851 (  5.547026)
```

## Detectable clients, bots and devices

We follow the Matomo Device Detector releases, so you can check the list of detected clients, bots and devices in [Matomo's Repository](https://github.com/matomo-org/device-detector/?tab=readme-ov-file#what-device-detector-is-able-to-detect)

## Maintainers

- The Podigee Team: https://podigee.com

## Contributors

Thanks a lot to the following contributors:

- Peter Gao: https://github.com/peteygao
- Stefan Kaes: https://github.com/skaes
- Dennis Wu: https://github.com/dnswus
- Steve Robinson: https://github.com/steverob
- Mark Dodwell: https://github.com/mkdynamic
- Sean Dilda: https://github.com/seandilda
- Stephan Leibelt: https://github.com/sliminas
- Rafael Porras Lucena: https://github.com/rporrasluc
- Anton Rieder: https://github.com/aried3r
- Bruno Arueira: https://github.com/brunoarueira
- Nicolas Rodriguez: https://github.com/n-rodriguez
- Igor Drozdov: https://github.com/igor-drozdov
- Axeleander: https://github.com/Axeleander
- Igor Pstyga: https://github.com/opti

## Contributing

1. Open an issue and explain your feature request or bug before writing any code (this can save a lot of time, both the contributor and the maintainers!)
2. Fork the project (https://github.com/podigee/device_detector/fork)
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request (compare with develop)
7. When adding new data to the yaml files, please make sure to open a PR in the original project, as well (https://github.com/matomo-org/device-detector)
