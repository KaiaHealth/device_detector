# frozen_string_literal: true

require_relative '../spec_helper'

describe DeviceDetector do
  fixture_dir = File.expand_path('../fixtures/detector', __dir__)
  fixture_files = Dir["#{fixture_dir}/*.yml"]

  raise 'invalid fixture load path specified' if fixture_files.empty?

  detector = DeviceDetector.new

  fixture_files.each do |fixture_file|
    describe File.basename(fixture_file) do
      fixtures = nil
      begin
        fixtures = YAML.load_file(fixture_file)
      rescue Psych::SyntaxError => e
        raise "Failed to parse #{fixture_file}, reason: #{e}"
      end

      def str_or_nil(string)
        return nil if string.nil?
        return nil if string == ''

        string.to_s
      end

      fixtures.each do |f|
        describe f['user_agent'] do
          it 'should be detected' do
            detector.use(f['user_agent'], f['headers'])

            if f['bot']
              expect(detector.bot?).to eq true
              expect(detector.bot_name).to eq str_or_nil(f['bot']['name'])
              next
            end

            expect(detector.name).to eq str_or_nil(f['client']['name']) if f['client']

            os_family = str_or_nil(f['os_family'])
            if os_family != 'Unknown'
              if os_family.nil?
                expect(detector.os_family).to be_nil
              else
                expect(detector.os_family).to eq(os_family)
              end

              name = str_or_nil(f['os']['name'])
              if name.nil?
                expect(detector.os_name).to be_nil
              else
                expect(detector.os_name).to eq name
              end

              os_version = str_or_nil(f['os']['version'])
              if os_version.nil?
                expect(detector.os_full_version).to be_nil
              else
                expect(detector.os_full_version).to eq os_version
              end
            end

            if f['device']
              expected_type = str_or_nil(f['device']['type'])
              actual_type = detector.device_type

              if expected_type.nil?
                expect(actual_type).to be_nil
              else
                expect(actual_type).to eq expected_type
              end

              model = str_or_nil(f['device']['model'])
              model = model.to_s unless model.nil?

              if model.nil?
                expect(detector.device_name).to be_nil
              else
                expect(detector.device_name).to eq model
              end

              brand = str_or_nil(f['device']['brand'])
              brand = brand.to_s unless brand.nil?
              if brand.nil?
                expect(detector.device_brand).to be_nil
              else
                expect(detector.device_brand).to eq brand
              end
            end
          end
        end
      end
    end
  end
end
