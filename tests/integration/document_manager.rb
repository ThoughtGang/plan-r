#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Integration tests for PlanR Document Manager

require 'test/unit'

require 'open-uri'
require 'thread'
require 'uri'
require 'webrick'
include WEBrick

require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/document_mgr'

require_relative "../shared/shm_repo"

# ----------------------------------------------------------------------
# refreshable remote document
class RefreshableTextDoc < HTTPServlet::AbstractServlet
  PATH = '/public/doc/refreshable.txt'
  CONTENTS='1000'
  @@contents = CONTENTS
  def do_GET(request, response)
    response.body =@@contents 
    @@contents = @@contents.succ
    response.status = 200
    response['Content-Type'] = 'text/plain'
  end

  def self.uri
    URI::HTTP.build( {:host => '127.0.0.1', :port => WWW_PORT, :path => PATH} )
  end
end

class StaticTextDoc < HTTPServlet::AbstractServlet
  PATH = '/public/doc/static.txt'
  CONTENTS='static text'
  def do_GET(request, response)
    response.body = CONTENTS
    response.status = 200
    response['Content-Type'] = 'text/plain'
  end

  def self.uri
    URI::HTTP.build( {:host => '127.0.0.1', :port => WWW_PORT, :path => PATH} )
  end
end

# ----------------------------------------------------------------------
# local web server for remote documents
WWW_PORT = 8888
def start_www_server
  $www_server = HTTPServer.new(:Port => WWW_PORT, 
                           :Logger => Log.new("/dev/null", Log::FATAL),
                           :AccessLog => [nil, nil] )
  ['TERM', 'INT'].each { |sig| trap(sig){ $www_server.shutdown } }

  $www_server.mount(RefreshableTextDoc::PATH, RefreshableTextDoc)
  $www_server.mount(StaticTextDoc::PATH, StaticTextDoc)

  Thread.new { $www_server.start }
end

class UtApp 
  include PlanR::Application
  def initialize
    #use ConfigManager
    use PluginManager
    #use DatabaseManager
    use CommandQueue

    PlanR::Application::Service.init_services
    PlanR::Application::Service.startup_services(self)
  end
end

# ----------------------------------------------------------------------
# Document Manager tests
CONTENT_BASE = shm_repo('test-doc-mgr')

class TC_DocMgrTest < Test::Unit::TestCase

  def test_0_0_initialize
    @app = UtApp.new
  end

  # ==============================================
  # 1.x : PROJECT

  def test_1_0_create_repo
    $repo = PlanR::Project.create('test-docmgr-proj', CONTENT_BASE)
    assert_equal('test-docmgr-proj', $repo.name)
  end

  # ==============================================
  # 2.x : LOCAL DOCUMENTS

  def test_2_0_import_raw
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager

    mgr.import_raw($repo, '/2_0/raw_import', 'imported text')
    assert($repo.exist? '/2_0/raw_import')

    doc = mgr.document($repo, '/2_0/raw_import')
    assert_equal('imported text', doc.contents)
  end

  def test_2_1_import_doc
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager
    mgr.import($repo, 'NOTES', '/2_1')
    # TODO: document manager for this? exist, class/type
    assert($repo.exist? '/2_1/NOTES')
    mgr.import($repo, 'README', '/')
    assert($repo.exist? '/README')
    # import repo, origin, dest_path, &block
  end

  def test_2_2_import_dir
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager
    mgr.import_dir($repo, 'doc', '/2_2')
  # import_dir repo, path, dest_path, &block
  end

  # ==============================================
  # 3.x : DOCUMENT MANAGEMENT

  def test_3_0_new_items
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager
  # new_filename repo, path, tree=DATA_DOC
  # new_document repo, tree, dest_path, contents, props=nil
  # new_folder repo, dest_path, props={}
  end

  def test_3_1_move_items
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager
  # move doc, dest_path
  # move_path from_path, to_path # operates on all data trees
  end

  def test_3_2_remove_items
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager
    #mgr.complete_tasks
  # remove doc
  end

  # ==============================================
  # 4.x : REMOTE DOCUMENTS

  # TODO: test fetch-and-mirror ?
  def test_4_0_static_remote_document
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager

    doc = mgr.import($repo, StaticTextDoc.uri.to_s, '/4_0')
    mgr.complete_tasks

    doc = mgr.document(repo, doc.path)
    assert_equal('static text', doc.contents)

    doc = mgr.document($repo, doc.path)
    doc.regenerate
    mgr.complete_tasks

    doc = mgr.document($repo, doc.path)
    assert_equal('static text', doc.contents)
  end

  def test_4_1_dynamic_remote_document
    assert_not_nil($repo, 'Repo not created')
    mgr = PlanR::Application::DocumentManager

    doc = mgr.import($repo, RefreshableTextDoc.uri.to_s, '/4_1')
    mgr.complete_tasks

    doc = mgr.document($repo, doc.path)
    assert_equal(1000, doc.contents.to_i)

    doc = mgr.document($repo, doc.path)
    doc.regenerate
    mgr.complete_tasks

    doc = mgr.document(repo, doc.path)
    assert_equal(1001, doc.contents.to_i)

    doc = mgr.document(repo, doc.path)
    mgr.refresh_doc(doc)
    mgr.complete_tasks

    doc = mgr.document(repo, doc.path)
    assert_equal(1002, doc.contents.to_i)
  end

  # ==============================================
  # 5.x : DOCUMENT PARSING/ANALYSIS
  # parse_doc doc # -> pdoc. internal 
  # ident_data data, filename # -> Ident. internal.
  # analyse_doc doc # wrapper. internal
  # analyse_doc_backend doc # internal
  # time w/, w/o command queue?

  def test_9999_application_cleanup
    PlanR::Application::Service.shutdown_services(@app)
  end
end


# ----------------------------------------------------------------------
# Initialization

# Clear repo
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)
Dir.mkdir(CONTENT_BASE)

# Start remote document server
start_www_server

# Start PlanR application
#PlanR::Application::ConfigManager.init
#PlanR::Application::PluginManager.init

#PlanR::Application::ConfigManager.startup(PlanR::Application.fake)
#PlanR::Application::PluginManager.startup(PlanR::Application.fake)

#at_exit { PlanR::Application::PluginManager.shutdown(PlanR::Application.fake) }
#['TERM', 'INT'].each { |sig| trap(sig){ PlanR::Application::PluginManager.shutdown(PlanR::Application.fake)} }
