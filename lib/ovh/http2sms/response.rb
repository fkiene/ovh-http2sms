# frozen_string_literal: true

require "json"

module Ovh
  module Http2sms
    # Response object for OVH HTTP2SMS API responses
    #
    # Parses responses in all supported formats: JSON, XML, HTML, and text/plain.
    # Provides a unified interface for accessing response data.
    #
    # @example Successful response
    #   response = Response.parse(body, content_type: "application/json")
    #   response.success? # => true
    #   response.sms_ids # => ["123456789"]
    #   response.credits_remaining # => 1987.0
    #
    # @example Error response
    #   response = Response.parse(body, content_type: "application/json")
    #   response.success? # => false
    #   response.error_message # => "Missing message"
    class Response
      # @return [Integer] API status code (100, 101 = success; 201, 202, 401 = error)
      attr_reader :status

      # @return [Float, nil] Remaining SMS credits
      attr_reader :credits_remaining

      # @return [Array<String>] SMS IDs for sent messages
      attr_reader :sms_ids

      # @return [String, nil] Error message if request failed
      attr_reader :error_message

      # @return [String] Raw response body
      attr_reader :raw_response

      # @return [String] Content type of the response
      attr_reader :content_type

      # Success status codes
      SUCCESS_CODES = [100, 101].freeze

      # Error status codes
      ERROR_CODES = {
        201 => :missing_parameter,
        202 => :invalid_parameter,
        241 => :sender_not_found,
        401 => :authentication_error
      }.freeze

      # rubocop:disable Metrics/ParameterLists
      def initialize(status:, credits_remaining: nil, sms_ids: [], error_message: nil,
                     raw_response: nil, content_type: nil)
        # rubocop:enable Metrics/ParameterLists
        @status = status
        @credits_remaining = credits_remaining
        @sms_ids = Array(sms_ids).map(&:to_s)
        @error_message = error_message
        @raw_response = raw_response
        @content_type = content_type
      end

      # Check if the request was successful
      #
      # @return [Boolean] true if status code indicates success (100 or 101)
      def success?
        SUCCESS_CODES.include?(status)
      end

      # Check if the request failed
      #
      # @return [Boolean] true if status code indicates failure
      def failure?
        !success?
      end

      # Get the error type based on status code
      #
      # @return [Symbol, nil] Error type (:missing_parameter, :invalid_parameter, :authentication_error)
      def error_type
        ERROR_CODES[status]
      end

      # Parse a raw API response
      #
      # @param body [String] Raw response body
      # @param content_type [String] Content-Type header value
      # @return [Response] Parsed response object
      #
      # @example Parse JSON response
      #   Response.parse('{"status":100,"creditLeft":"1987","SmsIds":["123"]}', content_type: "application/json")
      def self.parse(body, content_type: "text/plain")
        parser = ResponseParser.new(body, content_type)
        parser.parse
      end
    end

    # Internal parser for different response formats
    # @api private
    class ResponseParser
      def initialize(body, content_type)
        @body = body.to_s
        @content_type = content_type.to_s.downcase
      end

      def parse
        case @content_type
        when /json/
          parse_json
        when /xml/
          parse_xml
        when /html/
          parse_html
        else
          parse_plain
        end
      rescue StandardError => e
        # If parsing fails, raise a specific error
        raise ResponseParseError.new(
          "Failed to parse API response: #{e.message}",
          content_type: @content_type,
          raw_response: @body
        )
      end

      private

      def parse_json
        data = JSON.parse(@body)

        Response.new(
          status: data["status"].to_i,
          credits_remaining: parse_credits(data["creditLeft"]),
          sms_ids: data["SmsIds"] || data["smsIds"] || [],
          error_message: data["message"],
          raw_response: @body,
          content_type: @content_type
        )
      end

      def parse_xml
        # Simple XML parsing without additional dependencies
        status = extract_xml_value("status").to_i
        credits = parse_credits(extract_xml_value("creditLeft"))
        message = extract_xml_value("message")
        sms_ids = extract_xml_sms_ids

        Response.new(
          status: status,
          credits_remaining: credits,
          sms_ids: sms_ids,
          error_message: message,
          raw_response: @body,
          content_type: @content_type
        )
      end

      def parse_html
        # HTML format: OK/KO<br>credits/message<br>sms_id<br>
        lines = extract_html_lines

        parse_text_lines(lines)
      end

      def parse_plain
        # Text/plain format:
        # OK\n1987\n123456789
        # or
        # KO\nError message
        lines = @body.strip.split(/\r?\n/)

        parse_text_lines(lines)
      end

      def parse_text_lines(lines)
        return empty_response if lines.empty?

        status_line = lines[0].to_s.strip.upcase

        if status_line == "OK"
          parse_success_lines(lines)
        else
          parse_error_lines(lines, status_line)
        end
      end

      def parse_success_lines(lines)
        credits = lines[1] ? parse_credits(lines[1]) : nil
        sms_ids = lines[2..].map(&:strip).reject(&:empty?)

        Response.new(
          status: 100,
          credits_remaining: credits,
          sms_ids: sms_ids,
          raw_response: @body,
          content_type: @content_type
        )
      end

      def parse_error_lines(lines, status_line)
        # Status might be numeric (like in some error cases) or "KO"
        status = status_line == "KO" ? 0 : status_line.to_i
        error_message = lines[1..].join("\n").strip

        # Try to extract status code from message if present
        if error_message =~ /\A(\d{3})\s/
          status = ::Regexp.last_match(1).to_i
          error_message = error_message.sub(/\A\d{3}\s*/, "")
        end

        Response.new(
          status: status,
          error_message: error_message.empty? ? "Unknown error" : error_message,
          raw_response: @body,
          content_type: @content_type
        )
      end

      def empty_response
        Response.new(
          status: 0,
          error_message: "Empty response",
          raw_response: @body,
          content_type: @content_type
        )
      end

      def extract_xml_value(tag)
        match = @body.match(%r{<#{tag}>(.*?)</#{tag}>}i)
        match ? match[1] : nil
      end

      def extract_xml_sms_ids
        # Handle both <smsIds><smsId>...</smsId></smsIds> format
        ids = []
        @body.scan(%r{<smsId>(.*?)</smsId>}i) { |match| ids << match[0] }
        ids
      end

      def extract_html_lines
        # Extract content between <BODY> tags and split by <br>
        body_match = @body.match(%r{<BODY>(.*?)</BODY>}im)
        return [] unless body_match

        body_content = body_match[1]
        body_content.split(%r{<br\s*/?>}).map(&:strip).reject(&:empty?)
      end

      def parse_credits(value)
        return nil if value.nil? || value.to_s.empty?

        Float(value)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
