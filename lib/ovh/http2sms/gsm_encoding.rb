# frozen_string_literal: true

require "gsm_encoder"

module Ovh
  module Http2sms
    # GSM 03.38 encoding utilities for SMS character counting
    #
    # Uses the gsm_encoder gem for character validation and provides
    # OVH-specific SMS limits accounting for the STOP clause.
    #
    # Standard SMS messages use GSM 7-bit encoding which allows 160 characters.
    # Extension characters (€, |, ^, {, }, [, ], ~, \) count as 2 characters.
    # Non-GSM characters force Unicode encoding which limits messages to 70 characters.
    #
    # Commercial SMS must include STOP clause which uses 11 characters,
    # reducing the first SMS limit.
    module GsmEncoding
      # SMS limits for GSM 7-bit encoding
      GSM_SINGLE_SMS_LIMIT = 160
      GSM_CONCAT_SMS_LIMIT = 153 # 7 chars used for UDH header in concatenated SMS
      GSM_FIRST_COMMERCIAL_LIMIT = 149 # After STOP clause (11 chars)
      GSM_CONCAT_COMMERCIAL_LIMIT = 153

      # SMS limits for Unicode encoding
      UNICODE_SINGLE_SMS_LIMIT = 70
      UNICODE_CONCAT_SMS_LIMIT = 67 # 3 chars used for UDH header
      UNICODE_FIRST_COMMERCIAL_LIMIT = 59 # After STOP clause (11 chars)
      UNICODE_CONCAT_COMMERCIAL_LIMIT = 70

      # Extension characters that count as 2 in GSM encoding
      EXTENSION_CHARACTERS = Set["€", "|", "^", "{", "}", "[", "]", "~", "\\"].freeze

      class << self
        # Check if a message contains only GSM 03.38 characters
        #
        # @param message [String] The message to check
        # @return [Boolean] true if all characters are GSM compatible
        #
        # @example
        #   GsmEncoding.gsm_compatible?("Hello!") # => true
        #   GsmEncoding.gsm_compatible?("Hello 👋") # => false
        def gsm_compatible?(message)
          GSMEncoder.can_encode?(message)
        end

        # Detect the required encoding for a message
        #
        # @param message [String] The message to analyze
        # @return [Symbol] :gsm or :unicode
        #
        # @example
        #   GsmEncoding.detect_encoding("Hello!") # => :gsm
        #   GsmEncoding.detect_encoding("Привет") # => :unicode
        def detect_encoding(message)
          gsm_compatible?(message) ? :gsm : :unicode
        end

        # Calculate the GSM character count (extension chars count as 2)
        #
        # @param message [String] The message to count
        # @return [Integer] Character count in GSM encoding
        #
        # @example
        #   GsmEncoding.gsm_char_count("Hello") # => 5
        #   GsmEncoding.gsm_char_count("Price: €10") # => 11 (€ counts as 2)
        def gsm_char_count(message)
          message.each_char.sum do |char|
            EXTENSION_CHARACTERS.include?(char) ? 2 : 1
          end
        end

        # Find all non-GSM characters in a message
        #
        # @param message [String] The message to check
        # @return [Array<String>] Array of non-GSM characters found
        #
        # @example
        #   GsmEncoding.non_gsm_characters("Hello 👋 World") # => ["👋"]
        def non_gsm_characters(message)
          message.each_char.reject { |char| can_encode_char?(char) }.uniq
        end

        # Calculate message info including SMS count
        #
        # @param message [String] The message to analyze
        # @param commercial [Boolean] Whether this is a commercial SMS (includes STOP clause)
        # @return [Hash] Message information with keys:
        #   - :characters - Character count (accounting for extension chars in GSM)
        #   - :encoding - :gsm or :unicode
        #   - :sms_count - Number of SMS segments required
        #   - :remaining - Characters remaining in current segment
        #   - :max_single_sms - Maximum chars for single SMS with this encoding
        #   - :non_gsm_chars - Array of non-GSM characters found (empty for GSM encoding)
        #
        # @example
        #   GsmEncoding.message_info("Hello!")
        #   # => { characters: 6, encoding: :gsm, sms_count: 1, remaining: 143, ... }
        def message_info(message, commercial: true)
          encoding = detect_encoding(message)

          if encoding == :gsm
            gsm_message_info(message, commercial: commercial)
          else
            unicode_message_info(message, commercial: commercial)
          end
        end

        private

        def can_encode_char?(char)
          GSMEncoder.can_encode?(char)
        end

        def gsm_message_info(message, commercial:)
          char_count = gsm_char_count(message)

          first_limit = commercial ? GSM_FIRST_COMMERCIAL_LIMIT : GSM_SINGLE_SMS_LIMIT
          concat_limit = commercial ? GSM_CONCAT_COMMERCIAL_LIMIT : GSM_CONCAT_SMS_LIMIT

          sms_count, remaining = calculate_sms_count(char_count, first_limit, concat_limit)

          {
            characters: char_count,
            encoding: :gsm,
            sms_count: sms_count,
            remaining: remaining,
            max_single_sms: first_limit,
            non_gsm_chars: []
          }
        end

        def unicode_message_info(message, commercial:)
          char_count = message.length

          first_limit = commercial ? UNICODE_FIRST_COMMERCIAL_LIMIT : UNICODE_SINGLE_SMS_LIMIT
          concat_limit = commercial ? UNICODE_CONCAT_COMMERCIAL_LIMIT : UNICODE_CONCAT_SMS_LIMIT

          sms_count, remaining = calculate_sms_count(char_count, first_limit, concat_limit)

          {
            characters: char_count,
            encoding: :unicode,
            sms_count: sms_count,
            remaining: remaining,
            max_single_sms: first_limit,
            non_gsm_chars: non_gsm_characters(message)
          }
        end

        def calculate_sms_count(char_count, first_limit, concat_limit)
          if char_count <= first_limit
            [1, first_limit - char_count]
          else
            # Multi-part SMS calculation
            remaining_after_first = char_count - first_limit
            additional_sms = (remaining_after_first.to_f / concat_limit).ceil
            total_sms = 1 + additional_sms

            total_capacity = first_limit + (additional_sms * concat_limit)
            remaining = total_capacity - char_count

            [total_sms, remaining]
          end
        end
      end
    end
  end
end
