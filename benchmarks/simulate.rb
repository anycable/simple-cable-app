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
# How much seconds to wait before launching the next wave of clients
WAIT = ENV.fetch("WAIT", 10).to_i
# The number of concurrent waves
N = ENV.fetch("N", 3).to_i
# The total number of waves to run
TOTAL = ENV.fetch("TOTAL", 10).to_i
# How many broadcasts to perform (percents)
SAMPLE = ENV.fetch("SAMPLE", 10).to_i
# Enable debug output
DEBUG = ENV["DEBUG"] == "1"
# How many clients to run at each wave run (cycling through the array of values)
SCALE = ENV.fetch("SCALE", "100").split(",").map(&:to_i)
# wsdirector clients synchronization timeout
SYNC_TIMEOUT = ENV.fetch("SYNC_TIMEOUT", 10)
# Whether to request GC compact after each wave
COMPACT = ENV["COMPACT"] == "1"
# Whether to request GC compact once a specified number of waves
# when no waves are active
COMPACT_IDLE = ENV.fetch("COMPACT_IDLE", 0).to_i

Dir.chdir File.join(__dir__, "..")

def log(msg)
  puts "[#{Time.now}]\t#{msg}"
end

if DEBUG
  def debug(msg)
    log(msg)
  end
else
  def debug(_); end
end

log "Running simulation (#{SCENARIO}) #{TOTAL} times with #{N} concurrent waves and #{WAIT}s delay"

def compact!
  log "Requesting GC.compact..."
  system("wsdirector features/connect.yml 'ws://#{HOST}:8080/cable?compact=1' -s 1").then do |res|
    debug "GC.compact status: #{res ? 'OK' : 'Failed ‼️'}"
  end
end

if COMPACT
  def maybe_compact
    compact!
  end
else
  def maybe_compact; end
end

WEBSOCKET_DIRECTOR_CMD = "SAMPLE=%<sample>d TEST_ID=%<id>d " \
                         "wsdirector %<scenario>s '%<url>s' " \
                         "-s %<scale>d -t #{SYNC_TIMEOUT}"

def run_websocket_director(id, scale)
  run_cmd(format(WEBSOCKET_DIRECTOR_CMD, url: "ws://#{HOST}:8080/cable", sample: SAMPLE, scale: scale, id: id, scenario: SCENARIO)) do |io|
    output = io.read
    debug "Output for ##{id}: #{output}"
    raise "Worker failed due to broken pipe" if output.include?("Broken pipe")
  end
end

def run_cmd(cmd, &block)
  debug "Run #{cmd}"
  IO.popen(cmd, err: [:child, :out], &block)
end

task_queue = Queue.new
result_queue = Queue.new

if COMPACT_IDLE > 0
  log "Start compactor"
  compactor_fib = Fiber.new do
    loop do
      log "Compaction is pending..."

      loop do
        sleep 1
        # all workers are idle
        break if task_queue.num_waiting == N
      end

      compact!

      Fiber.yield
    end
  end
end

N.times do |id|
  Thread.new do
    scales = SCALE.dup.cycle

    loop do
      # wait for a new task
      task_queue.pop

      scale = scales.next
      start = Time.now

      retry_count = 0
      begin
        debug "Run worker ##{id} (scale: #{scale}). Attempt: #{retry_count + 1}"
        run_websocket_director(id, scale)
      rescue => err
        retry_count += 1
        raise if retry_count > 5
        log "💥 Worker failed: #{err}. Retry in 5s"
        sleep 5
        retry
      end

      debug "Worker ##{id} is done: #{$?} (#{Time.now - start}s)"

      maybe_compact

      result_queue.push(true)
    end
  end
end

deadline = Time.now + WAIT
completed = 0

N.times do
  task_queue.push(true)
  sleep WAIT
end

loop do
  result_queue.pop

  completed += 1

  log "Finished #{completed} out of #{TOTAL}."

  compactor_fib.resume if COMPACT_IDLE > 0 && (completed % COMPACT_IDLE) == 0

  break if completed == TOTAL

  wait = deadline - Time.now

  sleep(wait) if wait > 0

  deadline = Time.now + WAIT

  task_queue.push(true)
end

