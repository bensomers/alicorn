require 'raindrops'
require 'logger'
require 'alicorn/dataset'
require 'alicorn/errors'

module Alicorn
  class Scaler
    attr_accessor :min_workers, :max_workers, :target_ratio, :buffer,
      :listener_type, :listener_address, :delay, :sample_count, :app_name,
      :dry_run, :logger

    attr_reader :signal_delay

    def initialize(options = {})
      @min_workers        = options[:min_workers]         || 1
      @max_workers        = options[:max_workers]
      @target_ratio       = options[:target_ratio]        || 1.3
      @buffer             = options[:buffer]              || 2
      @listener_type      = options[:listener_type]       || "tcp"
      @listener_address   = options[:listener_address]    || "0.0.0.0:80"
      @delay              = options[:delay]               || 1
      @sample_count       = options[:sample_count]        || 30
      @app_name           = options[:app_name]            || "unicorn"
      @dry_run            = options[:dry_run]
      @signal_delay       = 0.5
      log_path            = options[:log_path]            || "/dev/null"

      self.logger = Logger.new(log_path)
      logger.level = options[:verbose] ? Logger::DEBUG : Logger::WARN
    end

    def scale
      data          = collect_data
      unicorns      = find_unicorns

      master_pid    = find_master_pid(unicorns)
      worker_count  = find_worker_count(unicorns)

      sig, number = auto_scale(data, worker_count)
      if sig and !dry_run
        number.times do
          send_signal(master_pid, sig) 
          sleep(signal_delay) # Make sure unicorn doesn't discard repeated signals
        end
      end
    rescue StandardError => e
      logger.error "exception occurred: #{e.class}\n\n#{e.message}"
      raise e unless e.is_a?(AmbiguousMasterError) or e.is_a?(NoMasterError) # Master-related errors are fine, usually just indicate a start or restart
    end

    def auto_scale(data, worker_count)
      return nil if data[:active].empty? or data[:queued].empty?
      connections = data[:active].zip(data[:queued]).map { |e| e.inject(:+) }
      connections = DataSet.new(connections)

      # Calculate target
      target = connections.max * target_ratio + buffer

      # Check hard thresholds
      target = max_workers if max_workers and target > max_workers
      target = min_workers if target < min_workers
      target = target.ceil

      logger.debug "target calculated at: #{target}, worker count at #{worker_count}"
      if worker_count == max_workers and target == max_workers
        logger.warn "at maximum capacity! cannot scale up"
        return nil, 0
      elsif connections.avg > worker_count and data[:queued].avg > 1
        logger.warn "danger, will robinson! scaling up fast!"
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

  protected

    def collect_data
      logger.debug "Sampling #{listener_type} listener at #{listener_address} #{sample_count} times at #{delay} second intervals"
      active, queued = DataSet.new, DataSet.new
      sample_count.times do
        stats = Raindrops::Linux.send(:"#{listener_type}_listener_stats")[listener_address]
        active << stats.active
        queued << stats.queued
        sleep(delay)
      end

      logger.debug "Collected:"
      logger.debug "active:#{active}"
      logger.debug "queued:#{queued}"

      {:active => active, :queued => queued}
    end

  private

    # Raises errors if the master is busy restarting, or we can't be certain which PID to signal
    def find_master_pid(unicorns)
      master_lines = unicorns.select { |line| line.match /master/ }
      if master_lines.size == 0
        raise NoMasterError.new("No unicorn master processes detected. You may still be starting up.")
      elsif master_lines.size > 1
        raise AmbiguousMasterError.new("Too many unicorn master processes detected. You may be restarting, or have an app name collision: #{master_lines}")
      elsif master_lines.first.match /\(old\)/
        raise AmbiguousMasterError.new("Old master process detected. You may be restarting: #{master_lines.first}")
      else
        master_lines.first.split.first.to_i
      end
    end

    def find_worker_count(unicorns)
      unicorns.select { |line| line.match /worker\[[\d]+\]/ }.count
    end

    def find_unicorns
      ptable = grep_process_list.split("\n")
      unicorns = ptable.select { |line| line.match(/unicorn/) && line.match(/#{Regexp.escape(app_name)}/) }
      raise NoUnicornsError.new("Could not find any unicorn processes") if unicorns.empty?

      unicorns.map(&:strip)
    end

    def grep_process_list
      %x(ps ax)
    end

    def send_signal(master_pid, sig)
      Process.kill(sig, master_pid)
    end
  end
end
