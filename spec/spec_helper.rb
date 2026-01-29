# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  minimum_coverage 95
end

require "ovh/http2sms"
require "webmock/rspec"

# Disable external HTTP connections
WebMock.disable_net_connect!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration before each test
  config.before do
    Ovh::Http2sms.reset_configuration!
  end
end

# Helper to configure with valid credentials
def configure_with_valid_credentials
  Ovh::Http2sms.configure do |config|
    config.account = "sms-test-1"
    config.login = "test_user"
    config.password = "test_password"
  end
end

# Helper to stub successful API response
def stub_successful_response(sms_id: "123456789", credits: "1987")
  stub_request(:get, /ovh\.com.*http2sms\.cgi/)
    .to_return(
      status: 200,
      body: { status: 100, creditLeft: credits, SmsIds: [sms_id] }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

# Helper to stub error API response
def stub_error_response(status:, message: nil)
  body = { status: status }
  body[:message] = message if message
  stub_request(:get, /ovh\.com.*http2sms\.cgi/)
    .to_return(
      status: 200,
      body: body.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end
