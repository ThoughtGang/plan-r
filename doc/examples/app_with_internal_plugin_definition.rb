#!/usr/bin/env ruby
# Example of a simple CLI application that adds a document to a repo.
# This includes a built-in plugin for parsing Unicode documents.

require 'uri'
require 'plan-r/project'
require 'plan-r/datatype/document'
# needed for plugin manager to work
require 'plan-r/application'
require 'plan-r/application/importer'

# For plugin defs
require 'plan-r/plugin'

# define a local, in-app plugin
# NOTE: this is just a dumbed-down versin of the ASCII parser plugin
class UnknownParserPlugin
  extend PlanR::Plugin
  name 'UnknownParser'
  author 'mkfs@thoughtgang.org'
  version '0.01'
  description 'Parser for unicode documents'
  help 'Generates a ParsedDocument with Unicode converted to ASCII'

  def parse_unicode(doc)
    pdoc = PlanR::ParsedDocument.new(name, doc)
    # re-encode contents as ASCII, replacing invalid characters with '?'
    ascii = doc.contents.encode('US-ASCII', invalid: :replace, undef: :replace,
                                replace: '?')
    # add a single text block for the entire document, converted to ASCII
    pdoc.add_text_block(ascii)
  end
  spec :parse_doc, :parse_unicode, 25
end

if __FILE__ == $0
  if ARGV.count < 2
    # path is the file to import; loc is the path/name in the content repo
    # default is top-level of project
    $stderr.puts "Usage: #{$0} PROJECT PATH [LOC]"
    exit 1
  end
  proj_path, doc_path, repo_path = ARGV
  if ! File.exist? proj_path
    $stderr.puts "Project does not exist: #{proj_path}"
    return -1
  end
  repo_path = '' if not repo_path

  PlanR::Application::ConfigManager.init
  PlanR::Application::PluginManager.init

  puts "Opening project #{proj_path}"
  proj = PlanR::Project.new(proj_path)

  puts "Adding to project #{doc_path}"
  PlanR::Application::Importer.import(proj.repo, doc_path, repo_path) if proj

  puts "Shutting down..."
  PlanR::Application::PluginManager.shutdown(PlanR::Application.fake)
end
