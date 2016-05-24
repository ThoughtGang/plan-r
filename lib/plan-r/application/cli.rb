#!/usr/bin/env ruby
# :title: Plan-R Command Line Application
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/application'
require 'ostruct'
require 'optparse'

require 'plan-r/content_repo'

module PlanR

=begin rdoc
A generic command-line application.
CLI utilities should derive from this to reduce code duplication.

Example:

class TheApp < CliApplication
  def self.disable_plugins?; true; end

  def handle_options(args)
    super
  end

  def start
    # application code goes here
  end
end

if __FILE__ == $0
  MyCliApplication.new(ARGV).exec()
end
=end
  class CliApplication
    attr_reader :options
    CONFIG_DOMAIN='plan-r-cli'

    include Application

    # per-application Service disable:
    #  A CLI application can override any of these to return 'true' if
    #  it has no need of the service.Tends to speed things up.
    def self.disable_plugins?; false; end
    def self.disable_jruby?;   false; end
    def self.disable_vcs?;     false; end

=begin rdoc
Instantiate the Application. This calls handle_options to process command-line
arguments, then initializes all Services.
=end
    def initialize(args)
      @options = OpenStruct.new
      init_default_options

      handle_options(args)

      # declare services
      if (! @options.no_services)
        use ConfigManager
        use PluginManager unless plugins_disabled?
        use JRuby unless java_disabled?
        use RevisionControl unless vcs_disabled?

        init_services
      end


      read_config
    end

=begin rdoc
Use OptionParser to handle command-line arguments. This fills @options with
values obtained from the arguments. Derived classes should implement this
method.
=end
    def handle_options(args)
      @options.arguments = []

      opts = OptionParser.new do |opts|
        standard_cli_options(opts)
      end

      opts.parse!(args)
      @options.arguments += args
    end

=begin rdoc
Read the config domain 'app' into @config.
=end
    def read_config
      @config = PlanR::Application::ConfigManager.read_config(CONFIG_DOMAIN)
    end

=begin rdoc
Initialize all Service objects. Derived classes can override this to perform
additional configuration (e.g. of plugins) before Services are instantiated.
=end
    def init_services
      PlanR::Application::Service.init_services
    end

=begin rdoc
Wrapper for CliApplication#start. This starts Services before calling
start(), and terminates Services afterwards.
=end
    def exec
      if (! @options.no_services)
        PlanR::Application::Service.startup_services(self)
      end

      begin
        start
      rescue Exception => e
        $stderr.puts "#{self.class.name} Caught exception: #{e.message}"
        $stderr.puts e.backtrace[0,30].join("\n")
      ensure
        self.cleanup
      end
    end

=begin rdoc
main() for the application. Command-line arguments have already been processed.
Derived classes *must* implement this method.
=end
    def start
      raise 'Virtual method start() invoked'
    end

=begin rdoc
Clean up application and framework before exit.
Applications should invoke this in fatal exception handlers.
=end
    def cleanup
      if (@options && (! @options.no_services))
        PlanR::Application::Service.shutdown_services(self)
      end
    end

    # ----------------------------------------------------------------------
    protected

    def standard_cli_options(opts)
      # This will be overridden completely by ENV[PLAN_R_CONF]. Only one
      # --config-dir argument can be present
      opts.on('--config-dir str', 'Specify config file directory') do |str|
        econf = PlanR::Application::ConfigManager.get_env
        ENV[PlanR::Application::ConfigManager::CONF_ENV] = str if econf.empty?
      end

      # This file will be applied to the "plan-r" domain and will override
      # all config directory files
      opts.on('--config-file str', 'Specify a config file') do |str|
        domain = PlanR::Application::ConfigManager::DEFAULT_DOMAIN
        PlanR::Application::ConfigManager.add_config_file(str, domain)
      end

      # TODO: config option

      opts.on('--no-java', 'Do not start JRuby process') do 
        @options.disable_java = true
      end
      opts.on('--no-jruby', 'Alias for --no-java') do 
        @options.disable_java = true
      end

      opts.on('--no-plugins', 'Do not start PluginManager') do 
        @options.disable_plugins = true
      end

      opts.on('--no-vcs', 'Do not use version control') do 
        @options.disable_vcs = true
      end
      opts.on('--no-git', 'Alias for --no-vcs') do 
        @options.disable_vcs = true
      end

      opts.on('-1', '--single-process', 'Alias for --no-jruby') do
        @options.disable_java = true
      end

      opts.on('--barebones', 'Do not start any services') do
        @options.no_services = true
      end

      opts.on_tail('-?', '--help', 'Show help screen') { puts opts; exit 1 }
      opts.on_tail('-v', '--version', 'Show version info') do
        puts 'Version: ' + PlanR::VERSION
        exit 2
      end 
    end

    def available_node_types(meta=false)
      meta ? ContentRepo::MetadataNode.class_keys :
             ContentRepo::ContentNode.class_keys 
    end

    def arg_to_node_type(arg)
      return nil if (! arg)
      arg = arg.to_sym
      case arg
      when :doc
        :document
      when :dir
        :folder
      when :res, :rsrc, :resources
        :resource
      when :tag
        :tags
      when :prop, :property
        :properties
      when :all
        nil
      else
        arg
      end
    end

    # ----------------------------------------------------------------------
    private

    def  init_default_options
      @options.no_services = false
      @options.disable_java = false
      @options.disable_vcs = false
      @options.disable_plugins = false
    end

    def java_disabled?
      (@options.disable_java or self.class.disable_jruby?)
    end

    def vcs_disabled?
      (@options.disable_vcs or self.class.disable_vcs?)
    end

    def plugins_disabled?
      (@options.disable_plugins or self.class.disable_plugins?)
    end

  end
end

