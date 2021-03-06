
require File.join(File.dirname(__FILE__), %w[.. setup])

if HAVE_SYSLOG

module TestLogging
module TestAppenders

  class TestSyslog < Test::Unit::TestCase
    include LoggingTestCase
    include ::Syslog::Constants

    def setup
      super
      Logging.init
      @levels = Logging::LEVELS
      @logopt = defined?(::Syslog::LOG_NDELAY) ?
                    (::Syslog::LOG_PERROR | ::Syslog::LOG_NDELAY) :
                    (::Syslog::LOG_PERROR)
    end

    def test_append
      return if RUBY_PLATFORM =~ %r/cygwin/

      stderr = IO::pipe

      pid = fork do
        stderr[0].close
        STDERR.reopen(stderr[1])
        stderr[1].close

        appender = create_syslog
        event = Logging::LogEvent.new('TestLogger', @levels['info'],
                                      [1, 2, 3, 4], false)
        appender.append event
        event.level = @levels['debug']
        event.data = 'the big log message'
        appender.append event

        appender.level = :warn
        event.level = @levels['info']
        event.data = 'this message should not get logged'
        appender.append event
        event.level = @levels['warn']
        event.data = 'this is your last warning'
        appender.append event

        exit!
      end

      stderr[1].close
      Process.waitpid(pid)

      assert_equal("syslog_test:  INFO  TestLogger : <Array> #{[1,2,3,4]}\n",
                   stderr[0].gets)
      assert_equal("syslog_test: DEBUG  TestLogger : the big log message\n",
                   stderr[0].gets)
      assert_equal("syslog_test:  WARN  TestLogger : this is your last warning\n",
                   stderr[0].gets)
    end

    def test_append_error
      appender = create_syslog
      appender.close false

      event = Logging::LogEvent.new('TestLogger', @levels['warn'],
                                    [1, 2, 3, 4], false)
      assert_raise(RuntimeError) {appender.append event}
      assert_equal true, appender.closed?
    end

    def test_close
      appender = create_syslog
      assert_equal false, appender.closed?

      appender.close false
      assert_equal true, appender.closed?
    end

    def test_concat
      return if RUBY_PLATFORM =~ %r/cygwin/

      stderr = IO::pipe

      pid = fork do
        stderr[0].close
        STDERR.reopen(stderr[1])
        stderr[1].close

        appender = create_syslog
        appender << 'this is a test message'
        appender << 'this is another message'
        appender << 'some other line'

        exit!
      end

      stderr[1].close
      Process.waitpid(pid)

      assert_equal("syslog_test: this is a test message\n", stderr[0].gets)
      assert_equal("syslog_test: this is another message\n", stderr[0].gets)
      assert_equal("syslog_test: some other line\n", stderr[0].gets)
    end

    def test_concat_error
      appender = create_syslog
      appender.close false

      assert_raise(RuntimeError) {appender << 'oopsy'}
      assert_equal true, appender.closed?
    end

    def test_map_eq
      appender = create_syslog

      assert_equal(
        [LOG_DEBUG, LOG_INFO, LOG_WARNING, LOG_ERR, LOG_CRIT],
        get_map_from(appender)
      )

      appender.map = {
        :debug => LOG_DEBUG,
        :info  => 'LOG_NOTICE',
        :warn  => :LOG_WARNING,
        :error => 'log_err',
        :fatal => :log_alert
      }

      assert_equal(
        [LOG_DEBUG, LOG_NOTICE, LOG_WARNING, LOG_ERR, LOG_ALERT],
        get_map_from(appender)
      )
    end

    def test_map_eq_error
      appender = create_syslog

      # Object is not a valid syslog level
      assert_raise(ArgumentError) do
        appender.map = {:debug => Object}
      end

      # there is no syslog level named "info"
      # it should be "log_info"
      assert_raise(NameError) do
        appender.map = {:info => 'lg_info'}
      end
    end

    def test_initialize_map
      appender = Logging.appenders.syslog(
        'syslog_test',
        :logopt => @logopt,
        :map => {
          :debug  =>  :log_debug,
          :info   =>  :log_info,
          :warn   =>  :log_warning,
          :error  =>  :log_err,
          :fatal  =>  :log_alert
        }
      )

      assert_equal(
        [LOG_DEBUG, LOG_INFO, LOG_WARNING, LOG_ERR, LOG_ALERT],
        get_map_from(appender)
      )
    end


    private

    def create_syslog
      layout = Logging.layouts.pattern(:pattern => '%5l  %c : %m')
      Logging.appenders.syslog(
          'syslog_test',
          :logopt => @logopt,
          :facility => ::Syslog::LOG_USER,
          :layout => layout
      )
    end

    def get_map_from( syslog )
      syslog.instance_variable_get :@map
    end

  end  # class TestSyslog

end  # module TestAppenders
end  # module TestLogging

end  # HAVE_SYSLOG

# EOF
