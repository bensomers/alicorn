class DataSet < Array
  def avg
    inject(:+) / size.to_i
  end

  def variance
    sum=self.inject(0){|acc,i|acc +(i-avg)**2}
    return(1/self.length.to_f*sum)
  end

  def stddev
    Math.sqrt(self.variance)
  end
end
