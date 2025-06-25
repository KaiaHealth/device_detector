# frozen_string_literal: true

require_relative '../spec_helper'

describe DeviceDetector do
  fixture_dir = File.expand_path('../fixtures/device', __dir__)
  fixture_files = Dir["#{fixture_dir}/*.yml"]

  raise 'invalid fixture load path specified' if fixture_files.empty?

  fixture_files.each do |fixture_file|
    describe File.basename(fixture_file) do
      fixtures = YAML.safe_load_file(fixture_file)
      fixtures.each do |f|
        user_agent = f['user_agent']
        headers = f['headers']

        describe user_agent do
          let(:device) do
            DeviceDetector.new(user_agent, headers)
          end

          it 'should be known' do
            expect(device).to be_known
          end

          it 'should have the expected model' do
            expect(device.device_name).to eq(str_or_nil(f['device']['model']))
          end

          it 'should have the expected brand' do
            expect(device.device_brand).to eq(f['device']['brand'])
          end

          it 'should have the expected type' do
            expect(device.device_type).to eq(f['device']['type'])
          end
        end
      end
    end
  end
end
