require 'curl'
require 'alicorn/dataset'

class Alicorn::Scaler
  attr_accessor :min_workers, :max_workers, :upward_step_size, 
    :downward_step_size, :upward_threshold, :downward_threshold, :raindrops_url, 
    :delay, :sample_count, :app_name, :master_pid, :worker_count, :calling, 
    :writing, :active, :queued

  def initialize(options)
    self.min_workers        = options[:min_workers]         || 1
    self.max_workers        = options[:max_workers]
    self.upward_threshold   = options[:upward_threshold]
    self.downward_threshold = options[:downward_threshold]
    self.upward_step_size   = options[:upward_step_size]    || 1
    self.downward_step_size = options[:downward_step_size]  || 1
    self.raindrops_url      = options[:url]                 || "http://127.0.0.1/_raindrops"
    self.delay              = options[:delay]               || 1
    self.sample_count       = options[:sample_count]        || 30
    self.app_name           = options[:app_name]            || "unicorn"
    self.master_pid         = find_master_pid(app_name)
    self.worker_count       = find_worker_count(app_name)
    self.calling            = DataSet.new
    self.writing            = DataSet.new
    self.active             = DataSet.new
    self.queued             = DataSet.new
  end

  def scale!
    collect_data
    upscale or downscale
  end

protected

  # planned algorithm: maintain worker count at 1.3*active
  def upscale
    # return false if worker_count >= max_workers
    # return false if calling.all? { |sample| sample == 0 }
  end

  def downscale
    # return false if worker_count <= min_workers
  end

private

  def find_master_pid(app_name)
  end

  def find_worker_count(app_name)
  end

  def collect_data
    p "Sampling #{sample_count} times"
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
  end

  def get_raindrops(url)
    Curl::Easy.http_get(url).body_str.split("\n")
  end
  
  def send_signal(sig)
    Process.kill(sig, master_pid)
  end
end
