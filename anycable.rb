# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'production'

require_relative "app"

ActionCable.server.config.cable = { "adapter" => "any_cable" }

Rails.application.initialize!

if ENV["OBJECT_TRACE"] == "1"
  require_relative "./memprof"

  ANYCABLE_SOURCES = /(anycable|grpc|protobuf)/

  def start_trace
    puts "Start allocation tracing\n"
    Memprof.start
  end

  def print_trace
    puts "Print allocation tracing\nTotal clients connected after warmup: #{COUNTER.value - WARMUP_COUNT}"

    Memprof.report(mapping: { action_cable: ACTIONCABLE_SOURCES, anycable: ANYCABLE_SOURCES, other: /.*/ }, ignore: [])
  end

  class ProfilerInterceptor < AnyCable::Middleware
    def call(request, call, method)
      return super unless request.is_a?(Anycable::ConnectionRequest)
      COUNTER.increment

      response = yield

      start_trace if COUNTER.value == WARMUP_COUNT
      val = COUNTER.value
      if val > WARMUP_COUNT && ((val - WARMUP_COUNT) % TRACE_INTERVAL) == 0
        print_trace
        COUNTER.value = 0
      end
      response
    end
  end

  AnyCable.middleware.use(ProfilerInterceptor)
end
