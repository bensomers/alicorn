class DataSet < Array
  def avg
    return 0 if empty?
    inject(:+) / size.to_i
  end
end
