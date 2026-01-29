# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::Response do
  describe "#success?" do
    it "returns true for status 100" do
      response = described_class.new(status: 100)
      expect(response.success?).to be true
    end

    it "returns true for status 101" do
      response = described_class.new(status: 101)
      expect(response.success?).to be true
    end

    it "returns false for error status codes" do
      [201, 202, 401, 0].each do |status|
        response = described_class.new(status: status)
        expect(response.success?).to be false
      end
    end
  end

  describe "#failure?" do
    it "returns opposite of success?" do
      success_response = described_class.new(status: 100)
      failure_response = described_class.new(status: 201)

      expect(success_response.failure?).to be false
      expect(failure_response.failure?).to be true
    end
  end

  describe "#error_type" do
    it "returns :missing_parameter for status 201" do
      response = described_class.new(status: 201)
      expect(response.error_type).to eq(:missing_parameter)
    end

    it "returns :invalid_parameter for status 202" do
      response = described_class.new(status: 202)
      expect(response.error_type).to eq(:invalid_parameter)
    end

    it "returns :authentication_error for status 401" do
      response = described_class.new(status: 401)
      expect(response.error_type).to eq(:authentication_error)
    end

    it "returns nil for success status" do
      response = described_class.new(status: 100)
      expect(response.error_type).to be_nil
    end
  end

  describe "#sms_ids" do
    it "returns array of strings" do
      response = described_class.new(status: 100, sms_ids: [123, 456])
      expect(response.sms_ids).to eq(%w[123 456])
    end

    it "handles single sms_id" do
      response = described_class.new(status: 100, sms_ids: "123")
      expect(response.sms_ids).to eq(["123"])
    end
  end

  describe ".parse" do
    context "with JSON response" do
      let(:success_json) { '{"status":100,"creditLeft":"1987","SmsIds":["10867690"]}' }
      let(:error_json) { '{"status":201,"message":"Missing message"}' }

      it "parses successful response" do
        response = described_class.parse(success_json, content_type: "application/json")

        expect(response.success?).to be true
        expect(response.status).to eq(100)
        expect(response.credits_remaining).to eq(1987.0)
        expect(response.sms_ids).to eq(["10867690"])
      end

      it "parses error response" do
        response = described_class.parse(error_json, content_type: "application/json")

        expect(response.failure?).to be true
        expect(response.status).to eq(201)
        expect(response.error_message).to eq("Missing message")
      end

      it "handles text/json content type" do
        response = described_class.parse(success_json, content_type: "text/json")
        expect(response.success?).to be true
      end
    end

    context "with XML response" do
      let(:success_xml) do
        '<?xml version="1.0" encoding="UTF-8" ?>' \
          "<response><status>100</status><creditLeft>1987</creditLeft>" \
          "<smsIds><smsId>10867690</smsId></smsIds></response>"
      end

      let(:error_xml) do
        '<?xml version="1.0" encoding="UTF-8" ?>' \
          "<response><status>201</status><message>Missing message</message></response>"
      end

      it "parses successful response" do
        response = described_class.parse(success_xml, content_type: "text/xml")

        expect(response.success?).to be true
        expect(response.credits_remaining).to eq(1987.0)
        expect(response.sms_ids).to eq(["10867690"])
      end

      it "parses error response" do
        response = described_class.parse(error_xml, content_type: "application/xml")

        expect(response.failure?).to be true
        expect(response.error_message).to eq("Missing message")
      end

      it "handles multiple SMS IDs" do
        multi_xml = '<?xml version="1.0" encoding="UTF-8" ?>' \
                    "<response><status>100</status><creditLeft>1987</creditLeft>" \
                    "<smsIds><smsId>123</smsId><smsId>456</smsId></smsIds></response>"

        response = described_class.parse(multi_xml, content_type: "text/xml")
        expect(response.sms_ids).to eq(%w[123 456])
      end
    end

    context "with HTML response" do
      let(:success_html) do
        "<!DOCTYPE html><HTML><HEAD></HEAD><BODY>OK<br>1987<br>10867690<br></BODY></HTML>"
      end

      let(:error_html) do
        "<!DOCTYPE html><HTML><HEAD></HEAD><BODY>KO<br>Missing message<br></BODY></HTML>"
      end

      it "parses successful response" do
        response = described_class.parse(success_html, content_type: "text/html")

        expect(response.success?).to be true
        expect(response.credits_remaining).to eq(1987.0)
        expect(response.sms_ids).to eq(["10867690"])
      end

      it "parses error response" do
        response = described_class.parse(error_html, content_type: "text/html")

        expect(response.failure?).to be true
        expect(response.error_message).to eq("Missing message")
      end
    end

    context "with text/plain response" do
      it "parses successful response" do
        response = described_class.parse("OK\n1987\n10867690", content_type: "text/plain")

        expect(response.success?).to be true
        expect(response.credits_remaining).to eq(1987.0)
        expect(response.sms_ids).to eq(["10867690"])
      end

      it "parses error response" do
        response = described_class.parse("KO\nMissing message", content_type: "text/plain")

        expect(response.failure?).to be true
        expect(response.error_message).to eq("Missing message")
      end

      it "handles multiple SMS IDs" do
        response = described_class.parse("OK\n1987\n123\n456\n789", content_type: "text/plain")
        expect(response.sms_ids).to eq(%w[123 456 789])
      end

      it "handles Windows line endings" do
        response = described_class.parse("OK\r\n1987\r\n123", content_type: "text/plain")
        expect(response.sms_ids).to eq(["123"])
      end
    end

    context "with invalid response" do
      it "returns error response for empty body" do
        response = described_class.parse("", content_type: "text/plain")

        expect(response.failure?).to be true
        expect(response.error_message).to eq("Empty response")
      end

      it "raises ResponseParseError for malformed JSON" do
        expect do
          described_class.parse("not json", content_type: "application/json")
        end.to raise_error(Ovh::Http2sms::ResponseParseError, /Failed to parse/)
      end

      it "includes content type in parse error" do
        error = nil
        expect do
          described_class.parse("{invalid", content_type: "application/json")
        end.to raise_error(Ovh::Http2sms::ResponseParseError) { |e| error = e }
        expect(error.content_type).to eq("application/json")
      end
    end

    context "with default content type" do
      it "defaults to text/plain parsing" do
        response = described_class.parse("OK\n1987\n123")
        expect(response.success?).to be true
      end
    end
  end
end
