require 'helper'

class TestScaler < Test::Unit::TestCase

  def setup
    @scaler = Alicorn::Scaler.new(:delay => 0)

    # stub out external call
    raindrops = "calling: 3\nwriting: 1\n/tmp/cart.socket active: 4\n/tmp/cart.socket queued: 0\n"
    Curl::Easy.stubs(:http_get).returns(stub(:body_str => raindrops))

    # enable us to test private methods, for the complicated ones
    class << @scaler
      def publicize(*methods)
        methods.each do |meth|
          self.class.class_eval { public meth }
        end
      end
    end
  end

  context "#scale" do
    context "when no unicorn processes are running" do
      setup do
        @scaler.stubs(:grep_process_list).returns("foo\nbar")
      end

      should "raise an error" do
        exception = assert_raise(RuntimeError) do
          @scaler.scale
        end
        assert_equal "Could not find any unicorn processes", exception.message
      end
    end

    context "when no master processes are running" do
      setup do
        plist = "1050 ?  Sl  1:06 unicorn_rails worker[0] -c first_unicorn.rb -E staging -D\n 
                 1051 ?  Sl  1:06 unicorn_rails worker[1] -c other_unicorn.rb -E staging -D\n"
        @scaler.stubs(:grep_process_list).returns(plist)
      end

      should "raise an error" do
        exception = assert_raise(RuntimeError) do
          @scaler.scale
        end
        assert_match /No unicorn master processes/, exception.message
      end
    end

    context "when multiple master processes are found" do
      setup do
        plist = "1050 ?  Sl  1:06 unicorn_rails master -c first_unicorn.rb -E staging -D\n 
                 1051 ?  Sl  1:06 unicorn_rails master -c other_unicorn.rb -E staging -D\n"
        @scaler.stubs(:grep_process_list).returns(plist)
      end

      should "raise an error" do
        exception = assert_raise(RuntimeError) do
          @scaler.scale
        end
        assert_match /Too many unicorn master processes/, exception.message
      end
    end

    context "when an old master process is running" do
      setup do
        plist = "1050 ?  Sl  1:06 unicorn_rails master (old) -c first_unicorn.rb -E staging -D\n 
                 1051 ?  Sl  1:06 unicorn_rails worker[0] -c other_unicorn.rb -E staging -D\n"
        @scaler.stubs(:grep_process_list).returns(plist)
      end

      should "raise an error" do
        exception = assert_raise(RuntimeError) do
          @scaler.scale
        end
        assert_match /Old master process detected/, exception.message
      end
    end

    context "when things are properly detected" do
      setup do
        plist = "1050 ?  Sl  1:06 unicorn_rails master -c first_unicorn.rb -E staging -D\n 
                 1051 ?  Sl  1:06 unicorn_rails master -c other_unicorn.rb -E staging -D\n
                 1052 ?  Sl  1:06 unicorn_rails worker[0] -c other_unicorn.rb -E staging -D\n
                 1053 ?  Sl  1:06 unicorn_rails worker[1] -c other_unicorn.rb -E staging -D\n
                 1054 ?  Sl  1:06 unicorn_rails worker[0] -c first_unicorn.rb -E staging -D\n" 
        @scaler.stubs(:grep_process_list).returns(plist)
        @scaler.stubs(:auto_scale).returns(["NOTASIGNAL", 2])
        @scaler.stubs(:signal_delay).returns(0)
        @scaler.app_name = "first"
      end

      should "find the correct master and correct worker quantity" do
        @scaler.publicize(:find_unicorns, :find_master_pid, :find_worker_count)
        unicorns = @scaler.find_unicorns

        assert_equal 1050, @scaler.find_master_pid(unicorns)
        assert_equal 1, @scaler.find_worker_count(unicorns)
      end

      should "send the correct number of signals" do
        @scaler.expects(:send_signal).with(1050, "NOTASIGNAL").twice
        @scaler.scale
        assert true
      end      
    end
  end

  # Test the scaling algorithm separately for simplicity's sake
  context "#auto_scale" do
    setup do
      @worker_count = 10
      @scaler.min_workers = 1
      @scaler.max_workers = 25
      @scaler.buffer = 2
      @scaler.target_ratio = 1.3
      @data = { :active => DataSet.new,
                :queued => DataSet.new }
      @data[:queued]
    end

    context "when we need to scale down" do
      setup do
        @data[:active] << 3 << 4 << 5
        @data[:queued] << 0 << 0 << 0
      end

      should "return 1 TTOU" do
        assert_equal ["TTOU", 1], @scaler.auto_scale(@data, @worker_count)
      end

      context "but we've hit our minimum workers" do
        setup do
          @scaler.min_workers = 10
        end

        should "return no signal" do
          assert_equal [nil, 0], @scaler.auto_scale(@data, @worker_count)
        end
      end
    end

    context "when we need to scale up" do
      setup do
        @data[:active] << 2 << 10
        @data[:queued] << 0 << 0
      end

      should "return 1 TTIN" do
        assert_equal ["TTIN", 1], @scaler.auto_scale(@data, @worker_count)
      end

      context "but we've hit our maximum workers" do
        setup do
          @scaler.max_workers = 10
        end

        should "return no signal" do
          assert_equal [nil, 0], @scaler.auto_scale(@data, @worker_count)
        end
      end
    end

    context "when we need to panic and scale up fast" do
      setup do
        @data[:queued] << 6
        @data[:active] << 6
      end

      should "return several TTIN" do
        assert_equal ["TTIN", 8], @scaler.auto_scale(@data, @worker_count)
      end
    end

    context "when we really, really need to panic" do
      setup do
        @data[:queued] << 20
        @data[:active] << 20
      end

      should "return TTIN to jump straight to max_workers" do
        assert_equal ["TTIN", 15], @scaler.auto_scale(@data, @worker_count)
      end
    end

    context "when we don't need to scale at all" do
      setup do
        @data[:active] << 6
        @data[:queued] << 0
      end

      should "return no signal" do
        assert_equal [nil, 0], @scaler.auto_scale(@data, @worker_count)
      end
    end

  end

  context "#collect_data" do
    should "return the correct data" do
      data = @scaler.send(:collect_data)
      expected_data = { :calling => [3]*30,
                        :writing => [1]*30,
                        :active  => [4]*30,
                        :queued  => [0]*30 }
      assert_equal expected_data, data
    end
  end

end
