# frozen_string_literal: true

module Ovh
  module Http2sms
    # Rails integration for OVH HTTP2SMS
    #
    # Automatically loads generators and sets up Rails-specific defaults.
    class Railtie < Rails::Railtie
      generators do
        require_relative "../../generators/ovh/http2sms/install_generator"
      end

      initializer "ovh_http2sms.set_defaults" do
        # Set Rails logger as default if not already configured
        config.after_initialize do
          if Ovh::Http2sms.configuration.logger.nil? && defined?(Rails.logger)
            Ovh::Http2sms.configuration.logger = Rails.logger
          end
        end
      end
    end
  end
end
