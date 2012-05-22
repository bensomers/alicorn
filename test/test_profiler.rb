require 'helper'
require 'alicorn/profiler'

class TestProfiler < Test::Unit::TestCase

  def setup
    @prof = Alicorn::Profiler.new(:log_path     => "test/fixtures/sample.alicorn.log",
                                  :min_workers  => 2,
                                  :max_workers  => 10,
                                  :target_ratio => 1.3,
                                  :buffer       => 1,
                                  :test         => true)
    @out = StringIO.new
    @prof.out = @out
  end

  context "#profile" do
    should "simulate real-world alicorn runs" do
      Alicorn::Scaler.any_instance.stubs(:auto_scale).returns(["TTIN", 1], ["TTOU", 3])
      @out.expects(:puts).with("Profiling 2 samples")
      @out.expects(:puts).with { |string| string.match /Overloaded! Ran 11 and got 26/ }

      @prof.profile
      assert_equal 8, @prof.worker_count
    end
  end
  
end
