#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR repo import/export

require 'test/unit'

require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/plugin_mgr'

require 'fileutils'

require_relative '../shared/shm_repo'

# FIXME: export to tarball. check tarball. import to new dir.

# ----------------------------------------------------------------------
CONTENT_BASE = shm_repo('export-repo')

class TC_ImportExportTest < Test::Unit::TestCase

  DOCS = [
    { :path => 'a/1', :data => '111' },
    { :path => 'a/2', :data => '222' },
    { :path => 'b/1', :data => '333' },
    { :path => 'b/2', :data => '444' },
    { :path => 'z/1/a', :data => '000' }
  ]
  def test_1_1_startup
    PlanR::Application::Service.enable(PlanR::Application::ConfigManager)
    PlanR::Application::Service.enable(PlanR::Application::PluginManager)
    PlanR::Application::Service.init_services
    PlanR::Application::Service.startup_services(self)
  end

  def test_1_2_create_repo
    $repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    assert_not_nil($repo, 'Repo not created')
    
    DOCS.each { |doc| $repo.add(doc[:path], doc[:data], :document) }
  end

  def test_2_1_tarball_plugin
    tgz_path = shm_tmp('ut-repo-export.tgz')
    p_name = PlanR::Plugins::ImportExport::Tarball.plugin_name
    p = PlanR::Application::PluginManager.find(p_name)
    assert_not_nil(p)

    paths = ['/']
    p.spec_invoke(:export_contents, $repo, paths, tgz_path, {})
    assert(File.exist? tgz_path)

    # test tar -ztf vs plugin list method
    if (! `which tar`.empty?)
      lines = `tar -ztf #{tgz_path}`.chomp.split("\n")
      assert_equal(lines, p.contents(tgz_path))
    end
    # FIXME: test contents against fixed list of paths

    i_repo_path = shm_repo('tarball-export-import-repo')
    FileUtils.rm_r(i_repo_path) if (File.exist? i_repo_path)
    i_repo = PlanR::Repo.create('import-test-repo', i_repo_path)
    assert(File.exist? i_repo_path)
    
    p.spec_invoke(:import_contents, i_repo, tgz_path, '', {})
    assert_equal( ["/", "/a", "/a/1", "/a/2", "/b", "/b/1", "/b/2",
                  "/z", "/z/1"],  i_repo.content_tree.subtree('/', nil, 3, true
                                  ).map { |x| x.path }.sort )

    FileUtils.rm_r(i_repo_path) if (File.exist? i_repo_path)

    # FIXME: test importing under subtree
    # FIXME: test export/import other content types

    File.delete(tgz_path)
  end

  # FIXME: tesrt other plugins, e.g. Tarball Archive

  def test_9_9_9_shutdown
    PlanR::Application::Service.shutdown_services(self)
  end

end

# ----------------------------------------------------------------------
# Initialization
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)
