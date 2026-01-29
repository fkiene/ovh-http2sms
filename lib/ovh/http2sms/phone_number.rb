# frozen_string_literal: true

module Ovh
  module Http2sms
    # Phone number formatting and validation utilities
    #
    # Converts local phone number formats to international format required by OVH API.
    # OVH requires the 00 prefix (e.g., 0033601020304 for French numbers).
    # Supports configurable country codes for different regions.
    #
    # @example Convert French number
    #   PhoneNumber.format("0601020304") # => "0033601020304"
    #
    # @example Convert UK number
    #   PhoneNumber.format("07911123456", country_code: "44") # => "00447911123456"
    module PhoneNumber
      # Pattern for numbers starting with 0 but not 00 (local format)
      LOCAL_FORMAT_PATTERN = /\A0(?!0)/

      # Pattern for numbers starting with + (international format with plus)
      PLUS_FORMAT_PATTERN = /\A\+/

      # Pattern for numbers starting with 00 (already OVH format)
      DOUBLE_ZERO_PATTERN = /\A00/

      # Valid phone number pattern (digits only, 9-17 digits for 00 prefix format)
      VALID_PHONE_PATTERN = /\A00\d{7,15}\z/

      class << self
        # Format a phone number to OVH international format (00 prefix)
        #
        # @param phone [String] Phone number in local or international format
        # @param country_code [String] Country code to use for local numbers (default: from config)
        # @return [String] Phone number in OVH format (e.g., "0033601020304")
        # @raise [PhoneNumberError] if phone number is invalid
        #
        # @example Local French number
        #   PhoneNumber.format("0601020304") # => "0033601020304"
        #
        # @example Already international with +
        #   PhoneNumber.format("+33601020304") # => "0033601020304"
        #
        # @example Already OVH format
        #   PhoneNumber.format("0033601020304") # => "0033601020304"
        #
        # @example UK number
        #   PhoneNumber.format("07911123456", country_code: "44") # => "00447911123456"
        def format(phone, country_code: nil)
          return nil if phone.nil?

          country_code ||= Ovh::Http2sms.configuration.default_country_code

          # Remove all non-digit characters except leading +
          cleaned = clean_phone(phone)

          # Convert to OVH international format (00 prefix)
          formatted = to_ovh_format(cleaned, country_code)

          # Validate the result
          validate!(formatted)

          formatted
        end

        # Format multiple phone numbers
        #
        # @param phones [Array<String>, String] Phone number(s) - can be array or comma-separated string
        # @param country_code [String] Country code to use for local numbers
        # @return [Array<String>] Array of formatted phone numbers
        # @raise [PhoneNumberError] if any phone number is invalid
        #
        # @example Array input
        #   PhoneNumber.format_multiple(["0601020304", "0602030405"])
        #   # => ["0033601020304", "0033602030405"]
        #
        # @example Comma-separated string
        #   PhoneNumber.format_multiple("0601020304,0602030405")
        #   # => ["0033601020304", "0033602030405"]
        def format_multiple(phones, country_code: nil)
          phone_array = phones.is_a?(Array) ? phones : phones.to_s.split(",")
          phone_array.map { |p| format(p.strip, country_code: country_code) }
        end

        # Validate a phone number format
        #
        # @param phone [String] Phone number to validate
        # @return [Boolean] true if valid
        def valid?(phone)
          return false if phone.nil? || phone.empty?

          phone.match?(VALID_PHONE_PATTERN)
        end

        # Validate a phone number and raise error if invalid
        #
        # @param phone [String] Phone number to validate
        # @raise [PhoneNumberError] if phone number is invalid
        # @return [void]
        def validate!(phone)
          return if valid?(phone)

          raise PhoneNumberError.new(
            "Invalid phone number format: '#{phone}'. " \
            "Expected OVH format with 00 prefix (e.g., 0033601020304)",
            phone_number: phone
          )
        end

        private

        def clean_phone(phone)
          # Remove all whitespace, dashes, dots, and parentheses
          phone.to_s.gsub(/[\s\-.()\[\]]/, "")
        end

        def to_ovh_format(phone, country_code)
          if phone.match?(PLUS_FORMAT_PATTERN)
            # +33601020304 -> 0033601020304
            "00#{phone.sub(PLUS_FORMAT_PATTERN, "")}"
          elsif phone.match?(DOUBLE_ZERO_PATTERN)
            # Already in OVH format: 0033601020304
            phone
          elsif phone.match?(LOCAL_FORMAT_PATTERN)
            # 0601020304 -> 0033601020304
            "00#{country_code}#{phone.sub(LOCAL_FORMAT_PATTERN, "")}"
          else
            # Assume raw country code format: 33601020304 -> 0033601020304
            "00#{phone}"
          end
        end
      end
    end
  end
end
