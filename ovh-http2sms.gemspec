# frozen_string_literal: true

require_relative "lib/ovh/http2sms/version"

Gem::Specification.new do |spec|
  spec.name = "ovh-http2sms"
  spec.version = Ovh::Http2sms::VERSION
  spec.authors = ["François Kiene"]

  spec.summary = "Ruby gem to send SMS via OVH's http2sms API"
  spec.description = "A production-ready Ruby gem that wraps OVH's http2sms API to send SMS via simple HTTP GET requests. " \
                     "Supports single and bulk sending, scheduled messages, GSM/Unicode encoding detection, " \
                     "phone number formatting, and Rails integration."
  spec.homepage = "https://github.com/fkiene/ovh-http2sms"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fkiene/ovh-http2sms"
  spec.metadata["changelog_uri"] = "https://github.com/fkiene/ovh-http2sms/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/ovh-http2sms"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?(*%w[bin/ spec/ .git .github .rspec .rubocop])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", ">= 1.0", "< 3.0"
  spec.add_dependency "gsm_encoder", "~> 0.1.7"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 3.9"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "yard", "~> 0.9"
end
