# frozen_string_literal: true

require_relative "http2sms/version"
require_relative "http2sms/errors"
require_relative "http2sms/configuration"
require_relative "http2sms/gsm_encoding"
require_relative "http2sms/phone_number"
require_relative "http2sms/response"
require_relative "http2sms/validators"
require_relative "http2sms/client"

# Load Rails integration if Rails is defined
require_relative "http2sms/railtie" if defined?(Rails::Railtie)

module Ovh
  # OVH HTTP2SMS Ruby client
  #
  # Send SMS via OVH's http2sms API using simple HTTP GET requests.
  # Supports single and bulk sending, scheduled messages, GSM/Unicode encoding,
  # phone number formatting, and Rails integration.
  #
  # @example Configuration
  #   Ovh::Http2sms.configure do |config|
  #     config.account = "sms-xx11111-1"
  #     config.login = "user"
  #     config.password = "secret"
  #   end
  #
  # @example Simple send
  #   response = Ovh::Http2sms.deliver(to: "33601020304", message: "Hello!")
  #   response.success? # => true
  #   response.sms_ids # => ["123456789"]
  #
  # @example With options
  #   Ovh::Http2sms.deliver(
  #     to: ["33601020304", "33602030405"],
  #     message: "Meeting reminder",
  #     sender: "MyCompany",
  #     deferred: 1.hour.from_now,
  #     tag: "meeting-reminders"
  #   )
  #
  # @example Check message length
  #   Ovh::Http2sms.message_info("Hello!")
  #   # => { characters: 6, encoding: :gsm, sms_count: 1, remaining: 143 }
  #
  module Http2sms
    class << self
      # @return [Configuration] Current configuration
      attr_writer :configuration

      # Get the current configuration
      #
      # @return [Configuration] Configuration instance
      def configuration
        @configuration ||= Configuration.new
      end

      # Configure the gem
      #
      # @yield [Configuration] Configuration block
      # @return [Configuration] The configuration object
      #
      # @example
      #   Ovh::Http2sms.configure do |config|
      #     config.account = "sms-xx11111-1"
      #     config.login = "user"
      #     config.password = "secret"
      #     config.default_sender = "MyApp"
      #     config.timeout = 30
      #   end
      def configure
        yield(configuration)
        configuration
      end

      # Reset configuration to defaults
      #
      # @return [Configuration] New configuration with defaults
      def reset_configuration!
        @configuration = Configuration.new
      end

      # Send an SMS message using the global configuration
      #
      # @param (see Client#deliver)
      # @return (see Client#deliver)
      # @raise (see Client#deliver)
      #
      # @example
      #   Ovh::Http2sms.deliver(to: "33601020304", message: "Hello!")
      def deliver(**options)
        client.deliver(**options)
      end

      # Get a new client instance with optional configuration overrides
      #
      # @param options [Hash] Configuration options to override
      # @return [Client] New client instance
      #
      # @example Use different credentials
      #   client = Ovh::Http2sms.client(account: "sms-other-1")
      #   client.deliver(to: "33601020304", message: "Hello!")
      def client(**options)
        Client.new(**options)
      end

      # Get message information (character count, encoding, SMS count)
      #
      # @param message [String] Message to analyze
      # @param commercial [Boolean] Whether this is a commercial SMS (default: true)
      # @return [Hash] Message information
      #
      # @example
      #   Ovh::Http2sms.message_info("Hello!")
      #   # => { characters: 6, encoding: :gsm, sms_count: 1, remaining: 143, ... }
      #
      # @example Non-commercial SMS
      #   Ovh::Http2sms.message_info("Hello!", commercial: false)
      #   # => { characters: 6, encoding: :gsm, sms_count: 1, remaining: 154, ... }
      def message_info(message, commercial: true)
        GsmEncoding.message_info(message, commercial: commercial)
      end

      # Check if a message uses only GSM characters
      #
      # @param message [String] Message to check
      # @return [Boolean] true if all characters are GSM compatible
      #
      # @example
      #   Ovh::Http2sms.gsm_compatible?("Hello!") # => true
      #   Ovh::Http2sms.gsm_compatible?("Привет") # => false
      def gsm_compatible?(message)
        GsmEncoding.gsm_compatible?(message)
      end

      # Format a phone number to international format
      #
      # @param phone [String] Phone number in local or international format
      # @param country_code [String] Country code for local numbers (default: from config)
      # @return [String] Phone number in OVH format (00 prefix)
      #
      # @example
      #   Ovh::Http2sms.format_phone("0601020304") # => "0033601020304"
      #   Ovh::Http2sms.format_phone("+33601020304") # => "0033601020304"
      def format_phone(phone, country_code: nil)
        PhoneNumber.format(phone, country_code: country_code)
      end
    end
  end
end
