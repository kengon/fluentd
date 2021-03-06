require 'fluent/test'
require 'helper'

class SyslogInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    require 'fluent/plugin/socket_util'
  end

  CONFIG = %[
    port 9911
    bind 127.0.0.1
    tag syslog
  ]

  IPv6_CONFIG = %[
    port 9911
    bind ::1
    tag syslog
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SyslogInput).configure(conf)
  end

  def test_configure
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)
      assert_equal 9911, d.instance.port
      assert_equal k, d.instance.bind
    }
  end

  def test_time_format
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)

      tests = [
        {'msg' => '<6>Sep 11 00:00:00 localhost logger: foo', 'expected' => Time.strptime('Sep 11 00:00:00', '%b %d %H:%M:%S').to_i},
        {'msg' => '<6>Sep  1 00:00:00 localhost logger: foo', 'expected' => Time.strptime('Sep  1 00:00:00', '%b  %d %H:%M:%S').to_i},
      ]

      d.run do
        u = Fluent::SocketUtil.create_udp_socket(k)
        u.connect(k, 9911)
        tests.each {|test|
          u.send(test['msg'], 0)
        }
        sleep 1
      end

      emits = d.emits
      emits.each_index {|i|
        assert_equal(tests[i]['expected'], emits[i][1])
      }
    }
  end

  def test_msg_size
    d = create_driver

    tests = [
      {'msg' => '<6>Sep 10 00:00:00 localhost logger: ' + 'x' * 100, 'expected' => 'x' * 100},
      {'msg' => '<6>Sep 10 00:00:00 localhost logger: ' + 'x' * 1024, 'expected' => 'x' * 1024},
    ]

    d.run do
      u = UDPSocket.new
      u.connect('127.0.0.1', 9911)
      tests.each {|test|
        u.send(test['msg'], 0)
      }
      sleep 1
    end

    emits = d.emits
    emits.each_index {|i|
      assert_equal(tests[i]['expected'], emits[i][2]['message'])
    }
  end
end

