FROM ruby:3.3.14-slim-bookworm

RUN apt-get update -qq && apt-get install -y \
    build-essential libssl-dev libffi-dev zlib1g-dev libgmp-dev \
    git \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /gem

# Install bundler
RUN gem install bundler

# Copy gemspec and Gemfile first for better caching
COPY Gemfile ovh-http2sms.gemspec ./
COPY lib/ovh/http2sms/version.rb lib/ovh/http2sms/

# Install dependencies
RUN bundle install

# Copy the rest of the code
COPY . .

# Default command: interactive console
CMD ["bin/console"]
