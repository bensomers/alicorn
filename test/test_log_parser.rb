require 'helper'
require 'alicorn/log_parser'

class TestLogParser < Test::Unit::TestCase

  def setup
    @alp = Alicorn::LogParser.new("test/fixtures/sample.alicorn.log")
  end

  context "#parse" do
    should "correctly read log file" do
      expected = [ { :calling => DataSet.new([1,2,1]),
                     :writing => DataSet.new([2,1,2]),
                     :active  => DataSet.new([1,4,3]),
                     :queued  => DataSet.new([0,2,1]) },
                   { :calling => DataSet.new([11, 12, 11, 13, 14]),
                     :writing => DataSet.new([12, 11, 12, 14, 13]),
                     :active  => DataSet.new([11, 14, 13, 12, 11]),
                     :queued  => DataSet.new([10, 12, 11, 11, 12]) }
                 ]

      @alp.parse

      assert_equal 2, @alp.samples.count
      assert_equal expected, @alp.samples
    end
  end
end
