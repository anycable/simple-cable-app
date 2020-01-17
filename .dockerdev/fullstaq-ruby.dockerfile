ARG RUBY_VERSION=2.7.0-jemalloc

FROM quay.io/evl.ms/fullstaq-ruby:${RUBY_VERSION}-buster-slim

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
  build-essential \
  git \
  zlib1g-dev \
  liblzma-dev \
  && rm -fr /var/cache/apt
