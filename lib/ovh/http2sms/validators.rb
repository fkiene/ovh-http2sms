# frozen_string_literal: true

module Ovh
  module Http2sms
    # Validators for SMS parameters
    #
    # Provides validation for all SMS parameters before sending to ensure
    # they meet OVH API requirements.
    module Validators
      # Maximum tag length allowed by OVH API
      MAX_TAG_LENGTH = 20

      # Valid SMS class values
      VALID_SMS_CLASSES = (0..3).to_a.freeze

      # Valid smsCoding values
      VALID_SMS_CODINGS = [1, 2].freeze

      # Deferred date format: hhmmddMMYYYY
      DEFERRED_FORMAT_PATTERN = /\A\d{12}\z/

      class << self
        # Validate all parameters for an SMS delivery
        #
        # @param params [Hash] Parameters to validate
        # @option params [String, Array<String>] :to Recipient phone number(s)
        # @option params [String] :message SMS content
        # @option params [String] :sender Sender name (optional)
        # @option params [Time, String] :deferred Scheduled send time (optional)
        # @option params [String] :tag Custom tag (optional, max 20 chars)
        # @option params [Integer] :sms_class SMS class 0-3 (optional)
        # @option params [Integer] :sms_coding Encoding 1=7bit, 2=Unicode (optional)
        # @option params [Boolean] :no_stop Disable STOP clause (optional)
        # @option params [Boolean] :sender_for_response Enable reply capability (optional)
        # @raise [ValidationError, PhoneNumberError, MessageLengthError] if validation fails
        # @return [void]
        def validate!(params)
          validate_required_params!(params)
          validate_phone_numbers!(params[:to])
          validate_message!(params[:message], no_stop: params[:no_stop])
          validate_tag!(params[:tag]) if params[:tag]
          validate_deferred!(params[:deferred]) if params[:deferred]
          validate_sms_class!(params[:sms_class]) if params[:sms_class]
          validate_sms_coding!(params[:sms_coding]) if params[:sms_coding]
          validate_sender_for_response!(params) if params[:sender_for_response]
        end

        # Validate presence of required parameters
        #
        # @param params [Hash] Parameters to validate
        # @raise [ValidationError] if required params are missing
        def validate_required_params!(params)
          missing = []
          missing << "to" if params[:to].nil? || params[:to].to_s.empty?
          missing << "message" if params[:message].nil? || params[:message].to_s.empty?

          return if missing.empty?

          raise ValidationError, "Missing required parameters: #{missing.join(", ")}"
        end

        # Validate phone number(s)
        #
        # @param phones [String, Array<String>] Phone number(s) to validate
        # @raise [PhoneNumberError] if any phone number is invalid
        def validate_phone_numbers!(phones)
          phone_list = phones.is_a?(Array) ? phones : [phones]
          phone_list.each do |phone|
            PhoneNumber.validate!(PhoneNumber.format(phone))
          end
        end

        # Validate message content and length
        #
        # @param message [String] Message content
        # @param no_stop [Boolean] Whether STOP clause is disabled
        # @raise [MessageLengthError] if message exceeds limits (when raise_on_length_error is true)
        def validate_message!(message, no_stop: false)
          info = GsmEncoding.message_info(message, commercial: !no_stop)
          log_unicode_warning(info)
          validate_message_length!(info)
        end

        def log_unicode_warning(info)
          logger = Ovh::Http2sms.configuration.logger
          return unless info[:encoding] == :unicode && logger

          non_gsm = info[:non_gsm_chars].join(", ")
          logger.warn(
            "[OVH HTTP2SMS] Message requires Unicode encoding due to characters: #{non_gsm}. " \
            "This reduces maximum SMS length from 160 to 70 characters."
          )
        end

        def validate_message_length!(info)
          return unless info[:sms_count] > 10

          if Ovh::Http2sms.configuration.raise_on_length_error
            raise_length_error(info)
          else
            log_length_warning(info)
          end
        end

        def raise_length_error(info)
          raise MessageLengthError.new(
            "Message is very long and will be sent as #{info[:sms_count]} SMS segments. " \
            "Current length: #{info[:characters]} characters (#{info[:encoding]} encoding).",
            encoding: info[:encoding],
            length: info[:characters],
            max_length: info[:max_single_sms]
          )
        end

        def log_length_warning(info)
          logger = Ovh::Http2sms.configuration.logger
          return unless logger

          logger.warn(
            "[OVH HTTP2SMS] Message will be sent as #{info[:sms_count]} SMS segments " \
            "(#{info[:characters]} characters, #{info[:encoding]} encoding). This may incur additional charges."
          )
        end

        # Validate tag length
        #
        # @param tag [String] Tag to validate
        # @raise [ValidationError] if tag exceeds maximum length
        def validate_tag!(tag)
          return if tag.to_s.length <= MAX_TAG_LENGTH

          raise ValidationError,
                "Tag exceeds maximum length of #{MAX_TAG_LENGTH} characters (got #{tag.length})"
        end

        # Validate deferred date format
        #
        # @param deferred [Time, String] Deferred send time
        # @raise [ValidationError] if format is invalid
        def validate_deferred!(deferred)
          return if deferred.is_a?(Time) || deferred.is_a?(DateTime)

          deferred_str = deferred.to_s
          return if deferred_str.match?(DEFERRED_FORMAT_PATTERN)

          raise ValidationError,
                "Invalid deferred format: '#{deferred}'. " \
                "Expected hhmmddMMYYYY format (e.g., 125025112024 for 25/11/2024 at 12:50) " \
                "or a Ruby Time/DateTime object."
        end

        # Validate SMS class
        #
        # @param sms_class [Integer] SMS class value
        # @raise [ValidationError] if class is invalid
        def validate_sms_class!(sms_class)
          return if VALID_SMS_CLASSES.include?(sms_class.to_i)

          raise ValidationError,
                "Invalid SMS class: #{sms_class}. Must be 0, 1, 2, or 3."
        end

        # Validate SMS coding
        #
        # @param sms_coding [Integer] SMS coding value
        # @raise [ValidationError] if coding is invalid
        def validate_sms_coding!(sms_coding)
          return if VALID_SMS_CODINGS.include?(sms_coding.to_i)

          raise ValidationError,
                "Invalid SMS coding: #{sms_coding}. Must be 1 (7-bit) or 2 (Unicode)."
        end

        # Validate sender_for_response compatibility
        #
        # @param params [Hash] Full parameters hash
        # @return [void]
        def validate_sender_for_response!(params)
          return unless params[:sender_for_response] && params[:sender]

          # Log warning but don't raise error
          Ovh::Http2sms.configuration.logger&.warn(
            "[OVH HTTP2SMS] senderForResponse is enabled but a sender is also specified. " \
            "The 'from' parameter will be ignored. Leave sender empty when using senderForResponse."
          )
        end
      end
    end
  end
end
