#!/usr/bin/env ruby
# :title: PlanR::JRuby
=begin rdoc
==JRuby service
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

Forks and invokes JRuby Daemon (bin/plan-r-jrubyd)

Note: This file contains code which executes in a standard Ruby process, but
forks and execs a JRuby process containing a JrubyDaemon DRb service.
=end
 
require 'plan-r/application/service'
require 'drb'
require 'uri'

# TODO: YAML for host/port cfg

module PlanR

  module Application

# ============================================================================
=begin rdoc
JRuby Plan-R Service. This manages the JRuby Daemon.

This module starts and stops the JRuby instance and wraps the DRb 
connectivity.
=end
    class JRuby
      extend Service

      CONF_NAME = 'jruby' # jruby.yaml in ~/.plan-r
      CONF_PORT = 'drb_port'
      CONF_URI = 'drb_uri'
      CONF_JRUBY = 'jruby_path'

      SERVER_PORT=59995
      SERVER_URI="druby://localhost:"
      JRUBY_DAEMON = File.join(File.dirname(              # plan-r/
                               File.dirname(__FILE__)),   # application/
                               'bin', 'plan-r-jrubyd') 

      # This is true if Jruby service has been successfully started
      @running = false

      def self.init
        read_config
      end

      def self.read_config
        @config = Application.config.read_config(CONF_NAME)
        @server_port = @config[CONF_PORT] || SERVER_PORT
        @server_uri = @config[CONF_URI] || (SERVER_URI + @server_port.to_s)
        @jruby = @config[CONF_JRUBY] || get_jruby
        if ! @jruby
          # disable this service
          Service.disable(:JRuby)
        end
      end

=begin rdoc
This should be invoked after an application has completed startup.
=end
      def self.startup(app)
        exec_daemon
      end

=begin rdoc
This is invoked by the application whenever a new document or repo is
loaded. This gives plugins a chance to register themselves with new
document windows.
=end
      def self.object_loaded(app, obj)
        # no-op
      end

=begin rdoc
This should be invoked after an application is about to commence shutdown.
=end
      def self.shutdown(app)
        service_shutdown
      end

      def self.running?
        @running
      end

=begin rdoc
Fork, exec jruby running plan-r-jrubyd. Returns pid of jruby daemon.
=end
        def self.exec_daemon
          DRb.start_service
          begin
            # from plan-r/bin/plan-r-jrubyd:
            #   a colon-delimited list of (PlanR plugin) directories.
            #   "/shared/jruby" is appended to each dir, and load_module_dir is
            #   invoked on the resulting path if it exists
            path = Application::PluginManager.plugin_dirs.join(":")

            pid = Process.fork do
              exit(self.exec_jrubyd path)
            end
            sleep 0.1
            Process.detach(pid)
            @running = true

          rescue Exception => e
            $stderr.puts "Unable to fork: #{e.message}"
            raise e
          end
        end

=begin rdoc
Returns command to invoke JRuby.
=end
        def self.get_jruby
          jruby = `which jruby`.chomp
          return jruby if ! jruby.empty?

          rvm = `which rvm`
          return nil if rvm.empty?

          jruby = `rvm list`.split("\n").select { |line| 
                                          line.strip.start_with? 'jruby' }.first

          return nil if ! jruby
          "rvm #{jruby.strip.split(' ').first} do ruby "
        end

=begin rdoc
Exec plan-r-jrubyd in JRuby with RUBYLIB set so JRuby plugin modules can be
found.
=end
        def self.exec_jrubyd(path)
          if ! @jruby
            $stderr.puts "No JRUBY found!"
            return 1
          end
          # add plugin path for loading shared/jruby moules
          ENV['PLANR_PLUGIN_PATH'] = path
          # add Plan-R path in case it doesn't exist as a JRuby gem
          ENV['PLANR_BASE_PATH'] = File.expand_path(File.dirname(File.dirname(
                                                    File.dirname(__FILE__))))
          exec "#{@jruby} #{JRUBY_DAEMON} #{@server_port}"
        end

        # ----------------------------------------------------------------------
        # JRUBY SERVICE API
=begin rdoc
Connect to JRuby Drb service. This starts the service. The return value is the
Drb Service object.

The connection to the service is tried 100 times with a 100-ms sleep, meaning 
this can delay returning for up to 10 seconds. This is necessary in order to 
allow JRuby time to spin up. If num_retries is provided, the connection loop 
is attempted that many times (default = 3 times or 30 seconds).

NOTE: A call to connect can come from process that did not call exec_daemon,
so it cannot attempt the exec itself. The exec_lucened call therefore MUST 
happen in application startup!
=end
      def self.connect(num_retries=3)
        return nil if num_retries == 0
        obj = nil
        connected = false

        # Wait on DRuby to initialize (max 10 seconds)
        100.times do
          begin
            obj = service_connection
            obj.inc_usage # increment service connection count
            connected = true
            break         # DRuby call successful!
          rescue Exception => e
            sleep 0.10     # 100-ms sleep
          end
        end

        connected ? obj : connect(num_retries - 1)
      end

=begin rdoc
Disconnect from Jruby Drb service. If the service cannot be reached this prints
an error but does not fail.
=end
      def self.disconnect
        obj = service_connection
        begin
          obj.dec_usage
        rescue DRb::DRbConnError
          $stderr.puts "Unable to send dec_usage to Lucene DRuby instance"
        end
      end

=begin rdoc
Returns a new DRb remote object representing a connection to the service. Note
that the connection is not performed until a method of the object is invoked.
=end
      def self.service_connection
        DRbObject.new_with_uri(@server_uri)
      end

      def self.service_shutdown
        @running = true
        warned = false
        100.times do
          begin
            DRbObject.new_with_uri(@server_uri).stop_if_unused
            break # successfully shut down
          rescue DRb::DRbConnError
            if ! warned
              # TODO: some proper sort of logging
              $stderr.puts "Stopping jrubyd before JRuby has initialized"
              warned = true
            end

            sleep 0.1
          end
        end
      end
    end

  end
end

require 'plan-r/application/plugin_mgr' # for plugin_dirs
