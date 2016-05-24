#!/usr/bin/env ruby
# :title: PlanR::Plugins::Parser::Null
=begin rdoc
Fallback parser for unrecognized inary documents
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

module PlanR
  module Plugins
    module Parser

=begin rdoc
This parser is used for unknown file formats that are non-ASCII
=end
      class Null
        extend TG::Plugin
        name 'Null Parser'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Parsing of binary files. This returns strings in file.'
        help 'This parser is invoked when on binary files of unknown type.
It is the equivalent of running strings(1) on the file.'

        api_doc :strings, ['String data'], 'Array strings', 
                'Return all strings of 3+ characters in binary data String'
        def strings(buf)
          # NOTE: regex and string are both forced to 8-bit ASCII - otherwise,
          #       a binary will give Invalid-UTF8 Sequence error
          # Shouldn't be necessary -- 'binary' is a catch-all in regexp
          if buf.length > 100000000
            # FIXME : log
            $stderr.puts "[NULL PARSER] warning: parsing #{buf.length} bytes"
          end
          exp = "[^[:print:]]+".force_encoding("binary")
          regexp = Regexp.new(exp, Regexp::FIXEDENCODING)
          buf.split(regexp).select { |s| s.length >= 3 }
        end

        # NOTE: this is really not a good idea with stuff like PDF.
        #        should definitely come up with a PDF parser, even a dummy
        def parse_strings(doc)
          pdoc = PlanR::ParsedDocument.new(name, doc)
          begin
          data = doc.contents
          strings(data).each { |s| pdoc.add_text_block s if s }
          rescue Exception => e
            $stderr.puts "[NULL PARSER] ERROR: #{e.message}"
            $stderr.puts e.backtrace[0,4].join("\n")
          end
          pdoc
        end
        # This is a fallback. It will always return a score of 1.
        spec :parse_doc, :parse_strings, 1
      end

    end
  end
end
