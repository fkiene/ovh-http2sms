# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::Client do
  subject(:client) { described_class.new }

  before { configure_with_valid_credentials }

  describe "#initialize" do
    it "uses global configuration by default" do
      expect(client.config.account).to eq("sms-test-1")
    end

    it "allows configuration overrides" do
      custom_client = described_class.new(account: "custom-account")
      expect(custom_client.config.account).to eq("custom-account")
    end

    it "merges with global configuration" do
      custom_client = described_class.new(account: "custom-account")
      expect(custom_client.config.login).to eq("test_user") # from global
    end
  end

  describe "#deliver" do
    context "with valid parameters" do
      before { stub_successful_response }

      it "sends SMS and returns response" do
        response = client.deliver(to: "33601020304", message: "Hello!")

        expect(response).to be_success
        expect(response.sms_ids).to eq(["123456789"])
      end

      it "formats phone numbers" do
        client.deliver(to: "0601020304", message: "Hello!")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("to" => "0033601020304"))
      end

      it "sends to multiple recipients" do
        client.deliver(to: %w[0601020304 0602030405], message: "Hello!")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("to" => "0033601020304,0033602030405"))
      end

      it "includes required parameters" do
        client.deliver(to: "33601020304", message: "Hello!")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including(
            "account" => "sms-test-1",
            "login" => "test_user",
            "password" => "test_password",
            "message" => "Hello!"
          ))
      end

      it "includes sender when provided" do
        client.deliver(to: "33601020304", message: "Hello!", sender: "MyApp")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("from" => "MyApp"))
      end

      it "uses default sender from config" do
        Ovh::Http2sms.configure { |c| c.default_sender = "DefaultApp" }

        client.deliver(to: "33601020304", message: "Hello!")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("from" => "DefaultApp"))
      end

      it "sets senderForResponse when enabled" do
        client.deliver(to: "33601020304", message: "Hello!", sender_for_response: true)

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("senderForResponse" => "1", "from" => ""))
      end

      it "includes tag when provided" do
        client.deliver(to: "33601020304", message: "Hello!", tag: "test-tag")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("tag" => "test-tag"))
      end

      it "includes noStop when enabled" do
        client.deliver(to: "33601020304", message: "Hello!", no_stop: true)

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("noStop" => "1"))
      end

      it "includes sms_class when provided" do
        client.deliver(to: "33601020304", message: "Hello!", sms_class: 2)

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("class" => "2"))
      end

      it "includes sms_coding when provided" do
        client.deliver(to: "33601020304", message: "Hello!", sms_coding: 2)

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("smsCoding" => "2"))
      end

      it "formats deferred Time to OVH format" do
        time = Time.new(2024, 11, 25, 12, 50, 0)
        client.deliver(to: "33601020304", message: "Hello!", deferred: time)

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("deferred" => "125025112024"))
      end

      it "passes through deferred string" do
        client.deliver(to: "33601020304", message: "Hello!", deferred: "125025112024")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("deferred" => "125025112024"))
      end

      it "encodes line breaks in message" do
        client.deliver(to: "33601020304", message: "Line1\nLine2")

        expect(WebMock).to have_requested(:get, /ovh\.com/)
          .with(query: hash_including("message" => "Line1%0dLine2"))
      end
    end

    context "with error responses" do
      it "raises AuthenticationError for status 401" do
        stub_error_response(status: 401, message: "IP not authorized")

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::AuthenticationError, /IP not authorized/)
      end

      it "raises MissingParameterError for status 201" do
        stub_error_response(status: 201, message: "Missing message")

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::MissingParameterError)
      end

      it "raises InvalidParameterError for status 202" do
        stub_error_response(status: 202, message: "Invalid tag: is too long")

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::InvalidParameterError)
      end

      it "raises SenderNotFoundError for status 241" do
        stub_error_response(status: 241, message: "Sms sender MyApp does not exists")

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::SenderNotFoundError)
      end
    end

    context "with network errors" do
      it "raises NetworkError on timeout" do
        stub_request(:get, /ovh\.com/).to_timeout

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::NetworkError)
      end

      it "raises NetworkError on connection failure" do
        stub_request(:get, /ovh\.com/).to_raise(Faraday::ConnectionFailed)

        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::NetworkError)
      end
    end

    context "without configuration" do
      before { Ovh::Http2sms.reset_configuration! }

      it "raises ConfigurationError" do
        expect do
          client.deliver(to: "33601020304", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::ConfigurationError)
      end
    end

    context "with validation errors" do
      before { stub_successful_response }

      it "raises ValidationError for missing message" do
        expect do
          client.deliver(to: "33601020304", message: "")
        end.to raise_error(Ovh::Http2sms::ValidationError)
      end

      it "raises PhoneNumberError for invalid phone" do
        expect do
          client.deliver(to: "abc", message: "Hello!")
        end.to raise_error(Ovh::Http2sms::PhoneNumberError)
      end

      it "raises ValidationError for invalid tag" do
        expect do
          client.deliver(to: "33601020304", message: "Hello!", tag: "a" * 21)
        end.to raise_error(Ovh::Http2sms::ValidationError)
      end
    end

    context "with logging" do
      let(:logger) { instance_double(Logger) }

      before do
        allow(logger).to receive(:debug)
        allow(logger).to receive(:warn)
        Ovh::Http2sms.configure { |c| c.logger = logger }
        stub_successful_response
      end

      it "logs request with filtered password" do
        client.deliver(to: "33601020304", message: "Hello!")

        expect(logger).to have_received(:debug).with(/Request:.*\[FILTERED\]/)
      end

      it "logs response" do
        client.deliver(to: "33601020304", message: "Hello!")

        expect(logger).to have_received(:debug).with(/Response:.*success=true/)
      end
    end
  end
end
