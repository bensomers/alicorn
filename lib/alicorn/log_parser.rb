module Alicorn
  class LogParser
    attr_accessor :filename, :samples

    def initialize(file = "alicorn.log")
      self.filename = file
      self.samples  = []
    end
    
    def parse
      f = File.open(filename)
      f.each do |line|
       if line.match(/Sampling/)
          @sample_hash = {} # this will reset every sample
        elsif line.match(/calling:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          @sample_hash[:calling] = (DataSet.new << data).flatten
        elsif line.match(/writing:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          @sample_hash[:writing] = (DataSet.new << data).flatten
        elsif line.match(/active:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          @sample_hash[:active] = (DataSet.new << data).flatten
        elsif line.match(/queued:\[(.+)\]/)
          data = $1.split(", ").map(&:to_i)
          @sample_hash[:queued] = (DataSet.new << data).flatten
          samples << @sample_hash # store the old sample
        end
      end
      samples
    end
  end
end
