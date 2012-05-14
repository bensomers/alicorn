require 'curl'
require 'alicorn/dataset'

class Alicorn::Scaler
  attr_accessor :min_workers, :max_workers, :target_ratio, :buffer,
    :raindrops_url, :delay, :sample_count, :app_name, :master_pid,
    :worker_count

  def initialize(options)
    self.min_workers        = options[:min_workers]         || 1
    self.max_workers        = options[:max_workers]
    self.target_ratio       = options[:target_ratio]        || 1.3
    self.buffer             = options[:buffer]              || 0
    self.raindrops_url      = options[:url]                 || "http://127.0.0.1/_raindrops"
    self.delay              = options[:delay]               || 1
    self.sample_count       = options[:sample_count]        || 30
    self.app_name           = options[:app_name]            || "unicorn"
  end

  def scale!
    master_pid    = find_master_pid
    worker_count  = find_worker_count
    data          = collect_data

    # Calcualte target
    target = data[:active].max * target_ratio - buffer

    # Check hard thresholds
    target = max_workers if max_workers and worker_count > max_workers
    target = min_workers if worker_count < min_workers

    p "target calculated at: #{target}"
    if target > worker_count
      p "scaling up!"
      send_signal("TTIN")
    elsif target <= worker_count
      p "scaling down!"
      send_signal("TTOU")
    end
  end

private

  def find_master_pid
  end

  def find_worker_count
    14
  end

  def collect_data
    p "Sampling #{sample_count} times"
    calling, writing, active, queued = DataSet.new, DataSet.new, DataSet.new, DataSet.new
    sample_count.times do
      raindrops = get_raindrops(raindrops_url)
      calling << $1.to_i if raindrops.detect { |line| line.match(/calling: ([0-9]+)/) }
      writing << $1.to_i if raindrops.detect { |line| line.match(/writing: ([0-9]+)/) }
      active  << $1.to_i if raindrops.detect { |line| line.match(/active: ([0-9]+)/) }
      queued  << $1.to_i if raindrops.detect { |line| line.match(/queued: ([0-9]+)/) }
      sleep(delay)
    end
    p "Collected:"
    p "calling:#{calling}"
    p "calling avg:#{calling.avg}"
    p "calling stddev:#{calling.stddev}"
    p "writing:#{writing}"
    p "writing avg:#{writing.avg}"
    p "writing stddev:#{writing.stddev}"
    p "active:#{active}"
    p "active avg:#{active.avg}"
    p "active stddev:#{active.stddev}"
    p "queued:#{queued}"
    p "queued avg:#{queued.avg}"
    p "queued stddev:#{queued.stddev}"
    {:calling => calling, :writing => writing, :active => active, :queued => queued}
  end

  def get_raindrops(url)
    Curl::Easy.http_get(url).body_str.split("\n")
  end
  
  def send_signal(sig)
    return sig
    # Process.kill(sig, master_pid)
  end
end
