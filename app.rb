# frozen_string_literal: true

# rubocop:disable all

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

require "rails"
require "global_id"

require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"

require "redis"
require "anycable-rails" if ENV['USE_ANYCABLE']

class TestApp < Rails::Application
  secrets.secret_token    = "secret_token"
  secrets.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)
  config.log_level = :info
  config.eager_load = true

  initializer "routes" do
    Rails.application.routes.draw do
      mount ActionCable.server => "/cable"
    end
  end
end

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :id

    def connect
      self.id = SecureRandom.uuid
    end
  end
end

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end

Rails.logger = ActionCable.server.config.logger = Logger.new(IO::NULL).tap { |logger| logger.level = :fatal }
ActionCable.server.config.cable = { "adapter" => "redis" }
ActionCable.server.config.connection_class = -> { ApplicationCable::Connection }
ActionCable.server.config.disable_request_forgery_protection = true

class DemoChannel < ApplicationCable::Channel
  def subscribed
    stream_from "demo"
  end
end

class BenchmarkChannel < ApplicationCable::Channel
  def subscribed
    stream_from "all"
  end

  def echo(data)
    transmit data
  end

  def broadcast(data)
    ActionCable.server.broadcast "all", data
    data["action"] = "broadcastResult"
    transmit data
  end
end

if ENV["OBJECT_TRACE"]
  require_relative "./memprof"

  WARMUP_COUNT = 200

  TRACE_INTERVAL = (ENV['TRACE'] || 10).to_i

  COUNTER = Concurrent::AtomicFixnum.new(0)

  ACTIONCABLE_SOURCES = /\/(actioncable|active_support|action_dispatch|concurrent)/
  WEBSOCKET_SOURCES = /\/websocket\-/

  def start_trace
    puts "Start allocation tracing\n"
    Memprof.start
  end

  def print_trace
    puts "Print allocation tracing\nTotal clients connected after warmup: #{COUNTER.value - WARMUP_COUNT}"

    Memprof.report(mapping: { action_cable: ACTIONCABLE_SOURCES, websocket: WEBSOCKET_SOURCES, other: /.*/ }, ignore: [Thread])
  end

  ActionCable::Connection::Base.prepend(Module.new do
    def respond_to_successful_request
      res = super
      COUNTER.increment
      start_trace if COUNTER.value == WARMUP_COUNT
      val = COUNTER.value
      if val > WARMUP_COUNT && ((val - WARMUP_COUNT) % TRACE_INTERVAL) == 0
        print_trace
        start_trace
      end
      res
    end
  end)
end