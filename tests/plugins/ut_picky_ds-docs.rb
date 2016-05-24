#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Picky Plugin : Ds-Doc Search

require 'test/unit'

require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/document_mgr'
require 'plan-r/application/plugin_mgr'
require 'plan-r/application/query_mgr'

require_relative "../shared/shm_repo"

# ----------------------------------------------------------------------
# on-disk path of the repo
CONTENT_BASE = shm_repo('tests/repo/picky-test-ds-doc-repo')

class TC_ApiDevTest < Test::Unit::TestCase

  DOCS = [
    { :path => 'a/1', :data => 'asm is as asm does' },
    { :path => 'a/2', :data => 'assembly language for stoners' },
    { :path => 'a/3', :data => 'learn assembler in a day' },
    { :path => 'a/4', :data => 'assembly and disassembly the hard way' },
    { :path => 'b/1', :data => 'work on an assembly-line factory' },
    { :path => 'b/2', :data => 'once twice three times assembly' },
    { :path => 'b/3', :data => 'assembly and disassembly of fnord falcon' },
    { :path => 'b/4', :data => 'picture an assembly of birds' },
    { :path => 'c.1', :data => 'machine language and the rest of us' },
    { :path => 'c.2', :data => 'where in the world is carmen assembler' },
    { :path => 'c.3', :data => 'the manual for demanualling' },
    { :path => 'c.4', :data => 'more nonsense' },
    { :path => 'z', :data => 'a few final words.' }
  ]

  def test_1_0_create_repo
    $repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    assert_not_nil($repo, 'Repo not created')
    path = File.join(CONTENT_BASE, 
                     PlanR::Plugins::Search::PickyDomainIndex::NORMALIZER_FILE)
    File.open(path, 'w') do |f|
      f.puts "assembly language\tasm"
      f.puts "assembler\tasm"
      f.puts "machine language\tasm"
      f.puts "machine code\tasm"
    end
    assert(File.exist? path)
    PlanR::Application::PluginManager.object_loaded(self, $repo)

    DOCS.each do |doc|
      $repo.add(doc[:path], doc[:data], :document)
      PlanR::Application::DocumentManager.import_raw($repo, doc[:path], 
                                doc[:data], PlanR::Document.default_properties)
    end
  end

  def test_2_0_keywords_list
    ds_search = PlanR::Plugins::Search::PickyDomainIndex.plugin_name
    h = PlanR::Application::QueryManager.index_keywords($repo, {}, ds_search)
    puts h.inspect
#{"Domain-Specific Document Index"=>["1", "2", "3", "4", "c.1", "c.2", "c.3", "c.4", "z", "asm", "is", "as", "does", "assembly", "language", "for", "stoners", "learn", "assembler", "in", "a", "day", "and", "disassembly", "the", "hard", "way", "work", "on", "an", "assembly-line", "factory", "once", "twice", "three", "times", "of", "fnord", "falcon", "picture", "birds", "machine", "rest", "us", "where", "world", "carmen", "manual", "demanualling", "more", "nonsense", "few", "final", "words.", "words"]}
    #{"Domain-Specific Document Index"=>["1", "2", "3", "4", "c.1", "c.2", "c.3", "c.4", "z", "asm", "is", "as", "does", "assembly", "language", "for", "stoners", "learn", "assembler", "in", "a", "day", "and", "disassembly", "the", "hard", "way", "work", "on", "an", "assembly-line", "factory", "once", "twice", "three", "times", "of", "fnord", "falcon", "picture", "birds", "machine", "rest", "us", "where", "world", "carmen", "manual", "demanualling", "more", "nonsense", "few", "final", "words.", "words"]}

    #in_tags = DOCS.map { |h| h[:tags].map {|t| t.downcase } }.flatten.sort.uniq
    #out_tags = PlanR::Application::DocumentManager.known_tags($repo).sort
    #assert_equal(in_tags, out_tags)
  end

  def test_3_0_search
    #tag_search = PlanR::Plugins::Search::PickyTag.plugin_name
    #[ 'a', 'b', 'dev', 'data analysis', 'testing', 'design', 'asm', 'x86', 
    #  'c++', 'x86-64' ].each do |t|
    #  # FIXME: Add to query manager (along with related docs)
    #  # NOTE: quotes needed to prevent partial matches
    #  q = PlanR::Query.new("\"#{t}\"")
    #  h_rv = PlanR::Application::QueryManager.perform($repo, q, tag_search)
    #  results = h_rv[tag_search]
    #  docs = DOCS.inject([]) { |arr,h| 
    #    arr << h[:path] if h[:tags].map { |ht| ht.downcase }.include? t
    #    arr
    #  }.sort
    #  assert_equal(docs, results.map { |r| r.path }.sort )
    #end

  end
end

# ----------------------------------------------------------------------
# Initialization
PlanR::Application::PluginManager.init
PlanR::Application::PluginManager.startup(self)
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)
