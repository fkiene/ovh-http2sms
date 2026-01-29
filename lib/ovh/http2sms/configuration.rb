# frozen_string_literal: true

module Ovh
  module Http2sms
    # Configuration class for OVH HTTP2SMS gem
    #
    # @example Block configuration
    #   Ovh::Http2sms.configure do |config|
    #     config.account = "sms-xx11111-1"
    #     config.login = "user"
    #     config.password = "secret"
    #   end
    #
    # @example Environment variables
    #   # Set OVH_SMS_ACCOUNT, OVH_SMS_LOGIN, OVH_SMS_PASSWORD
    #   Ovh::Http2sms.deliver(to: "33601020304", message: "Hello!")
    #
    class Configuration
      # @return [String, nil] SMS account identifier (ex: sms-xx11111-1)
      attr_accessor :account

      # @return [String, nil] SMS user login
      attr_accessor :login

      # @return [String, nil] SMS user password
      attr_accessor :password

      # @return [String, nil] Default sender name
      attr_accessor :default_sender

      # @return [String] Default response content type
      attr_accessor :default_content_type

      # @return [Integer] HTTP request timeout in seconds
      attr_accessor :timeout

      # @return [Logger, nil] Optional logger for debugging
      attr_accessor :logger

      # @return [String] Default country code for phone number formatting
      attr_accessor :default_country_code

      # @return [Boolean] Whether to raise errors on message length violations
      attr_accessor :raise_on_length_error

      # @return [String] API endpoint URL
      attr_accessor :api_endpoint

      # Environment variable prefix
      ENV_PREFIX = "OVH_SMS_"

      # Default values
      DEFAULTS = {
        default_content_type: "application/json",
        timeout: 15,
        default_country_code: "33",
        raise_on_length_error: true,
        api_endpoint: "https://www.ovh.com/cgi-bin/sms/http2sms.cgi"
      }.freeze

      def initialize
        reset!
      end

      # Reset configuration to defaults and environment variables
      #
      # @return [void]
      def reset!
        # Set defaults
        DEFAULTS.each do |key, value|
          send("#{key}=", value)
        end

        # Clear credentials
        self.account = nil
        self.login = nil
        self.password = nil
        self.default_sender = nil
        self.logger = nil

        # Load from environment variables
        load_from_env
      end

      # Check if the configuration is valid for making API requests
      #
      # @return [Boolean] true if required fields are present
      def valid?
        !account.nil? && !account.empty? &&
          !login.nil? && !login.empty? &&
          !password.nil? && !password.empty?
      end

      # Validate configuration and raise error if invalid
      #
      # @raise [ConfigurationError] if configuration is invalid
      # @return [void]
      def validate!
        missing = find_missing_credentials
        return if missing.empty?

        raise ConfigurationError, build_validation_error_message(missing)
      end

      def find_missing_credentials
        missing = []
        missing << "account" if blank?(account)
        missing << "login" if blank?(login)
        missing << "password" if blank?(password)
        missing
      end

      def blank?(value)
        value.nil? || value.empty?
      end

      def build_validation_error_message(missing)
        env_vars = missing.map { |m| "#{ENV_PREFIX}#{m.upcase}" }.join(", ")
        "Missing required configuration: #{missing.join(", ")}. " \
          "Set via Ovh::Http2sms.configure block or environment variables (#{env_vars})"
      end

      private

      def load_from_env
        self.account ||= ENV.fetch("#{ENV_PREFIX}ACCOUNT", nil)
        self.login ||= ENV.fetch("#{ENV_PREFIX}LOGIN", nil)
        self.password ||= ENV.fetch("#{ENV_PREFIX}PASSWORD", nil)
        self.default_sender ||= ENV.fetch("#{ENV_PREFIX}DEFAULT_SENDER", nil)
        self.default_content_type = ENV.fetch("#{ENV_PREFIX}DEFAULT_CONTENT_TYPE", default_content_type)
        self.default_country_code = ENV.fetch("#{ENV_PREFIX}DEFAULT_COUNTRY_CODE", default_country_code)

        env_timeout = ENV.fetch("#{ENV_PREFIX}TIMEOUT", nil)
        self.timeout = env_timeout.to_i if env_timeout

        env_raise_on_length = ENV.fetch("#{ENV_PREFIX}RAISE_ON_LENGTH_ERROR", nil)
        self.raise_on_length_error = env_raise_on_length != "false" if env_raise_on_length
      end
    end
  end
end
