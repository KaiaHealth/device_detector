# frozen_string_literal: true

describe DeviceDetector::Parser::Bot do
  fixture_dir = File.expand_path('../../fixtures/detector', __dir__)
  fixture_files = Dir["#{fixture_dir}/bots.yml"]
  fixture_files.each do |fixture_file|
    describe File.basename(fixture_file) do
      fixtures = YAML.load_file(fixture_file)

      fixtures.each do |f|
        user_agent = f['user_agent']
        headers = f['headers']

        device = DeviceDetector.new(user_agent, headers)

        describe user_agent do
          it 'should be a bot' do
            expect(device.bot?).to eq(true)
          end

          it 'should have the expected name' do
            expect(device.bot_name).to eq(f['bot']['name'])
          end
        end
      end
    end
  end
end
