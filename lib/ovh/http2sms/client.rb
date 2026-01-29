# frozen_string_literal: true

require "faraday"
require "uri"

module Ovh
  module Http2sms
    # HTTP client for OVH HTTP2SMS API
    #
    # Handles building requests, making HTTP calls, and processing responses.
    # Thread-safe for use in multi-threaded environments.
    #
    # @example Direct usage
    #   client = Client.new(account: "sms-xx111-1", login: "user", password: "pass")
    #   response = client.deliver(to: "33601020304", message: "Hello!")
    class Client
      # @return [Configuration] Client configuration
      attr_reader :config

      # Initialize a new client
      #
      # @param options [Hash] Configuration options (overrides global config)
      # @option options [String] :account SMS account identifier
      # @option options [String] :login SMS user login
      # @option options [String] :password SMS user password
      # @option options [String] :default_sender Default sender name
      # @option options [String] :default_content_type Response format
      # @option options [Integer] :timeout HTTP timeout in seconds
      # @option options [Logger] :logger Logger for debugging
      # @option options [String] :default_country_code Default country code
      def initialize(**options)
        @config = build_config(options)
      end

      # Send an SMS message
      #
      # @param to [String, Array<String>] Recipient phone number(s)
      # @param message [String] SMS content
      # @param sender [String, nil] Sender name (uses default if nil)
      # @param deferred [Time, String, nil] Scheduled send time
      # @param tag [String, nil] Custom tag for tracking (max 20 chars)
      # @param sms_class [Integer, nil] SMS class (0-3)
      # @param sms_coding [Integer, nil] Encoding (1=7bit, 2=Unicode)
      # @param no_stop [Boolean] Set to true for non-commercial SMS
      # @param sender_for_response [Boolean] Enable reply capability
      # @param content_type [String, nil] Response format (uses default if nil)
      # @return [Response] Parsed response object
      # @raise [ConfigurationError] if configuration is invalid
      # @raise [ValidationError] if parameters are invalid
      # @raise [NetworkError] if HTTP request fails
      # @raise [AuthenticationError] if IP is not authorized
      # @raise [MissingParameterError] if required parameter is missing
      # @raise [InvalidParameterError] if parameter value is invalid
      #
      # @example Simple send
      #   client.deliver(to: "33601020304", message: "Hello!")
      #
      # @example With options
      #   client.deliver(
      #     to: ["33601020304", "33602030405"],
      #     message: "Meeting at 3pm",
      #     sender: "MyCompany",
      #     deferred: 1.hour.from_now,
      #     tag: "reminders"
      #   )
      # rubocop:disable Metrics/ParameterLists
      def deliver(to:, message:, sender: nil, deferred: nil, tag: nil,
                  sms_class: nil, sms_coding: nil, no_stop: false,
                  sender_for_response: false, content_type: nil)
        # rubocop:enable Metrics/ParameterLists
        @config.validate!

        params = build_delivery_params(to, message, sender, deferred, tag, sms_class,
                                       sms_coding, no_stop, sender_for_response)
        Validators.validate!(params)

        query_params = build_query_params(params, content_type)
        execute_request(query_params, content_type)
      end

      ERROR_HANDLERS = {
        401 => AuthenticationError,
        201 => MissingParameterError,
        202 => InvalidParameterError,
        241 => SenderNotFoundError
      }.freeze
      private_constant :ERROR_HANDLERS

      private

      # rubocop:disable Metrics/ParameterLists
      def build_delivery_params(to, message, sender, deferred, tag, sms_class,
                                sms_coding, no_stop, sender_for_response)
        # rubocop:enable Metrics/ParameterLists
        {
          to: to, message: message, sender: sender, deferred: deferred, tag: tag,
          sms_class: sms_class, sms_coding: sms_coding, no_stop: no_stop,
          sender_for_response: sender_for_response
        }
      end

      def build_config(options)
        return Ovh::Http2sms.configuration.dup if options.empty?

        Configuration.new.tap { |config| merge_config_options(config, options) }
      end

      def merge_config_options(config, options)
        global = Ovh::Http2sms.configuration
        merge_credentials(config, options, global)
        merge_defaults(config, options, global)
      end

      def merge_credentials(config, options, global)
        config.account = options[:account] || global.account
        config.login = options[:login] || global.login
        config.password = options[:password] || global.password
      end

      def merge_defaults(config, options, global)
        config.default_sender = options[:default_sender] || global.default_sender
        config.default_content_type = options[:default_content_type] || global.default_content_type
        config.timeout = options[:timeout] || global.timeout
        config.logger = options[:logger] || global.logger
        config.default_country_code = options[:default_country_code] || global.default_country_code
        config.raise_on_length_error = options.fetch(:raise_on_length_error, global.raise_on_length_error)
        config.api_endpoint = options[:api_endpoint] || global.api_endpoint
      end

      def build_query_params(params, content_type)
        query = build_base_params(params)
        add_sender_params(query, params)
        add_optional_params(query, params)
        query[:contentType] = content_type || @config.default_content_type
        query
      end

      def build_base_params(params)
        {
          account: @config.account,
          login: @config.login,
          password: @config.password,
          to: format_recipients(params[:to]),
          message: encode_message(params[:message])
        }
      end

      def add_sender_params(query, params)
        if params[:sender_for_response]
          query[:from] = ""
          query[:senderForResponse] = "1"
        else
          sender = params[:sender] || @config.default_sender
          query[:from] = sender if sender
        end
      end

      def add_optional_params(query, params)
        query[:deferred] = format_deferred(params[:deferred]) if params[:deferred]
        query[:tag] = params[:tag] if params[:tag]
        query[:class] = params[:sms_class].to_s if params[:sms_class]
        query[:smsCoding] = params[:sms_coding].to_s if params[:sms_coding]
        query[:noStop] = "1" if params[:no_stop]
      end

      def format_recipients(to)
        phones = PhoneNumber.format_multiple(to, country_code: @config.default_country_code)
        phones.join(",")
      end

      def encode_message(message)
        # URL encoding is handled by Faraday, but we need to handle line breaks
        # OVH uses %0d for line breaks in the URL
        message.to_s.gsub("\n", "%0d").gsub("\r", "")
      end

      def format_deferred(deferred)
        if deferred.respond_to?(:strftime)
          # Format Time/DateTime as hhmmddMMYYYY
          deferred.strftime("%H%M%d%m%Y")
        else
          deferred.to_s
        end
      end

      def execute_request(query_params, content_type)
        log_request(query_params)
        run_before_request_callbacks(query_params)

        response = make_http_request(query_params)
        parsed_response = parse_response(response, content_type)

        log_response(parsed_response)
        run_after_request_callbacks(parsed_response)

        if parsed_response.failure?
          run_on_failure_callbacks(parsed_response)
          handle_error_response(parsed_response)
        else
          run_on_success_callbacks(parsed_response)
        end

        parsed_response
      rescue Faraday::Error => e
        raise NetworkError.new(
          "HTTP request failed: #{e.message}",
          original_error: e
        )
      end

      def make_http_request(query_params)
        connection.get do |req|
          req.params = query_params
        end
      end

      def connection
        @connection ||= Faraday.new(url: @config.api_endpoint) do |faraday|
          faraday.options.timeout = @config.timeout
          faraday.options.open_timeout = @config.timeout
          faraday.adapter Faraday.default_adapter
        end
      end

      def parse_response(http_response, content_type)
        Response.parse(
          http_response.body,
          content_type: content_type || @config.default_content_type
        )
      end

      def handle_error_response(response)
        error_class = ERROR_HANDLERS[response.status]
        return unless error_class

        message = response.error_message || default_error_message(response.status)
        raise error_class.new(message, raw_response: response.raw_response)
      end

      def default_error_message(status)
        status == 401 ? "IP not authorized" : nil
      end

      def log_request(params)
        return unless @config.logger

        safe_params = params.dup
        safe_params[:password] = "[FILTERED]"
        @config.logger.debug("[OVH HTTP2SMS] Request: #{safe_params}")
      end

      def log_response(response)
        return unless @config.logger

        @config.logger.debug(
          "[OVH HTTP2SMS] Response: status=#{response.status} success=#{response.success?}"
        )
      end

      def run_before_request_callbacks(params)
        safe_params = params.dup
        safe_params[:password] = "[FILTERED]"
        @config.before_request_callbacks.each { |callback| callback.call(safe_params) }
      end

      def run_after_request_callbacks(response)
        @config.after_request_callbacks.each { |callback| callback.call(response) }
      end

      def run_on_success_callbacks(response)
        @config.on_success_callbacks.each { |callback| callback.call(response) }
      end

      def run_on_failure_callbacks(response)
        @config.on_failure_callbacks.each { |callback| callback.call(response) }
      end
    end
  end
end
