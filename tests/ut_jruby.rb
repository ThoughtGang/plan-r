#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Application JRuby Service

require 'test/unit'

require 'plan-r/application'
require 'plan-r/application/config'
require 'plan-r/application/jruby'
require 'plan-r/application/plugin_mgr'

# ----------------------------------------------------------------------
class TC_JRubyTest < Test::Unit::TestCase

  def test_1_define
    PlanR::Application::Service.enable(PlanR::Application::ConfigManager)
    PlanR::Application::Service.enable(PlanR::Application::PluginManager)
    PlanR::Application::Service.enable('PlanR::Application::JRuby')

    assert_equal( [PlanR::Application::ConfigManager, 
                   PlanR::Application::JRuby,
                   PlanR::Application::PluginManager ], 
                   PlanR::Application::Service.services )

    assert_equal( ['ConfigManager', 'JRuby', 'PluginManager' ], 
                  PlanR::Application::Service.service_names )
  end

  def test_2_init
    PlanR::Application::Service.init_services
    # ensure JRuby is still enabled
    assert_equal( ['ConfigManager', 'JRuby', 'PluginManager' ], 
                  PlanR::Application::Service.service_names )
  end

  def test_3_startup
    PlanR::Application::Service.startup_services(self)
    assert_equal(true, PlanR::Application::JRuby.running?)
  end

  def test_4_connect
    obj = PlanR::Application::JRuby.connect
    assert_equal(DRb::DRbObject, obj.class)
    obj.send(:inc_usage)
    # NOTE: the jruby service works by loading plugin modules, so code
    #       cannot be sent directly to it
    obj.send(:dec_usage)
    PlanR::Application::JRuby.disconnect
  end

  def test_5_shutdown
    PlanR::Application::Service.shutdown_services(self)
  end

end
