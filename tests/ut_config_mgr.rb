#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Application Config Manager service

require 'test/unit'

require 'plan-r/repo'

require 'plan-r/application'
require 'plan-r/application/config'
require 'plan-r/application/repo_mgr'
require 'plan-r/application/service'

require_relative "shared/shm_repo"

# ----------------------------------------------------------------------
# on-disk path of the repo
CONTENT_BASE = shm_repo('cfg-mgr-test-repo')

class ConfigTestService
  extend PlanR::Application::Service

  ORIG_CONFIG = { 'a' => 1, 'b' => [1,2,3], 'c' => { 'abc' => '123' } }
  CONF_NAME = 'config-test'

  def self.config; @config; end

  def self.init
    @config = PlanR::Application::ConfigManager.read_config_hash(ORIG_CONFIG,
                                                                 CONF_NAME)
    # TODO: read_config() from file
  end

  def self.object_loaded(app, obj); @config.merge!(obj.config); end
end

class TC_ConfigMgrTest < Test::Unit::TestCase
  REPO_CONFIG = { 'b' => [4,5,6], 'z' => 999 }

  def test_1_startup
    PlanR::Application::Service.enable(PlanR::Application::ConfigManager)
    PlanR::Application::Service.enable(ConfigTestService)
    PlanR::Application::Service.init_services
    PlanR::Application::Service.startup_services(self)
  end

  def test_2_create_repo
    repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    assert(File.directory? File.join(CONTENT_BASE, 'settings'))

    File.open(File.join(repo.base_path, PlanR::Repo::CONFIG_DIR,
                        PlanR::Repo::CONFIG_FILE), 'w') do |f|
      f.puts REPO_CONFIG.to_yaml
    end
    repo.close

    # test initial config reading
    assert_equal( ConfigTestService::ORIG_CONFIG, ConfigTestService.config )

    repo = PlanR::Application::RepoManager.open(CONTENT_BASE)

    # test repo-specific config reading
    assert_equal( ConfigTestService::ORIG_CONFIG.merge!(REPO_CONFIG),
                  ConfigTestService.config )

    PlanR::Application::RepoManager.close(repo)
  end

  # TODO: test reading from files

  def test_9_9_9_shutdown
    PlanR::Application::Service.shutdown_services(self)
  end

end

# ----------------------------------------------------------------------
# Initialization
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)

