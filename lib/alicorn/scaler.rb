require 'curl'
require 'logger'
require 'alicorn/dataset'

module Alicorn
  class Scaler
    attr_accessor :min_workers, :max_workers, :target_ratio, :buffer,
      :raindrops_url, :delay, :sample_count, :app_name, :dry_run,
      :master_pid, :worker_count, :logger

    def initialize(options)
      self.min_workers        = options[:min_workers]         || 1
      self.max_workers        = options[:max_workers]
      self.target_ratio       = options[:target_ratio]        || 1.3
      self.buffer             = options[:buffer]              || 0
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
      master_pid    = find_master_pid
      worker_count  = find_worker_count
      data          = collect_data

      sig = auto_scale(data, worker_count)
      send_signal(sig) if sig
    end

  protected

    def auto_scale(data, worker_count)
      # Calculate target
      target = data[:active].max * target_ratio + buffer

      # Check hard thresholds
      target = max_workers if max_workers and target > max_workers
      target = min_workers if target < min_workers
      target = target.ceil

      logger.debug "target calculated at: #{target}, worker count at #{worker_count}"
      if target > worker_count
        logger.debug "scaling up!" unless dry_run
        return "TTIN"
      elsif target < worker_count
        logger.debug "scaling down!" unless dry_run
        return "TTOU"
      end
    end

    def find_master_pid
    end

    def find_worker_count
      14
    end

  private

    def collect_data
      logger.debug "Sampling #{sample_count} times at #{Time.now}"
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

    def get_raindrops(url)
      Curl::Easy.http_get(url).body_str.split("\n")
    end
    
    def send_signal(sig)
      return false if dry_run
      return sig
      # Process.kill(sig, master_pid)
    end
  end
end
