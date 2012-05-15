class DataSet < Array
  def avg
    return nil if empty?
    inject(:+) / size.to_i
  end

  def variance
    return nil if empty?
    sum=self.inject(0){|acc,i|acc +(i-avg)**2}
    return(1/self.length.to_f*sum)
  end

  def stddev
    return nil if empty?
    Math.sqrt(self.variance)
  end
end
