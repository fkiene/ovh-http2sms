# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::GsmEncoding do
  describe ".gsm_compatible?" do
    it "returns true for basic Latin characters" do
      expect(described_class.gsm_compatible?("Hello World")).to be true
    end

    it "returns true for digits" do
      expect(described_class.gsm_compatible?("0123456789")).to be true
    end

    it "returns true for GSM special characters" do
      expect(described_class.gsm_compatible?("@£$¥èéùìòÇ")).to be true
    end

    it "returns true for extension characters" do
      expect(described_class.gsm_compatible?("€|^{}[]~\\")).to be true
    end

    it "returns false for emoji" do
      expect(described_class.gsm_compatible?("Hello 👋")).to be false
    end

    it "returns false for Cyrillic" do
      expect(described_class.gsm_compatible?("Привет")).to be false
    end

    it "returns false for smart quotes" do
      expect(described_class.gsm_compatible?("He said \u201Chello\u201D")).to be false
    end
  end

  describe ".detect_encoding" do
    it "returns :gsm for GSM-compatible messages" do
      expect(described_class.detect_encoding("Hello!")).to eq(:gsm)
    end

    it "returns :unicode for non-GSM messages" do
      expect(described_class.detect_encoding("Hello 🎉")).to eq(:unicode)
    end
  end

  describe ".gsm_char_count" do
    it "counts basic characters as 1" do
      expect(described_class.gsm_char_count("Hello")).to eq(5)
    end

    it "counts extension characters as 2" do
      expect(described_class.gsm_char_count("€")).to eq(2)
      expect(described_class.gsm_char_count("Price: €10")).to eq(11)
    end

    it "counts all extension characters correctly" do
      # €, |, ^, {, }, [, ], ~, \ each count as 2
      expect(described_class.gsm_char_count("€|^{}[]~\\")).to eq(18)
    end
  end

  describe ".non_gsm_characters" do
    it "returns empty array for GSM message" do
      expect(described_class.non_gsm_characters("Hello!")).to eq([])
    end

    it "returns non-GSM characters" do
      expect(described_class.non_gsm_characters("Hello 👋 World")).to eq(["👋"])
    end

    it "returns unique characters" do
      expect(described_class.non_gsm_characters("👋 and 👋")).to eq(["👋"])
    end
  end

  describe ".message_info" do
    context "with GSM encoding" do
      it "calculates basic message info" do
        info = described_class.message_info("Hello!")

        expect(info[:characters]).to eq(6)
        expect(info[:encoding]).to eq(:gsm)
        expect(info[:sms_count]).to eq(1)
        expect(info[:remaining]).to eq(143) # 149 - 6 (commercial)
      end

      it "accounts for extension characters" do
        info = described_class.message_info("€100")

        expect(info[:characters]).to eq(5) # € counts as 2
        expect(info[:encoding]).to eq(:gsm)
      end

      it "calculates multi-part SMS" do
        long_message = "A" * 150
        info = described_class.message_info(long_message)

        expect(info[:characters]).to eq(150)
        expect(info[:sms_count]).to eq(2) # 149 + 153 threshold
      end

      it "respects commercial parameter" do
        info_commercial = described_class.message_info("Hello!", commercial: true)
        info_non_commercial = described_class.message_info("Hello!", commercial: false)

        expect(info_commercial[:max_single_sms]).to eq(149)
        expect(info_non_commercial[:max_single_sms]).to eq(160)
      end
    end

    context "with Unicode encoding" do
      it "detects Unicode encoding" do
        info = described_class.message_info("Hello 👋")

        expect(info[:encoding]).to eq(:unicode)
        expect(info[:max_single_sms]).to eq(59) # commercial
      end

      it "calculates Unicode character count" do
        info = described_class.message_info("Привет")

        expect(info[:characters]).to eq(6)
        expect(info[:encoding]).to eq(:unicode)
      end

      it "reports non-GSM characters" do
        info = described_class.message_info("Hello 👋")

        expect(info[:non_gsm_chars]).to eq(["👋"])
      end

      it "calculates multi-part Unicode SMS" do
        long_message = "Привет " * 10 # 70 characters
        info = described_class.message_info(long_message)

        expect(info[:sms_count]).to be >= 2
      end
    end
  end

  describe "SMS limits constants" do
    it "defines correct GSM limits" do
      expect(described_class::GSM_SINGLE_SMS_LIMIT).to eq(160)
      expect(described_class::GSM_CONCAT_SMS_LIMIT).to eq(153)
      expect(described_class::GSM_FIRST_COMMERCIAL_LIMIT).to eq(149)
    end

    it "defines correct Unicode limits" do
      expect(described_class::UNICODE_SINGLE_SMS_LIMIT).to eq(70)
      expect(described_class::UNICODE_CONCAT_SMS_LIMIT).to eq(67)
      expect(described_class::UNICODE_FIRST_COMMERCIAL_LIMIT).to eq(59)
    end
  end
end
