# frozen_string_literal: true

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe Ovh::Http2sms::Error do
  it "accepts message, status_code, and raw_response" do
    error = described_class.new("Test error", status_code: 201, raw_response: "raw")

    expect(error.message).to eq("Test error")
    expect(error.status_code).to eq(201)
    expect(error.raw_response).to eq("raw")
  end

  it "inherits from StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end
end

RSpec.describe Ovh::Http2sms::ConfigurationError do
  it "inherits from Error" do
    expect(described_class.new).to be_a(Ovh::Http2sms::Error)
  end
end

RSpec.describe Ovh::Http2sms::AuthenticationError do
  it "sets status code to 401" do
    error = described_class.new("IP not authorized")
    expect(error.status_code).to eq(401)
  end

  it "has default message" do
    error = described_class.new
    expect(error.message).to include("IP not authorized")
  end
end

RSpec.describe Ovh::Http2sms::MissingParameterError do
  it "sets status code to 201" do
    error = described_class.new("Missing message")
    expect(error.status_code).to eq(201)
  end

  it "stores parameter name" do
    error = described_class.new("Missing message", parameter: "message")
    expect(error.parameter).to eq("message")
  end
end

RSpec.describe Ovh::Http2sms::InvalidParameterError do
  it "sets status code to 202" do
    error = described_class.new("Invalid tag")
    expect(error.status_code).to eq(202)
  end

  it "stores parameter name" do
    error = described_class.new("Invalid tag", parameter: "tag")
    expect(error.parameter).to eq("tag")
  end
end

RSpec.describe Ovh::Http2sms::NetworkError do
  it "stores original error" do
    original = Faraday::TimeoutError.new("timed out")
    error = described_class.new("Network error", original_error: original)

    expect(error.original_error).to eq(original)
  end
end

RSpec.describe Ovh::Http2sms::MessageLengthError do
  it "stores encoding, length, and max_length" do
    error = described_class.new(
      "Message too long",
      encoding: :unicode,
      length: 75,
      max_length: 70
    )

    expect(error.encoding).to eq(:unicode)
    expect(error.length).to eq(75)
    expect(error.max_length).to eq(70)
  end
end

RSpec.describe Ovh::Http2sms::PhoneNumberError do
  it "stores phone number" do
    error = described_class.new("Invalid format", phone_number: "abc")
    expect(error.phone_number).to eq("abc")
  end
end

RSpec.describe Ovh::Http2sms::SenderNotFoundError do
  it "sets status code to 241" do
    error = described_class.new("Sender not found")
    expect(error.status_code).to eq(241)
  end

  it "stores sender name" do
    error = described_class.new("Sender not found", sender: "MyApp")
    expect(error.sender).to eq("MyApp")
  end
end

RSpec.describe Ovh::Http2sms::ResponseParseError do
  it "stores content type" do
    error = described_class.new("Parse failed", content_type: "application/json")
    expect(error.content_type).to eq("application/json")
  end

  it "stores raw response" do
    error = described_class.new("Parse failed", raw_response: "invalid")
    expect(error.raw_response).to eq("invalid")
  end
end

RSpec.describe Ovh::Http2sms::ValidationError do
  it "inherits from Error" do
    expect(described_class.new).to be_a(Ovh::Http2sms::Error)
  end
end
# rubocop:enable RSpec/MultipleDescribes
