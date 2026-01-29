# frozen_string_literal: true

module Ovh
  module Http2sms
    # Base error class for all OVH HTTP2SMS errors
    class Error < StandardError
      # @return [Integer, nil] API status code if available
      attr_reader :status_code

      # @return [String, nil] Raw API response if available
      attr_reader :raw_response

      def initialize(message = nil, status_code: nil, raw_response: nil)
        @status_code = status_code
        @raw_response = raw_response
        super(message)
      end
    end

    # Raised when configuration is missing or invalid
    #
    # @example
    #   raise ConfigurationError, "Missing required configuration: account"
    class ConfigurationError < Error; end

    # Raised when authentication fails (API status 401)
    #
    # @example
    #   raise AuthenticationError.new("IP not authorized", status_code: 401)
    class AuthenticationError < Error
      def initialize(message = "Authentication failed: IP not authorized", **options)
        super(message, **options.merge(status_code: 401))
      end
    end

    # Raised when a required parameter is missing (API status 201)
    #
    # @example
    #   raise MissingParameterError.new("Missing message")
    class MissingParameterError < Error
      # @return [String, nil] Name of the missing parameter
      attr_reader :parameter

      def initialize(message = "Missing required parameter", parameter: nil, **options)
        @parameter = parameter
        super(message, **options.merge(status_code: 201))
      end
    end

    # Raised when a parameter value is invalid (API status 202)
    #
    # @example
    #   raise InvalidParameterError.new("Invalid tag: is too long", parameter: "tag")
    class InvalidParameterError < Error
      # @return [String, nil] Name of the invalid parameter
      attr_reader :parameter

      def initialize(message = "Invalid parameter", parameter: nil, **options)
        @parameter = parameter
        super(message, **options.merge(status_code: 202))
      end
    end

    # Raised when a network error occurs (timeout, connection failure, etc.)
    #
    # @example
    #   raise NetworkError.new("Connection timed out")
    class NetworkError < Error
      # @return [Exception, nil] Original exception that caused the network error
      attr_reader :original_error

      def initialize(message = "Network error occurred", original_error: nil, **options)
        @original_error = original_error
        super(message, **options)
      end
    end

    # Raised when message length exceeds SMS limits
    #
    # @example
    #   raise MessageLengthError.new("Message exceeds GSM encoding limit", encoding: :gsm, length: 161)
    class MessageLengthError < Error
      # @return [Symbol] Encoding type (:gsm or :unicode)
      attr_reader :encoding

      # @return [Integer] Actual message length
      attr_reader :length

      # @return [Integer] Maximum allowed length
      attr_reader :max_length

      def initialize(message = "Message length error", encoding: nil, length: nil, max_length: nil, **options)
        @encoding = encoding
        @length = length
        @max_length = max_length
        super(message, **options)
      end
    end

    # Raised when phone number format is invalid
    #
    # @example
    #   raise PhoneNumberError.new("Invalid phone number format", phone_number: "abc123")
    class PhoneNumberError < Error
      # @return [String, nil] The invalid phone number
      attr_reader :phone_number

      def initialize(message = "Invalid phone number", phone_number: nil, **options)
        @phone_number = phone_number
        super(message, **options)
      end
    end

    # Raised when validation fails before sending
    #
    # @example
    #   raise ValidationError.new("Tag exceeds maximum length of 20 characters")
    class ValidationError < Error; end

    # Raised when the sender does not exist (API status 241)
    #
    # @example
    #   raise SenderNotFoundError.new("Sender 'MyApp' not found")
    class SenderNotFoundError < Error
      # @return [String, nil] The sender that was not found
      attr_reader :sender

      def initialize(message = "Sender not found", sender: nil, **options)
        @sender = sender
        super(message, **options.merge(status_code: 241))
      end
    end

    # Raised when the API response cannot be parsed
    #
    # @example
    #   raise ResponseParseError.new("Invalid JSON", raw_response: "not json")
    class ResponseParseError < Error
      # @return [String, nil] The content type that failed to parse
      attr_reader :content_type

      def initialize(message = "Failed to parse API response", content_type: nil, **options)
        @content_type = content_type
        super(message, **options)
      end
    end
  end
end
