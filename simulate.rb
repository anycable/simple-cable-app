# Run this strict to simulate active WS clients.
#
# Runs 5 waves of 1000 clients interactive clients
# (each wave consists of 5 interlapping steps by 200 clients).
#
#    $ ruby simulate.rb
#
# See below for options.

# Scenario to run
SCENARIO = ENV.fetch("SCENARIO", "features/simulate.yml")
# How much seconds wait before launching the next batch of clients within one step
WAIT = ENV.fetch("WAIT", 5).to_i
# How much seconds wait between wave
STEP_WAIT = ENV.fetch("STEP_WAIT", 20).to_i
# How many steps in one wave
STEP_SIZE = ENV.fetch("STEP_SIZE", 5).to_i

def parse_scale(scale)
  return unless scale
  scale.split(",").map(&:to_i)
end

# How much clients to run at each step
SCALE = parse_scale(ENV["SCALE"]) || [200]
# Total number of waves
N = ENV.fetch("N", 5).to_i
# whether to request GC compact before each step
COMPACT = ENV["COMPACT"] == "1"
# ID of the docker container to monitor memory usage
DOCKER_ID = ENV["DOCKER"]

def step(num)
  step_start = Time.now

  workers = []
  scale = SCALE.size == 1 ? SCALE.first : SCALE.shift

  if COMPACT
    print "Requesting GC.compact..."
    system("wsdirector features/connect.yml 'ws://localhost:8080/cable?compact=1' -s 1").then do |res|
      puts " #{res ? 'OK' : 'Failed ‼️'}"
    end
  end

  loop do
    id = workers.size + 1
    workers << Thread.new {
      start = Time.now
      retry_count = 0
      begin
        puts "Run worker ##{id} (#{scale} connections). Attempt: #{retry_count + 1}"
        IO.popen("wsdirector #{SCENARIO} 'ws://localhost:8080/cable' -s #{scale}", err: [:child, :out]) do |io|
          raise "Worker failed due to broker pipe" if io.read.include?("Broken pipe")
        end
      rescue => err
        retry_count += 1
        raise if retry_count > 5
        puts "💥 Worker failed: #{err}. Retry in 5s"
        sleep 5
        retry
      end
      puts "Worker ##{id} is done (#{Time.now - start}s)"
    }
    sleep WAIT
    break if workers.size == STEP_SIZE
  end

  workers.map(&:join)
  puts "Step #{num} finished in #{Time.now - step_start}s. Wait for #{STEP_WAIT}s"
  sleep STEP_WAIT unless num == N
end

def monitor_docker(id)
  report = {stopped: false, data: []}
  Thread.new do
    IO.popen("docker stats #{id} --format='{{.MemUsage}}' 2> /dev/null") do |io|
      while line = io.gets
        break if report[:stopped]
        report[:data] << line.match(/([\.\d]+)MiB/)[1].to_f
      end
    end
  end
  report
end

mem_report =
  if DOCKER_ID
    monitor_docker(DOCKER_ID)
  end

N.times { |i| step(i + 1) }

puts "Finished."

return unless mem_report

mem_report[:stopped] = true

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  gem 'unicode_plot'
end

require 'unicode_plot'

plot = UnicodePlot.lineplot(mem_report[:data], name: "MiB", width: 100, height: 20, color: :red)
plot.render
