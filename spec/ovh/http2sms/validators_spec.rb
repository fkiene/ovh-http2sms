# frozen_string_literal: true

RSpec.describe Ovh::Http2sms::Validators do
  describe ".validate!" do
    let(:valid_params) { { to: "33601020304", message: "Hello!" } }

    it "does not raise for valid params" do
      expect { described_class.validate!(valid_params) }.not_to raise_error
    end
  end

  describe ".validate_required_params!" do
    it "raises for missing 'to'" do
      expect do
        described_class.validate_required_params!({ message: "Hello" })
      end.to raise_error(Ovh::Http2sms::ValidationError, /Missing required parameters: to/)
    end

    it "raises for missing 'message'" do
      expect do
        described_class.validate_required_params!({ to: "123" })
      end.to raise_error(Ovh::Http2sms::ValidationError, /Missing required parameters: message/)
    end

    it "raises for empty 'to'" do
      expect do
        described_class.validate_required_params!({ to: "", message: "Hello" })
      end.to raise_error(Ovh::Http2sms::ValidationError, /Missing required parameters: to/)
    end

    it "raises for both missing" do
      expect do
        described_class.validate_required_params!({})
      end.to raise_error(Ovh::Http2sms::ValidationError, /to, message/)
    end

    it "does not raise when both present" do
      expect do
        described_class.validate_required_params!({ to: "123", message: "Hello" })
      end.not_to raise_error
    end
  end

  describe ".validate_phone_numbers!" do
    it "accepts valid single number" do
      expect { described_class.validate_phone_numbers!("33601020304") }.not_to raise_error
    end

    it "accepts valid array of numbers" do
      expect do
        described_class.validate_phone_numbers!(%w[33601020304 33602030405])
      end.not_to raise_error
    end

    it "raises for invalid number" do
      expect do
        described_class.validate_phone_numbers!("abc")
      end.to raise_error(Ovh::Http2sms::PhoneNumberError)
    end

    it "raises if any number in array is invalid" do
      expect do
        described_class.validate_phone_numbers!(%w[33601020304 abc])
      end.to raise_error(Ovh::Http2sms::PhoneNumberError)
    end
  end

  describe ".validate_tag!" do
    it "accepts tag up to 20 characters" do
      expect { described_class.validate_tag!("a" * 20) }.not_to raise_error
    end

    it "raises for tag over 20 characters" do
      expect do
        described_class.validate_tag!("a" * 21)
      end.to raise_error(Ovh::Http2sms::ValidationError, /exceeds maximum length of 20/)
    end
  end

  describe ".validate_deferred!" do
    it "accepts Time object" do
      expect { described_class.validate_deferred!(Time.now) }.not_to raise_error
    end

    it "accepts DateTime object" do
      expect { described_class.validate_deferred!(DateTime.now) }.not_to raise_error
    end

    it "accepts valid format string (hhmmddMMYYYY)" do
      expect { described_class.validate_deferred!("125025112024") }.not_to raise_error
    end

    it "raises for invalid format" do
      expect do
        described_class.validate_deferred!("2024-11-25 12:50")
      end.to raise_error(Ovh::Http2sms::ValidationError, /Invalid deferred format/)
    end

    it "raises for partial format" do
      expect do
        described_class.validate_deferred!("12502511")
      end.to raise_error(Ovh::Http2sms::ValidationError)
    end
  end

  describe ".validate_sms_class!" do
    it "accepts valid classes 0-3" do
      (0..3).each do |sms_class|
        expect { described_class.validate_sms_class!(sms_class) }.not_to raise_error
      end
    end

    it "raises for invalid class" do
      expect do
        described_class.validate_sms_class!(4)
      end.to raise_error(Ovh::Http2sms::ValidationError, /Invalid SMS class/)
    end
  end

  describe ".validate_sms_coding!" do
    it "accepts 1 (7-bit)" do
      expect { described_class.validate_sms_coding!(1) }.not_to raise_error
    end

    it "accepts 2 (Unicode)" do
      expect { described_class.validate_sms_coding!(2) }.not_to raise_error
    end

    it "raises for invalid coding" do
      expect do
        described_class.validate_sms_coding!(3)
      end.to raise_error(Ovh::Http2sms::ValidationError, /Invalid SMS coding/)
    end
  end

  describe ".validate_sender_for_response!" do
    it "does not raise when sender_for_response is false" do
      expect do
        described_class.validate_sender_for_response!({ sender_for_response: false, sender: "Test" })
      end.not_to raise_error
    end

    it "does not raise when sender_for_response is true without sender" do
      expect do
        described_class.validate_sender_for_response!({ sender_for_response: true })
      end.not_to raise_error
    end

    it "logs warning when both sender_for_response and sender are set" do
      logger = instance_double(Logger)
      allow(logger).to receive(:warn)
      Ovh::Http2sms.configure { |c| c.logger = logger }

      described_class.validate_sender_for_response!({ sender_for_response: true, sender: "Test" })

      expect(logger).to have_received(:warn).with(/senderForResponse is enabled but a sender is also specified/)
    end
  end

  describe ".validate_message!" do
    before do
      Ovh::Http2sms.configure { |c| c.raise_on_length_error = true }
    end

    it "does not raise for normal messages" do
      expect { described_class.validate_message!("Hello!") }.not_to raise_error
    end

    it "raises for very long messages (>10 SMS segments)" do
      very_long_message = "A" * 2000
      expect do
        described_class.validate_message!(very_long_message)
      end.to raise_error(Ovh::Http2sms::MessageLengthError)
    end

    it "logs warning for Unicode encoding" do
      logger = instance_double(Logger)
      allow(logger).to receive(:warn)
      Ovh::Http2sms.configure do |c|
        c.logger = logger
        c.raise_on_length_error = true
      end

      described_class.validate_message!("Hello 👋")

      expect(logger).to have_received(:warn).with(/Unicode encoding/)
    end

    it "respects raise_on_length_error config" do
      Ovh::Http2sms.configure { |c| c.raise_on_length_error = false }
      very_long_message = "A" * 2000

      expect { described_class.validate_message!(very_long_message) }.not_to raise_error
    end
  end
end
