# Run this strict to simulate active WS clients.
#
# Runs 5 waves of 1000 clients interactive clients
# (each wave consists of 5 interlapping steps by 200 clients).
#
#    $ ruby simulate.rb
#
# See below for options.

# How much seconds wait before launching the next batch of clients within one step
WAIT = ENV.fetch("WAIT", 5).to_i
# How much seconds wait between wave
STEP_WAIT = ENV.fetch("STEP_WAIT", 20).to_i
# How many steps in one wave
STEP_SIZE = ENV.fetch("STEP_SIZE", 5).to_i
# How much clients to run at each step
SCALE = ENV.fetch("SCALE", 200).to_i
# Total number of waves
N = ENV.fetch("N", 5).to_i
# whether to request GC compact before each step
COMPACT = ENV["COMPACT"] == "1"

def step(num)
  step_start = Time.now

  workers = []

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
        puts "Run worker ##{id} (#{SCALE} connections). Attempt: #{retry_count + 1}"
        IO.popen("wsdirector features/simulate.yml 'ws://localhost:8080/cable' -s #{SCALE}", err: [:child, :out]) do |io|
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
  sleep STEP_WAIT
end

N.times { |i| step(i + 1) }

puts "Finished."
