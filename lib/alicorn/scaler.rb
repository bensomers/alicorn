require 'curl'
require 'logger'
require 'alicorn/dataset'

module Alicorn
  class Scaler
    attr_accessor :min_workers, :max_workers, :target_ratio, :buffer,
      :raindrops_url, :delay, :sample_count, :app_name, :dry_run, :logger

    def initialize(options = {})
      raise ArgumentError.new("You must pass a :max_workers option") unless options[:max_workers]

      self.min_workers        = options[:min_workers]         || 1
      self.max_workers        = options[:max_workers]
      self.target_ratio       = options[:target_ratio]        || 1.3
      self.buffer             = options[:buffer]              || 2
      self.raindrops_url      = options[:url]                 || "http://127.0.0.1/_raindrops"
      self.delay              = options[:delay]               || 1
      self.sample_count       = options[:sample_count]        || 30
      self.app_name           = options[:app_name]            || "unicorn"
      self.dry_run            = options[:dry_run]
      log_path                = options[:log_path]            || "/dev/null"

      self.logger = Logger.new(log_path)
      logger.level = options[:verbose] ? Logger::DEBUG : Logger::WARN
    end

    def scale!
      data          = collect_data
      unicorns      = find_unicorns
      master_pid    = find_master_pid(unicorns)
      worker_count  = find_worker_count(unicorns)

      sig, number = auto_scale(data, worker_count)
      if sig and !dry_run
        number.times do
          send_signal(master_pid, sig) 
          sleep(1) # Make sure unicorn doesn't discard repeated signals
        end
      end
    end

  protected

    def auto_scale(data, worker_count)
      return nil if data[:active].empty?

      # Calculate target
      target = data[:active].max * target_ratio + buffer

      # Check hard thresholds
      target = max_workers if max_workers and target > max_workers
      target = min_workers if target < min_workers
      target = target.ceil

      logger.debug "target calculated at: #{target}, worker count at #{worker_count}"
      if data[:active].avg > worker_count and data[:queued].avg > 1
        logger.debug "danger, will robinson! scaling up fast!"
        return "TTIN", target - worker_count
      elsif target > worker_count
        logger.debug "scaling up!"
        return "TTIN", 1
      elsif target < worker_count
        logger.debug "scaling down!"
        return "TTOU", 1
      elsif target == worker_count
        logger.debug "just right!"
        return nil, 0
      end
    end

    def find_master_pid(unicorns)
      master_lines = unicorns.select { |line| line.match /master/ }
      if master_lines.size > 1
        abort "Too many unicorn master processes detected. You may be restarting, or have an app name collision: #{master_lines}"
      elsif master_lines.first.match /\(old\)/
        abort "Old master process detected. You may be restarting: #{master_lines.first}"
      else
        master_lines.first.split.first
      end
    end

    def find_worker_count(unicorns)
      unicorns.select { |line| line.match /worker\[[\d]\]/ }.count
    end

    def find_unicorns
      ptable = %x(ps ax).split("\n")
      unicorns = ptable.select { |line| line.match(/unicorn/) && line.match(/#{Regexp.escape(app_name)}/) }
      unicorns.map(&:strip)
    end


    def collect_data
      logger.debug "Sampling #{sample_count} times"
      calling, writing, active, queued = DataSet.new, DataSet.new, DataSet.new, DataSet.new
      sample_count.times do
        raindrops = get_raindrops(raindrops_url)
        calling << $1.to_i if raindrops.detect { |line| line.match(/calling: ([0-9]+)/) }
        writing << $1.to_i if raindrops.detect { |line| line.match(/writing: ([0-9]+)/) }
        active  << $1.to_i if raindrops.detect { |line| line.match(/active: ([0-9]+)/) }
        queued  << $1.to_i if raindrops.detect { |line| line.match(/queued: ([0-9]+)/) }
        sleep(delay)
      end

      logger.debug "Collected:"
      logger.debug "calling:#{calling}"
      logger.debug "calling avg:#{calling.avg}"
      logger.debug "calling stddev:#{calling.stddev}"
      logger.debug "writing:#{writing}"
      logger.debug "writing avg:#{writing.avg}"
      logger.debug "writing stddev:#{writing.stddev}"
      logger.debug "active:#{active}"
      logger.debug "active avg:#{active.avg}"
      logger.debug "active stddev:#{active.stddev}"
      logger.debug "queued:#{queued}"
      logger.debug "queued avg:#{queued.avg}"
      logger.debug "queued stddev:#{queued.stddev}"

      {:calling => calling, :writing => writing, :active => active, :queued => queued}
    end

    def send_signal(master_pid, sig)
      Process.kill(sig, master_pid)
    end

private

    def get_raindrops(url)
      Curl::Easy.http_get(url).body_str.split("\n")
    end
    
  end
end
