ARG RUBY_VERSION=2.7.0-jemalloc

FROM quay.io/evl.ms/fullstaq-ruby:${RUBY_VERSION}-buster-slim

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
  build-essential \
  git \
  zlib1g-dev \
  liblzma-dev \
  libc++-dev \
  libgflags-dev libgtest-dev \
  autoconf libtool pkg-config \
  && rm -fr /var/cache/apt

# gRPC building deps
RUN apt-get update && apt-get install -qq -y --no-install-recommends \
  libc++-dev \
  libgflags-dev libgtest-dev \
  autoconf libtool pkg-config \
  && rm -fr /var/cache/apt
