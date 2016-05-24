#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Picky Plugin : Tag Search

require 'test/unit'

require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/plugin_mgr'

require_relative "../shared/shm_repo"

# ----------------------------------------------------------------------
# on-disk path of the repo
CONTENT_BASE = shm_repo('picky-test-tag-repo')

class TC_ApiDevTest < Test::Unit::TestCase

  DOCS = [
    { :path => 'a/1', :data => '111', :tags => ['a', 'c++'] },
    { :path => 'a/2', :data => '222', :tags => ['a', 'dev', 'design'] },
    { :path => 'a/3', :data => '222', :tags => ['A', 'data analysis'] },
    { :path => 'a/4', :data => '222', :tags => ['a', 'design'] },
    { :path => 'b/1', :data => '333', :tags => ['b', 'c++'] },
    { :path => 'b/2', :data => '444', :tags => ['b', 'dev', 'testing'] },
    { :path => 'b/3', :data => '444', :tags => ['B', 'data analysis'] },
    { :path => 'b/4', :data => '444', :tags => ['b', 'dev', 'design'] },
    { :path => 'c.1', :data => 'c11', :tags => ['x86', 'asm'] },
    { :path => 'c.2', :data => 'c22', :tags => ['x86', 'asm'] },
    { :path => 'c.3', :data => 'c33', :tags => ['x86-64', 'asm'] },
    { :path => 'c.4', :data => 'c44', :tags => ['arm', 'asm'] },
    { :path => 'z', :data => 'zzz', :tags => [] }
  ]

  def test_1_0_create_repo
    $repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    assert_not_nil($repo, 'Repo not created')
    PlanR::Application::PluginManager.object_loaded(self, $repo)

    DOCS.each do |doc|
      $repo.add(doc[:path], doc[:data], :document)
      doc[:tags].each { |t| $repo.tag(doc[:path], :document, t) }
      assert_equal(doc[:tags], $repo.tags(doc[:path], :document))
    end
  end

  def test_2_0_tag_list
    in_tags = DOCS.map { |h| h[:tags].map {|t| t.downcase } }.flatten.sort.uniq
    out_tags = PlanR::Application::DocumentManager.known_tags($repo).sort
    assert_equal(in_tags, out_tags)
  end

  def test_3_0_tag_search
    tag_search = PlanR::Plugins::Search::PickyTag.plugin_name
    [ 'a', 'b', 'dev', 'data analysis', 'testing', 'design', 'asm', 'x86', 
      'c++', 'x86-64' ].each do |t|
      # FIXME: Add to query manager (along with related docs)
      # NOTE: quotes needed to prevent partial matches
      q = PlanR::Query.new("\"#{t}\"")
      h_rv = PlanR::Application::QueryManager.perform($repo, q, tag_search)
      results = h_rv[tag_search]
      docs = DOCS.inject([]) { |arr,h| 
        arr << h[:path] if h[:tags].map { |ht| ht.downcase }.include? t
        arr
      }.sort
      assert_equal(docs, results.map { |r| r.path }.sort )
    end

  end
end

# ----------------------------------------------------------------------
# Initialization
PlanR::Application::PluginManager.init
PlanR::Application::PluginManager.startup(self)
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)
