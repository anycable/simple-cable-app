require "objspace"

module Memprof
  include ObjectSpace

  def gc_start
    GC.start;GC.start;GC.start
  end

  def print_rss
    puts "RSS: #{`ps -o rss= -p #{Process.pid}`.to_i}KB"
  end

  def start
    trace_object_allocations_clear
    trace_object_allocations_start
  end

  def report(mapping:, ignore: [])
    gc_start

    print_rss
    results = Hash.new { |h, k| h[k] = { type: k, count: 0, memsize: 0 } }

    hit = 0
    match = 0
    miss = 0

    each_object do |obj|
      next if ignore.detect { |ignored_class| obj.is_a?(ignored_class) }

      path = allocation_sourcefile(obj)

      # created before allocation started
      if path.nil?
        miss += 1
        next
      end

      hit += 1

      mapping.each do |type, pattern|
        next unless path.match?(pattern)

        debug(type, obj) if ENV["MEMPROF_VERBOSE"]

        results[type][:count] += 1
        results[type][:memsize] += memsize_of(obj)

        match += 1
        break
      end
    end

    trace_object_allocations_clear

    puts "TOTAL: #{miss + hit}\nMISS: #{miss}\nHIT:#{hit}\nMATCH:#{match}"


    puts format("%15s\t\t%15s\t\t%15s\n", *%w(type count memsize))
    
    total_count = 0
    total_memsize = 0

    results.each do |_, res|
      puts format("%15s\t\t%15d\t\t%15d\n", res[:type], res[:count], res[:memsize])

      total_count += res[:count]
      total_memsize += res[:memsize]
    end

    puts format("\n%15s\t\t%15d\t\t%15d\n", "__total__", total_count, total_memsize)

    nil
  end

  def debug(type, obj)
    path = allocation_sourcefile(obj)
    line = allocation_sourceline(obj)
    class_path = allocation_class_path(obj)
    method_id = allocation_method_id(obj)
    memsize = memsize_of(obj)

    puts "OBJECT type=#{type} class=#{obj.class} class_path=#{class_path} method_id=#{method_id} path=#{path} line=#{line} memsize=#{memsize}"
  end

  extend self
end
