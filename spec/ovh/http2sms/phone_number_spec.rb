# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::PhoneNumber do
  describe ".format" do
    context "with French numbers (default country code 33)" do
      it "converts local format to OVH international" do
        expect(described_class.format("0601020304")).to eq("0033601020304")
      end

      it "converts plus format to OVH international" do
        expect(described_class.format("+33601020304")).to eq("0033601020304")
      end

      it "keeps already OVH formatted numbers" do
        expect(described_class.format("0033601020304")).to eq("0033601020304")
      end

      it "converts raw country code format" do
        expect(described_class.format("33601020304")).to eq("0033601020304")
      end

      it "removes spaces and special characters" do
        expect(described_class.format("06 01 02 03 04")).to eq("0033601020304")
        expect(described_class.format("06-01-02-03-04")).to eq("0033601020304")
        expect(described_class.format("06.01.02.03.04")).to eq("0033601020304")
        expect(described_class.format("(06) 01-02-03-04")).to eq("0033601020304")
      end
    end

    context "with custom country code" do
      it "uses provided country code" do
        expect(described_class.format("07911123456", country_code: "44")).to eq("00447911123456")
      end

      it "handles UK format" do
        expect(described_class.format("07911 123456", country_code: "44")).to eq("00447911123456")
      end
    end

    context "with nil input" do
      it "returns nil" do
        expect(described_class.format(nil)).to be_nil
      end
    end

    context "with invalid numbers" do
      it "raises PhoneNumberError for too short numbers" do
        expect { described_class.format("123") }.to raise_error(Ovh::Http2sms::PhoneNumberError)
      end

      it "raises PhoneNumberError for letters" do
        expect { described_class.format("abc123def") }.to raise_error(Ovh::Http2sms::PhoneNumberError)
      end
    end
  end

  describe ".format_multiple" do
    it "formats array of phone numbers" do
      phones = %w[0601020304 0602030405]
      result = described_class.format_multiple(phones)

      expect(result).to eq(%w[0033601020304 0033602030405])
    end

    it "formats comma-separated string" do
      phones = "0601020304,0602030405"
      result = described_class.format_multiple(phones)

      expect(result).to eq(%w[0033601020304 0033602030405])
    end

    it "handles spaces around comma" do
      phones = "0601020304, 0602030405"
      result = described_class.format_multiple(phones)

      expect(result).to eq(%w[0033601020304 0033602030405])
    end

    it "uses custom country code" do
      phones = %w[07911123456 07922234567]
      result = described_class.format_multiple(phones, country_code: "44")

      expect(result).to eq(%w[00447911123456 00447922234567])
    end
  end

  describe ".valid?" do
    it "returns true for valid OVH format numbers" do
      expect(described_class.valid?("0033601020304")).to be true
      expect(described_class.valid?("00447911123456")).to be true
    end

    it "returns false for nil" do
      expect(described_class.valid?(nil)).to be false
    end

    it "returns false for empty string" do
      expect(described_class.valid?("")).to be false
    end

    it "returns false for numbers without 00 prefix" do
      expect(described_class.valid?("33601020304")).to be false
      expect(described_class.valid?("0601020304")).to be false
    end

    it "returns false for numbers with letters" do
      expect(described_class.valid?("0033abc123")).to be false
    end
  end

  describe ".validate!" do
    it "does not raise for valid OVH format numbers" do
      expect { described_class.validate!("0033601020304") }.not_to raise_error
    end

    it "raises PhoneNumberError for invalid numbers" do
      expect { described_class.validate!("abc") }.to raise_error(Ovh::Http2sms::PhoneNumberError)
    end

    it "includes phone number in error" do
      expect { described_class.validate!("abc") }.to raise_error do |error|
        expect(error.phone_number).to eq("abc")
      end
    end
  end
end
