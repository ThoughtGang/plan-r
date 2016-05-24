#!/usr/bin/env ruby
# :title: PlanR::Plugins::Analysis::WhatLanguage
=begin rdoc
Determines language of content
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'
require 'plan-r/datatype/analysis_results'

require 'whatlanguage'

module PlanR
  module Plugins
    module Analysis

      class WhatLanguage
        extend TG::Plugin
        name 'WhatLanguage text analysis'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Identify language of file via WhatLanguage plugin'
        help 'This uses ParsedDocument#plaintext_ascii to determine the
language of a File. Note that the WhatLanguage plugin does not support UTF-8.
The AnalysisReults object contains the keys :language and :language scores.'

        def analyze_lang(pdoc)
          adoc = PlanR::AnalysisResults.new(name, pdoc)
          begin
            wl = ::WhatLanguage.new(:all)
            data = pdoc.plaintext_ascii
            adoc[:language] = wl.language(data).to_s
            adoc[:language_scores] = wl.process_text(data)
          rescue Exception => e
            # FIXME: log
            $stderr.puts 'Exception in what_language plugin: ' + e.message
            $stderr.puts e.backtrace[0,4].join("\n")
          end
          adoc
        end
        spec :analyze_doc, :analyze_lang, 70
        # FIXME: reduce score if original document is non-ASCII

      end

    end
  end
end
