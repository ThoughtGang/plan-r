#!/usr/bin/env ruby
# :title: PlanR::Plugins::Parser::Poppler
=begin rdoc
Built-in HTML and XML parser
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

require 'shellwords'

module PlanR
  module Plugins
    module Parser

=begin rdoc
Poppler-based plugin
=end
      class Poppler
        extend TG::Plugin
        name 'Poppler Parser'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Parse PDFs using Poppler command-line utilities'
        help 'Invoked pdfinfo and pdftotext on Document'

        PARSE_UTIL='pdftotext' # NOTE: could do pdftohtml + Nokogiri
        INFO_UTIL='pdfinfo'
        # FIXME: disable/blacklist plugin if these utils are missing

        # ---------------------------------------------------------------------
        # PARSE

=begin rdoc
Use Poppler to generate a ParsedDocument for the source document
=end
        def parse(doc)
          pdoc = PlanR::ParsedDocument.new(name, doc)

          begin
            safe_fname = Shellwords.escape(doc.abs_path)
            # FIXME: capture STDERR so these messages disappear:
            #        Syntax Error: Invalid object stream
            #        Syntax Error: Expected the optional content group list, but wasn't able to find it, or it isn't an Array
            info = %x{#{INFO_UTIL} -enc UTF-8 #{safe_fname}}.chomp
            properties_from_info(pdoc, info)
            # TODO: support pdftotext options?
            text = %x{#{PARSE_UTIL} -q -enc UTF-8 #{safe_fname} - }.chomp
            pdoc.add_text_block(text)
          rescue Exception => e
            # FIXME: log
            $stderr.puts "[POPPLER] ERROR #{e.message}"
            $stderr.puts "INPUT: #{doc.abs_path}"
            $stderr.puts e.backtrace[0,4].join("\n")
          end
          pdoc
        end
        # NOTE: spec has a low rating because we want to use native PDF parsers
        #       if available
        spec :parse_doc, :parse, 40 do |doc|
          next 0 if `which #{PARSE_UTIL}`.empty?
          next 20 if `which #{INFO_UTIL}`.empty?
          ['application/pdf', 'application/x-pdf', 
           'text/pdf', 'test/x-pdf',
           'application/acrobat', 'applications/vnd.pdf'
          ].include?(doc.properties[:mime_type]) ? 40 : 0
        end

        private

        PROP_KEY_MAP = {
          'title' => PlanR::Document::PROP_TITLE,
          'author' => PlanR::Document::PROP_AUTHOR,
          'subject' => PlanR::Document::PROP_SUBJECT,
          'keywords' => PlanR::Document::PROP_KEYWORDS
        }
        def properties_from_info(pdoc, info)
          delim = ':'.force_encoding('UTF-8')
          # FIXME: extract into utils StringCleanup
          info = info.encode('UTF-8', invalid: :replace, undef: :replace,
                              replace: '?') 
          info.lines.each do |line|
            k,v = line.chomp.split(delim, 2)
            prop = PROP_KEY_MAP[k.downcase]
            pdoc.properties[prop] = v if prop
          end
        end

      end

    end
  end
end
