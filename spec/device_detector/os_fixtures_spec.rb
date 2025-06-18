# frozen_string_literal: true

require_relative '../spec_helper'

describe DeviceDetector do
  fixture_dir = File.expand_path('../fixtures/parser', __dir__)
  fixture_files = Dir["#{fixture_dir}/oss.yml"]

  raise 'invalid fixture load path specified' if fixture_files.empty?

  fixture_files.each do |fixture_file|
    describe File.basename(fixture_file) do
      fixtures = YAML.load_file(fixture_file)
      fixtures.each do |f|
        user_agent = f['user_agent']
        headers = f['headers']

        describe user_agent do
          let(:device) do
            DeviceDetector.new(user_agent, headers)
          end

          it 'should have the expected name' do
            expect(device.os_name).to eq f['os']['name']
          end
        end
      end
    end
  end
end
