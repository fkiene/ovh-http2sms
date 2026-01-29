# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.default_content_type).to eq("application/json")
      expect(config.timeout).to eq(15)
      expect(config.default_country_code).to eq("33")
      expect(config.raise_on_length_error).to be true
    end

    it "leaves credentials nil" do
      expect(config.account).to be_nil
      expect(config.login).to be_nil
      expect(config.password).to be_nil
    end
  end

  describe "#valid?" do
    it "returns false when credentials are missing" do
      expect(config.valid?).to be false
    end

    it "returns false when some credentials are missing" do
      config.account = "test"
      config.login = "user"
      expect(config.valid?).to be false
    end

    it "returns true when all credentials are present" do
      config.account = "test"
      config.login = "user"
      config.password = "pass"
      expect(config.valid?).to be true
    end

    it "returns false for empty strings" do
      config.account = ""
      config.login = "user"
      config.password = "pass"
      expect(config.valid?).to be false
    end
  end

  describe "#validate!" do
    it "raises ConfigurationError when credentials are missing" do
      expect { config.validate! }.to raise_error(
        Ovh::Http2sms::ConfigurationError,
        /Missing required configuration: account, login, password/
      )
    end

    it "raises ConfigurationError with specific missing fields" do
      config.account = "test"
      expect { config.validate! }.to raise_error(
        Ovh::Http2sms::ConfigurationError,
        /Missing required configuration: login, password/
      )
    end

    it "does not raise when valid" do
      config.account = "test"
      config.login = "user"
      config.password = "pass"
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#reset!" do
    before do
      config.account = "test"
      config.login = "user"
      config.password = "pass"
      config.timeout = 30
    end

    it "resets credentials to nil" do
      config.reset!
      expect(config.account).to be_nil
      expect(config.login).to be_nil
      expect(config.password).to be_nil
    end

    it "resets settings to defaults" do
      config.reset!
      expect(config.timeout).to eq(15)
    end
  end

  describe "environment variable loading" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "loads account from environment" do
      ENV["OVH_SMS_ACCOUNT"] = "env-account"
      new_config = described_class.new
      expect(new_config.account).to eq("env-account")
    end

    it "loads login from environment" do
      ENV["OVH_SMS_LOGIN"] = "env-login"
      new_config = described_class.new
      expect(new_config.login).to eq("env-login")
    end

    it "loads password from environment" do
      ENV["OVH_SMS_PASSWORD"] = "env-password"
      new_config = described_class.new
      expect(new_config.password).to eq("env-password")
    end

    it "loads timeout from environment" do
      ENV["OVH_SMS_TIMEOUT"] = "30"
      new_config = described_class.new
      expect(new_config.timeout).to eq(30)
    end

    it "loads default_country_code from environment" do
      ENV["OVH_SMS_DEFAULT_COUNTRY_CODE"] = "44"
      new_config = described_class.new
      expect(new_config.default_country_code).to eq("44")
    end

    it "loads raise_on_length_error from environment" do
      ENV["OVH_SMS_RAISE_ON_LENGTH_ERROR"] = "false"
      new_config = described_class.new
      expect(new_config.raise_on_length_error).to be false
    end
  end
end
