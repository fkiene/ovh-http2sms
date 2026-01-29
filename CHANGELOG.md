# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-01-29

### Changed

- Bump `rubocop-rspec` from 2.x to 3.9
- Bump `actions/checkout` from 4 to 6
- Bump `codecov/codecov-action` from 4 to 5
- Bump `softprops/action-gh-release` from 1 to 2
- Update RuboCop config to use plugins syntax (rubocop-rspec 3.x)
- Re-enable `RSpec/PredicateMatcher` cop (fixed in rubocop-rspec 3.x)

## [0.1.1] - 2025-01-29

### Added

- Request lifecycle callbacks for monitoring and metrics:
  - `before_request`: called before each API request with filtered params
  - `after_request`: called after each request with response
  - `on_success`: called on successful SMS delivery
  - `on_failure`: called on failed delivery
- Dependabot configuration for automated dependency updates
- Community contribution files:
  - `CONTRIBUTING.md` with development guidelines
  - Pull request template
  - Issue templates for bugs and feature requests
- `SenderNotFoundError` exception for status 241
- `ResponseParseError` exception for malformed responses

### Changed

- Improved error handling with more specific exception types

## [0.1.0] - 2025-01-28

### Added

- Initial release
- Core SMS sending functionality via OVH http2sms API
- Support for single and multiple recipients
- Scheduled (deferred) message sending with Time objects or OVH format
- GSM 03.38 encoding detection using `gsm_encoder` gem
- Unicode encoding support with automatic detection
- Phone number formatting (local to international format)
- Configurable country codes for international support
- Commercial SMS handling with STOP clause character limits
- Reply-enabled SMS (senderForResponse)
- Response parsing for all formats: JSON, XML, HTML, text/plain
- Configuration via block, environment variables, or options hash
- Rails integration with generator (`rails g ovh:http2sms:install`)
- Rails credentials support
- Comprehensive error handling with custom exception classes:
  - `ConfigurationError`
  - `AuthenticationError`
  - `MissingParameterError`
  - `InvalidParameterError`
  - `NetworkError`
  - `MessageLengthError`
  - `PhoneNumberError`
  - `ValidationError`
- Thread-safe client implementation
- Full YARD documentation
- RSpec test suite with WebMock
- Rubocop configuration
- GitHub Actions CI workflow

### Dependencies

- Ruby >= 3.0.0
- Faraday >= 1.0, < 3.0
- gsm_encoder ~> 0.1.7

[Unreleased]: https://github.com/fkiene/ovh-http2sms/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/fkiene/ovh-http2sms/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/fkiene/ovh-http2sms/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/fkiene/ovh-http2sms/releases/tag/v0.1.0
