#!/usr/bin/env ruby
# :title: PlanR::Plugins::Analysis::WhatLanguage
=begin rdoc
Produces summary of content
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'
require 'plan-r/datatype/analysis_results'

require 'summarize'

module PlanR
  module Plugins
    module Analysis

=begin rdoc
A document analysis plugin based on the summarize gem, which uses 
Open Text Summarizer.
=end
      class OTSummarize
        extend TG::Plugin
        name 'Summarize text'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Produce a summary of the document contents'
        help 'This uses ParsedDocument#plaintext_utf8 to generate a summary
of the document contents. The AnalysisReults object contains the keys 
:summary and :topics.'

        DICT_FILENAME = 'summarize_stemming_rules.xml'
        def summarize_doc(pdoc)
          adoc = PlanR::AnalysisResults.new(name, pdoc)
          begin
            # TODO: specify language code
            # .summarize(:language => 'pt', :ratio => 50)
            opts = { :topics => true }
            opts[:dictionary] = @dictionary_path if (@dictionary_path)

            content, topics = pdoc.plaintext_utf8.summarize(opts)

            content.force_encoding('UTF-8')
            topics.force_encoding('UTF-8')
            adoc[:summary] = content
            adoc[:topics] = topics.split(',')
          rescue Exception => e
            # FIXME: log
            $stderr.puts 'Exception in summary plugin: ' + e.message
            $stderr.puts e.backtrace[0,4].join("\n")
          end
          adoc
        end
        spec :analyze_doc, :summarize_doc, 70 
        # TODO: check contents for language etc

=begin rdoc
Use custom stemmer dictionary if it exists.
This uses a fixed pathname in the repo root directory. The pathname could be
stored as a repo property, but then we'd have to distinguish between in-repo
and outside-of-repo paths.
The name of the stemmer dictionary is 'summarize_stemming_rules.xml'.
=end
        def load_summary_dictionary(repo)
          path = File.join(repo.base_path, DICT_FILENAME)
          @dictionary_path = path if (File.exist? path)
        end
        spec :repo_open, :load_summary_dictionary, 50

      end

    end
  end
end
