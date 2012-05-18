module Alicorn
  class LogParser
    attr_accessor :filename, :samples, :calling, :active, :queued, :calling_avg, :active_avg, :queued_avg

    def initialize(file = "alicorn.log")
      self.filename = file
      self.samples, self.calling, self.active, self.queued, self.calling_avg, self.active_avg, self.queued_avg = [], [], [], [], [], [], []
    end
    
    def parse
      f = File.open(filename)
      f.each do |line|
        if line.match(/Sampling/)
          @sample_hash = {} # this will reset every sample
        elsif line.match(/calling:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          calling << data
          @sample_hash[:calling] = data
        elsif line.match(/calling avg:([\d]+)/)
          data = $1.to_i
          calling_avg << data
          @sample_hash[:calling_avg] = data
        elsif line.match(/active:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          active << data
          @sample_hash[:active] = data
        elsif line.match(/active avg:([\d]+)/)
          data = $1.to_i
          active_avg << data
          @sample_hash[:active_avg] = data
          samples << @sample_hash
        end
      end
    end
  end
end
