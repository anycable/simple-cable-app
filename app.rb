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
      p "Current thread: #{Thread.current.object_id}"
      self.id = SecureRandom.uuid
    end
  end
end

module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end

ActionCable.server.config.logger = Rails.logger
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
    sleep 1
    transmit data
  end

  def broadcast(data)
    ActionCable.server.broadcast "all", data
    data["action"] = "broadcastResult"
    transmit data
  end
end
