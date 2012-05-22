require 'alicorn/log_parser'

module Alicorn
  class Profiler
    attr_accessor :log_path, :min_workers, :max_workers, :target_ratio, :buffer,
      :worker_count, :verbose, :out

    def initialize(options = {})
      @log_path     = options[:log_path]
      @min_workers  = options[:min_workers]
      @max_workers  = options[:max_workers]
      @target_ratio = options[:target_ratio]
      @buffer       = options[:buffer]
      @verbose      = options.delete(:verbose)

      @out          = options[:test] ? File.open("/dev/null") : STDOUT
      @worker_count = @max_workers
      @scaler = Scaler.new(options.merge(:log_path => nil))
      @alp    = LogParser.new(@log_path)
    end

    def profile
      samples = @alp.parse
      @out.puts "Profiling #{samples.count} samples"

      samples.each do |sample|
        connections = sample[:active].zip(sample[:queued]).map { |e| e.inject(:+) }
        if connections.max > @worker_count
          @out.puts "Overloaded! Ran #{@worker_count} and got #{connections.max} active + queued"
          @out.puts sample if @verbose
        end
        sig, count = @scaler.auto_scale(sample, @worker_count)
        @worker_count += count if sig == "TTIN"
        @worker_count -= count if sig == "TTOU"
      end
    end
  end
end
