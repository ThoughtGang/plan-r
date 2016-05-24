#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

require 'test/unit'
require 'yaml'

require 'plan-r/plugin'
require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/config'
require 'plan-r/application/repo_mgr'
require 'plan-r/application/plugin_mgr'

require_relative "../shared/shm_repo"

# ===========================================================================
SPEC_PROTO='fn(x)'
SPEC_IN = [ Fixnum ]
SPEC_OUT = [ Fixnum ]
SPEC_X=:operation_x
SPEC_Y=:operation_y

# Plugin A: the control
class PluginA
  extend PlanR::Plugin

  name 'Plugin A'
  author 'a developer'
  version '1.0'

  def op_plus(x) x + 1; end
  spec SPEC_X, :op_plus, 50
  def op_minus(x) x - 1; end
  spec SPEC_Y, :op_minus, 40
end

# Plugin B : this will be biased by repo config
class PluginB
  extend PlanR::Plugin

  name 'Plugin B'
  author 'be developer'
  version '1.0'

  def op_plus(x) x + 2; end
  spec SPEC_X, :op_plus, 40
  def op_minus(x) x - 2; end
  spec SPEC_Y, :op_minus, 50
end

# Plugin C : this will be blacklisted by repo config
class PluginC
  extend PlanR::Plugin

  name 'Plugin C'
  author 'see developer'
  version '1.0'
end

# Plugin D : this will be whitelisted by repo config
class PluginD
  extend PlanR::Plugin

  name 'Plugin D'
  author 'd developer'
  version '1.0'
end

CONTENT_BASE = shm_repo('plugin-repo-cfg-test-repo')

class TC_PluginRepoConfigTest < Test::Unit::TestCase

  def test_1_startup

    PlanR::Application::Service.enable(PlanR::Application::ConfigManager)
    PlanR::Application::Service.enable(PlanR::Application::PluginManager)
    PlanR::Application::Service.init_services

    PlanR::Application::PluginManager.purge
    assert_equal(0, PlanR::Application::PluginManager.plugins.count)

    PlanR::Application::PluginManager.clear_specs
    PlanR::Plugin::Specification.new(SPEC_X, SPEC_PROTO, SPEC_IN, SPEC_OUT)
    PlanR::Plugin::Specification.new(SPEC_Y, SPEC_PROTO, SPEC_IN, SPEC_OUT)
    assert_equal(2, PlanR::Application::PluginManager.specs.count)

    PlanR::Application::PluginManager.blacklist PluginD.canon_name

    PlanR::Application::PluginManager.load_plugin(PluginA)
    PlanR::Application::PluginManager.load_plugin(PluginB)
    PlanR::Application::PluginManager.load_plugin(PluginC)
    PlanR::Application::PluginManager.load_plugin(PluginD)

    assert_equal(3, PlanR::Application::PluginManager.plugins.count)

    PlanR::Application::Service.startup_services(self)
  end

  def test_2_spec_bias
    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_x, 10)
    assert_equal(11, rv) # Plugin A wins

    p = PlanR::Application::PluginManager.find('Plugin B')
    assert_not_nil(p)
    PlanR::Application::PluginManager.set_spec_bias(:operation_x, p, 11)

    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_x, 10)
    assert_equal(12, rv) # Plugin B now wins
  end

  def test_3_create_repo
    # create repo
    repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    repo.close

    # create repo config
    File.open(File.join(repo.base_path, PlanR::Repo::CONFIG_DIR,
                        PlanR::Repo::CONFIG_FILE), 'w') do |f|

      f.puts generate_yaml_config
    end

    # existing bias (operation_x) and default fitness (operation_y) favor B
    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_x, 10)
    assert_equal(12, rv) # Plugin B wins
    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_y, 10)
    assert_equal(8, rv) # Plugin B wins

    # loaded plugins: A, B, C
    assert_equal( [PluginA.canon_name, PluginB.canon_name, PluginC.canon_name],
                  PlanR::Application::PluginManager.plugins.map { |name, p|
                    p.canon_name }.sort )

    repo = PlanR::Application::RepoManager.open(CONTENT_BASE)
    # at this point, repo config should have been applied to plugin mgr

    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_x, 10)
    assert_equal(11, rv) # Plugin A wins
    rv = PlanR::Application::PluginManager.fittest_invoke(:operation_y, 10)
    assert_equal(9, rv) # Plugin A wins

    # loaded plugins: A, B, D
    assert_equal( [PluginA.canon_name, PluginB.canon_name, PluginD.canon_name],
                  PlanR::Application::PluginManager.plugins.map { |name, p|
                    p.canon_name }.sort )

    # close repo
    PlanR::Application::RepoManager.close(repo)
  end

  def test_9_9_9_shutdown
    PlanR::Application::Service.shutdown_services(self)
  end

  def generate_yaml_config
    # DOMAIN is 'plan-r-repo'

    {
      PlanR::Application::PluginManager::CONF_NAME => {
        'strict_return' => false,
        'debug' => false,
        'base_dirs' => [
        ],
        'prevent_loading' => [
        ],
        'plugin_dirs' => [
        ],
        'plugin_files' => [
        ],
        'enable' => [
          PluginD.canon_name
        ],
        'disable' => [
          PluginC.canon_name
        ],
        'bias' => {
          'Plugin A' => {
            'operation_y' => 11
          },
          'Plugin B' => {
            'operation_x' => -2
          }
        }
      }
    }.to_yaml
  end
end



# ----------------------------------------------------------------------
# Initialization
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)

