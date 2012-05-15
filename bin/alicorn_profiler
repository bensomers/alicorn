#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__),'..','lib')

require 'optparse'
require 'alicorn'
require 'alicorn/log_parser'


options = {}
OptionParser.new do |opts|
  opts.banner = "Alicorn Profiler is a profiling tool to use for determining
optimal settings to run alicorn at. First, run the scaler in dry-run mode
to collect statistics about your application load. Then pull that log file
and feed it into this profiler. Experiment with the options until you find
settings that work well for you. Be aware that occasional 'Overloaded!' 
situations are not necessarily bad; they just result in requests getting 
queued. \n\nUsage: alicorn [options]"
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end

  opts.on("--min-workers N", Integer, "the minimum number of workers to scale down to") do |v|
    options[:min_workers] = v
  end

  opts.on("--max-workers N", Integer, "the maximum number of workers to scale up to") do |v|
    options[:max_workers] = v
  end

  opts.on("--buffer N", Integer, "the number of extra workers to keep for safety's sake") do |v|
    options[:buffer] = v
  end

  opts.on("--target-ratio F", Float, "the desired ratio of workers to busy workers") do |v|
    options[:target_ratio] = v
  end

  opts.on("--log-path PATH", String, "location of the alicorn log file to read") do |v|
    options[:log_path] = v
  end
end.parse!

# Use these two variables to control the profiler
# The log file is the output of the sampling-mode alicorn
# The options are a stripped-down option set, including only
# the options that matter to the scaling algorithm.
@log_file = options[:log_path]
@options = { :min_workers => options[:min_workers],
             :max_workers => options[:max_workers],
             :target_ratio => options[:target_ration],
             :buffer => options[:buffer],
             :debug => true,
             :dry_run => true}

@alp = Alicorn::LogParser.new(@log_file)
@alp.parse

scaler = Alicorn::Scaler.new(@options)
@worker_count = @options[:max_workers]

p "Testing #{@alp.samples.count} samples"
@alp.samples.each do |sample|
  if sample[:active].max > @worker_count
    p "Overloaded! Ran #{@worker_count} and got #{sample[:active].max} active"
  end
  sig = scaler.send(:auto_scale, sample, @worker_count)
  @worker_count += 1 if sig == "TTIN"
  @worker_count -= 1 if sig == "TTOU"
end
