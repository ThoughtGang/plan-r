#!/usr/bin/env ruby
# :title: PlanR::Application
=begin rdoc
Plan R Application module

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r'
require 'plan-r/application/service'

module PlanR

=begin rdoc
Module for PlanR-based applications
=end
  module Application

    autoload :ConfigManager, 'plan-r/application/config.rb'
    autoload :DocumentManager, 'plan-r/application/document_mgr.rb'
    autoload :JRuby, 'plan-r/application/jruby.rb'
    autoload :PluginManager, 'plan-r/application/plugin_mgr.rb'
    autoload :QueryManager, 'plan-r/application/query_mgr.rb'
    autoload :RepoManager, 'plan-r/application/repo_mgr.rb'
    autoload :RevisionControl, 'plan-r/application/revision_control.rb'
    autoload :ScriptManager, 'plan-r/application/script_mgr.rb'

=begin rdoc
Declare that the Application uses specified service. 'sym' is one of the
above auto-loaded services.

Example:

  class TheApplication
    include PlanR::Application

    def initialize(argv)
      use PluginManager
    end
  end
=end
    def use(sym)
      Service.enable(sym)
    end

=begin rdoc
Return PluginManager instance
=end
    def self.plugins
      PluginManager
    end

    def plugins
      self.class.plugins
    end

=begin rdoc
Return ConfigManager instance
=end
    def self.config
      ConfigManager
    end

    def config
      self.class.config
    end

=begin rdoc
Return a simple, 'fake' Application object.
This is just an instance of Object with the Appliction module added.
=end
    def self.fake
      obj = Object.new
      obj.extend Application
    end
  end

end

