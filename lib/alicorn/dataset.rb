class DataSet < Array
  def avg
    inject(:+) / size.to_i
  end
end
