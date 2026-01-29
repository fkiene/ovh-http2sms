# frozen_string_literal: true

require "rails/generators/base"

module Ovh
  module Http2sms
    module Generators
      # Rails generator for OVH HTTP2SMS initializer
      #
      # @example
      #   rails g ovh:http2sms:install
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        desc "Creates an OVH HTTP2SMS initializer file"

        # Create the initializer file
        def create_initializer_file
          template "initializer.rb", "config/initializers/ovh_http2sms.rb"
        end

        # Show instructions after installation
        def show_instructions
          say ""
          say "OVH HTTP2SMS initializer created!", :green
          say ""
          say "Next steps:"
          say "  1. Edit config/initializers/ovh_http2sms.rb with your credentials"
          say "  2. Or set environment variables: OVH_SMS_ACCOUNT, OVH_SMS_LOGIN, OVH_SMS_PASSWORD"
          say "  3. Or use Rails credentials: rails credentials:edit"
          say ""
          say "Example credentials structure:"
          say "  ovh_sms:"
          say "    account: sms-xx11111-1"
          say "    login: your_login"
          say "    password: your_password"
          say ""
        end
      end
    end
  end
end
