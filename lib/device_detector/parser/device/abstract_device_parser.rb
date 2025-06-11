# frozen_string_literal: true

class DeviceDetector
  module Parser
    module Device
      module AbstractDeviceParser
        include AbstractParser

        def parser_type
          :device
        end

        # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/Device/AbstractDeviceParser.php#L2255
        def parse
          result_client_hint = parse_client_hints
          @device_model = result_client_hint&.fetch('model', '') || ''

          restore_user_agent_from_client_hints

          return result if @device_model.empty? && user_agent_client_hints_fragment?

          return result if @device_model.empty? && desktop_fragment?

          regex, matches = regexes.detect do |r|
            matches = match_user_agent(r['regex'])
            break r, matches if matches
          end

          brand = regex['brand'] if regex

          if matches.nil? || matches.empty?
            @device_type = result_client_hint['device_type']
            return result_client_hint
          end

          if brand != 'Unknown'
            # TODO: device brand list check
            # https://github.com/matomo-org/device-detector/blob/6.4.5/Parser/Device/AbstractDeviceParser.php#L2287
            @brand = brand
          end

          if regex['device'] && DEVICE_TYPES.key?(regex['device'])
            @device_type = DEVICE_TYPES[regex['device']]
          end

          @model = ''
          @model = build_model(regex['model'], matches) if regex['model']

          if regex['models']
            model_regex, matches = regex['models'].detect do |model_regex|
              matches = match_user_agent(model_regex['regex'])
              break model_regex, matches if matches
            end

            return result unless model_regex

            @model = build_model(model_regex['model'], matches)

            if model_regex['brand'] && DEVICE_BRANDS.key?(model_regex['brand'])
              @brand = model_regex['brand']
            end
            if model_regex['device'] && DEVICE_TYPES.key?(model_regex['device'])
              @device_type = DEVICE_TYPES[model_regex['device']]
            end
          end

          result
        end

        private

        def parse_client_hints
          model = @client_hints&.model
          if model
            form_factors = @client_hints.form_factors
            detected_device_type = form_factors.detect do |form_factor, device_type|
              break device_type if form_factors.include?(form_factor)
            end

            @device_type = detected_device_type
            @model = model
            @brand = ''
            return result
          end

          nil
        end

        def result
          {
            'deviceType' => @device_type,
            'model' => @model,
            'brand' => @brand
          }
        end
      end
    end
  end
end
