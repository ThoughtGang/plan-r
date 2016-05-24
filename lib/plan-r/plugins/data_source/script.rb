#!/usr/bin/env ruby
# :title: PlanR::Plugins::DataSource::Script
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'uri'

require 'tg/plugin'

require 'plan-r/application/script_mgr'

module PlanR
  module Plugins
    module DataSource

=begin rdoc
Data source for executing a Script to rebuild a document.
=end
      class Script
        extend TG::Plugin
        name 'Script Data Source'
        author 'dev@thoughtgang.org'
        version '1.0-alpha'
        description 'Generate document contents from script URI'
        help 'This execute a Script content node and generates a Document from its output.
The script URI is a repo path prefixed by script://. e.g. script:///stats.sh 
for the script /stats.sh in the repository.'

        def load_from_script(url, repo)
          uri = URI.parse(url)
          scpt = PlanR::Application::ScriptManager.script(repo, uri.path)
          q = uri.query
          query = (q and (! q.empty?)) ? split('&').inject({}){ |h,i| 
                  k,v = i.split('='); h[k.to_sym] = v; h } : {}
          doc = nil
          if (query[:doc_path] and query[:doc_tree])
            # this document was generated with another document as input
            doc = Document.factory(repo, query[:doc_path],
                                   query[:doc_type].to_sym)
          end
          PlanR::Application::ScriptManager.exec_on_doc(scpt, doc)
        end
        spec :data_source, :load_from_script, 20 do |origin, repo|
          begin
            uri = URI.parse(origin)
            ('script'.casecmp(uri.scheme) == 0) ? 90 : 0
          rescue Exception => e
            0 # Not a URI
          end
        end
      end

    end
  end
end

