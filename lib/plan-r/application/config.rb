#!/usr/bin/env ruby
# :title: PlanR::Application::ConfigManager
=begin rdoc
Plan R Config Manager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'yaml'

require 'plan-r/application/service'

module PlanR

  module Application

=begin rdoc
An application service for managing configuration and preferences.

Example:
=end
    class ConfigManager
      extend Service

      # Name of directory where config files are stored
      # For example, ~/.plan-r or /etc/plan-r
      DEFAULT_DOMAIN = 'plan-r'
      @app_dir = DEFAULT_DOMAIN

      # Environment variable for overriding config file
      CONF_ENV = 'PLAN_R_CONF'

      @config_domains = {}
      @framework_cfg = nil
      @config_files = {}

      def self.init
        # read system config
        @framework_cfg = read_config(@app_dir)
        @config_files.each do |sym, arr|
          arr.each { |path| read_config_file(path, sym) }
        end
      end

=begin rdoc
This should be invoked after an application has completed startup.
=end
      def self.startup(app)
        # nothing to do
      end

=begin rdoc
When repo (or other applicaton object) is loaded, read its config.
=end
      def self.object_loaded(app, obj)
        obj.read_config(self) if obj.respond_to? :read_config
      end

=begin rdoc
This should be invoked after an application is about to commence shutdown.
=end
      def self.shutdown(app)
        # write config?
      end

=begin rdoc
Return default configuration directory.
=end
      def self.get_default_dir
          File.join(File.dirname(File.dirname(__FILE__)), 'conf')
      end

=begin rdoc
Return application config directory in system conf dir (/etc).
=end
      def self.get_system_dir
        # FIXME: win32 support
        File.join('', 'etc', @app_dir, 'conf')
      end

=begin rdoc
Return application config directory in user home dir (~).
=end
      def self.get_home_dir
        File.join(Dir.home, '.' + @app_dir, 'conf')
      end

=begin rdoc
Return conf directory specified in environment variable, if any
=end
      def self.get_env
        ENV[CONF_ENV] ? ENV[CONF_ENV] : ''
      end

      # install_dir + system dir + home dir
      def self.config_dirs
        [ get_env, get_default_dir, get_system_dir, get_home_dir, Dir.pwd 
        ].reject{ |dir| ! dir || dir.empty? }
      end

=begin rdoc
Set the directory name in which config files are present.
WARNING: changing this will override all PlanR framework config files!
=end
      def self.set_app_dir(name)
        @app_dir = name
      end

=begin rdoc
Add a config file to the list of config files read on init. Config files added 
after init() is called will not be read -- use read_config_file for that.

Note that a file added here will override all files in config dirs.
=end
      def self.add_config_file(path, domain)
        @config_files[domain] ||= []
        @config_files[domain] << path
      end

      def self.read_config(cfg_name)
        name = File.basename(cfg_name)
        sym = name.to_sym

        config_dirs.each do |d|
          path = File.join(d, name + '.yaml')
          read_config_file(path, sym)
        end
        @config_domains[sym] || {}
      end

      def self.read_config_file(path, domain)
        read_config_hash(read_yaml_file(path), domain)
      end

      def self.read_config_hash(h, domain)
        @config_domains[domain] ||= {}
        @config_domains[domain].merge!(h)
      end

      def self.[](*args)
        @config_domains.[](*args)
      end

      def self.[]=(*args)
        @config_domains.[]=(*args)
      end

      def self.domains
        @config_domains.keys
      end

      private

      def self.read_yaml_file(path)
        return {} if (! File.exist? path)
        buf = File.read(path)
        YAML.safe_load(buf) || {}
      end

    end

  end
end
