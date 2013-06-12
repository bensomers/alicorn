module Alicorn
  class LogParser
    attr_accessor :filename, :samples

    SAMPLE_REGEX = /(?<sample_type>active|queued|calling|writing):\[(?<values>.+)\]/

    def initialize(file = "alicorn.log")
      self.filename = file
      self.samples  = []
    end
    
    def parse
      f = File.open(filename)
      f.each do |line|
        sample_line(line)
      end
      samples
    end

  private

    # Not suitable for calling in isolation, since an actual data sample
    # spans 5 lines in the log file. This method checks for lines indicating
    # either the beginning or end of a sample, or for data lines in the middle.
    def sample_line(line)
      if line.match(/Sampling/)
        @sample_hash = {} # reset for the new sample
      elsif match_result = line.match(SAMPLE_REGEX)
        data = match_result[:values].split(", ").map(&:to_i)
        @sample_hash[match_result[:sample_type].to_sym] = (DataSet.new << data).flatten
      elsif line.match(/target calculated at:/)
        samples << @sample_hash # store the old sample
      end
    end

  end
end
