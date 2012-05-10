require 'curl'

class Alicorn
  attr_accessor :min_workers, :max_workers, :upward_step_size, 
    :downward_step_size, :raindrops_url, :delay, :sample_count, :app_name,
    :master_pid, :worker_count, :calling, :writing, :active, :queued

  def initialize(options)
    self.min_workers        = options[:min_workers]         || 1
    self.max_workers        = options[:max_workers]
    self.upward_step_size   = options[:upward_step_size]    || 1
    self.downward_step_size = options[:downward_step_size]  || 1
    self.raindrops_url      = options[:url]                 || "http://127.0.0.1/_raindrops"
    self.delay              = options[:delay]               || 1
    self.sample_count       = options[:sample_count]        || 30
    self.app_name           = options[:app_name]            || "unicorn"
    self.master_pid         = find_master_pid(app_name)
    self.worker_count       = find_worker_count(app_name)
    self.calling, self.writing, self.active, self.queued = [], [], [], []
  end

  def scale!
    collect_data
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
    p "writing:#{writing}"
    p "active:#{active}"
    p "queued:#{queued}"
  end

  def get_raindrops(url)
    Curl::Easy.http_get(url).body_str.split("\n")
  end
  
  def send_signal(sig)
  end
end
