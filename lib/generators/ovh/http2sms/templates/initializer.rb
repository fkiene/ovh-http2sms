# frozen_string_literal: true

# OVH HTTP2SMS configuration
#
# You can configure the gem using:
# 1. This initializer (direct values or Rails credentials)
# 2. Environment variables: OVH_SMS_ACCOUNT, OVH_SMS_LOGIN, OVH_SMS_PASSWORD, etc.
#
# Environment variables take precedence if this block doesn't set values.

Ovh::Http2sms.configure do |config|
  # Required credentials
  # Option 1: Direct configuration (not recommended for production)
  # config.account = "sms-xx11111-1"
  # config.login = "your_login"
  # config.password = "your_password"

  # Option 2: Using Rails credentials (recommended)
  # Run: rails credentials:edit
  # Add:
  #   ovh_sms:
  #     account: sms-xx11111-1
  #     login: your_login
  #     password: your_password
  #
  if Rails.application.credentials.ovh_sms.present?
    config.account = Rails.application.credentials.dig(:ovh_sms, :account)
    config.login = Rails.application.credentials.dig(:ovh_sms, :login)
    config.password = Rails.application.credentials.dig(:ovh_sms, :password)
    config.default_sender = Rails.application.credentials.dig(:ovh_sms, :default_sender)
  end

  # Optional settings

  # Default sender name (must be registered in OVH account)
  # config.default_sender = "MyApp"

  # Default country code for phone number formatting (default: "33" for France)
  # config.default_country_code = "33"

  # Response content type: application/json, text/xml, text/plain, text/html
  # config.default_content_type = "application/json"

  # HTTP timeout in seconds (default: 15)
  # config.timeout = 15

  # Raise error if message exceeds SMS length limits (default: true)
  # config.raise_on_length_error = true

  # Logger for debugging (uses Rails.logger by default in Rails apps)
  config.logger = Rails.logger if defined?(Rails.logger)
end
