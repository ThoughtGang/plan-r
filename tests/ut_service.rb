#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Application Service API

require 'test/unit'

require 'plan-r/application'
require 'plan-r/application/service'

# ----------------------------------------------------------------------
class TC_ServiceApiTest < Test::Unit::TestCase

  class UnitTestService
    extend PlanR::Application::Service

    @state = 'undefined'
    def self.state; @state; end
    @app = nil
    def self.app; @app; end
    @obj = nil
    def self.obj; @obj; end

    def self.init
      @state = 'init'
    end

    def self.startup(app)
      @state = 'started'
      @app = app
    end

    def self.object_loaded(app, obj)
      @state = 'open'
      @obj = obj
    end

    def self.shutdown(app)
      @state = 'stopped'
    end
  end

  def test_1_define
    # [TC_ServiceApiTest::UnitTestService]
    # PlanR::Application::Service.services.inspect
    # ["UnitTestService"]
    # PlanR::Application::Service.service_names.inspect
    assert_equal('undefined', UnitTestService.state)
    PlanR::Application::Service.enable(:UnitTestService)
  end

  def test_2_init
    PlanR::Application::Service.init_services
    assert_equal('init', UnitTestService.state)
  end

  def test_3_startup
    PlanR::Application::Service.startup_services(self)
    assert_equal('started', UnitTestService.state)
    assert_equal(self, UnitTestService.app)
  end

  def test_4_open
    h = { :a => 1, :b => 2 }
    PlanR::Application::Service.broadcast_object_loaded(self, h)
    assert_equal('open', UnitTestService.state)
    assert_equal(h, UnitTestService.obj)
  end

  def test_5_shutdown
    PlanR::Application::Service.shutdown_services(self)
    assert_equal('stopped', UnitTestService.state)
  end

end
