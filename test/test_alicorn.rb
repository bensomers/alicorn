require 'helper'

class TestScaler < Test::Unit::TestCase

  def setup
    @scaler = Alicorn::Scaler.new(:delay => 0)
    class << @scaler
      def publicize(method)
        self.class.class_eval { public method }
      end
    end
  end

  context "#auto_scale" do
    setup do
      @scaler.publicize :auto_scale
      @worker_count = 10
      @scaler.min_workers = 1
      @scaler.max_workers = 25
      @scaler.buffer = 2
      @scaler.target_ratio = 1.3
      @data = { :active => DataSet.new }
    end

    context "when we're above the target" do
      setup do
        @data[:active] << 3 << 4 << 5
      end

      should "return 1 TTOU" do
        assert_equal ["TTOU", 1], @scaler.auto_scale(@data, @worker_count)
      end
    end

    context "when we're below the target" do
      setup do
        @data[:active] << 2 << 10
      end

      should "return 1 TTIN" do
        assert_equal ["TTIN", 1], @scaler.auto_scale(@data, @worker_count)
      end
    end

    context "when we need to scale up fast" do
      setup do
        @data[:active] << 12
      end

      should "return several TTIN" do
        assert_equal ["TTIN", 8], @scaler.auto_scale(@data, @worker_count)
      end
    end

    context "when we don't need to scale at all" do
      setup do
        @data[:active] << 6
      end

      should "return several TTIN" do
        assert_equal [nil, 0], @scaler.auto_scale(@data, @worker_count)
      end
    end

  end

  context "#collect_data" do
    setup do
      @scaler.publicize :collect_data
      raindrops = "calling: 3\nwriting: 1\n/tmp/cart.socket active: 4\n/tmp/cart.socket queued: 0\n"
      Curl::Easy.stubs(:http_get).returns(stub(:body_str => raindrops))
    end

    should "return the correct data" do
      data = @scaler.collect_data
      expected_data = { :calling => [3]*30,
                        :writing => [1]*30,
                        :active  => [4]*30,
                        :queued  => [0]*30 }
      assert_equal expected_data, data
    end
  end

end
