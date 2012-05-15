#!/usr/bin/env ruby
$:.push File.join(File.dirname(__FILE__),'..','lib')
$:.push File.join(File.dirname(__FILE__),'..','script')

require 'alp'
require 'alicorn'

# Use these two variables to control the profiler
# The log file is the output of the sampling-mode alicorn
# The options are a stripped-down option set, including only
# the options that matter to the scaling algorithm.
@log_file = "/Users/bensomers/alicorn.log"
@options = { :min_workers => 4,
             :max_workers => 14,
             :target_ratio => 1.3,
             :buffer => 2,
             :debug => true}

@alp = AlicornLogParser.new(@log_file)
@alp.parse

scaler = Alicorn::Scaler.new(@options)
@worker_count = @options[:max_workers]

@alp.samples.each do |sample|
  if sample[:active].max > @worker_count
    p "Overloaded! Ran #{@worker_count} and got #{sample[:active].max} active"
  end
  sig = scaler.send(:auto_scale, sample, @worker_count)
  @worker_count += 1 if sig == "TTIN"
  @worker_count -= 1 if sig == "TTOU"
end
