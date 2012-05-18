require 'helper'

class TestScaler < Test::Unit::TestCase

  def setup
    @scaler = Alicorn::Scaler.new(:delay => 0) # for test performance, all other defaults are fine
    class << @scaler
      def publicize(method)
        self.class.class_eval { public method }
      end
    end
  end

  context "#auto_scale" do
    setup do
      @scaler.publicize :auto_scale
      @data = {:a => "a"}
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
