# frozen_string_literal: true

RSpec.describe Ovh::Http2sms do
  it "has a version number" do
    expect(Ovh::Http2sms::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "yields configuration block" do
      described_class.configure do |config|
        config.account = "sms-test-1"
        config.login = "user"
        config.password = "pass"
      end

      expect(described_class.configuration.account).to eq("sms-test-1")
      expect(described_class.configuration.login).to eq("user")
      expect(described_class.configuration.password).to eq("pass")
    end

    it "returns configuration object" do
      result = described_class.configure { |c| c.account = "test" }
      expect(result).to be_a(Ovh::Http2sms::Configuration)
    end
  end

  describe ".reset_configuration!" do
    it "resets configuration to defaults" do
      described_class.configure { |c| c.account = "test-account" }
      described_class.reset_configuration!

      expect(described_class.configuration.account).to be_nil
    end
  end

  describe ".deliver" do
    before { configure_with_valid_credentials }

    it "sends SMS via client" do
      stub_successful_response

      response = described_class.deliver(to: "33601020304", message: "Hello!")

      expect(response).to be_success
      expect(response.sms_ids).to eq(["123456789"])
    end
  end

  describe ".client" do
    it "returns a new client instance" do
      client = described_class.client

      expect(client).to be_a(Ovh::Http2sms::Client)
    end

    it "allows configuration overrides" do
      described_class.configure { |c| c.account = "global-account" }
      client = described_class.client(account: "override-account")

      expect(client.config.account).to eq("override-account")
    end
  end

  describe ".message_info" do
    it "returns message information" do
      info = described_class.message_info("Hello!")

      expect(info[:characters]).to eq(6)
      expect(info[:encoding]).to eq(:gsm)
      expect(info[:sms_count]).to eq(1)
    end

    it "handles commercial parameter" do
      info_commercial = described_class.message_info("Hello!", commercial: true)
      info_non_commercial = described_class.message_info("Hello!", commercial: false)

      # Commercial has lower limit due to STOP clause
      expect(info_commercial[:remaining]).to be < info_non_commercial[:remaining]
    end
  end

  describe ".gsm_compatible?" do
    it "returns true for GSM characters" do
      expect(described_class.gsm_compatible?("Hello World!")).to be true
    end

    it "returns false for non-GSM characters" do
      expect(described_class.gsm_compatible?("Hello 👋")).to be false
    end
  end

  describe ".format_phone" do
    it "formats local numbers to OVH international format" do
      expect(described_class.format_phone("0601020304")).to eq("0033601020304")
    end

    it "handles already international numbers" do
      expect(described_class.format_phone("33601020304")).to eq("0033601020304")
    end

    it "handles plus prefix" do
      expect(described_class.format_phone("+33601020304")).to eq("0033601020304")
    end
  end
end
