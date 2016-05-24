#!/usr/bin/env ruby
# :title: PlanR::Plugins::Parser::ASCII
=begin rdoc
Fallback parser for ASCII documents
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

module PlanR
  module Plugins
    module Parser

=begin rdoc
Parser for ASCII plaintext files. This creates text blocks by splitting the
document on blank lines.
=end
      class Ascii
        extend TG::Plugin
        name 'ASCII Parser'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Parsing of ASCII files. This just file contents.'
        help 'This is a simple parser for plaintext documents. It returns the
 contents of the document as the parsed data. There is no formatting to parse
 in plaintext, so this is a no-op.'

        def get_title(buf)
          # title is first sentence.
          first_line = buf.lines.first
          title = first_line =~ /^([^.?!]+[.?!])/ ? $1 : first_line
          title.gsub(/[[:space:]]/, ' ').strip.rstrip
        end

        def parse_ascii(doc)
          pdoc = PlanR::ParsedDocument.new(name, doc)
          begin
            data = doc.contents.encode('US-ASCII', invalid: :replace, 
                                       undef: :replace, replace: '?') 
            pdoc.properties[:title] = get_title(data)
            # use non-printable characters to distinguish blocks
            data.split(/[^[:print:]]/).map { |s| 
              # ...then use blank lines to further distinguish blocks
              s.split(/[\n\r\f]/) 
            }.flatten.select { |s|
              # ...then select blocks with a sequence of 3+ letters
              s =~ /[[:alpha:][:punct:]]{3,}/
            }.each { |blk|  pdoc.add_text_block blk  }
          rescue Exception => e
            # FIXME: log
            $stderr.puts "[ASCII] ERROR #{e.message}"
            $stderr.puts e.backtrace[0,4].join("\n")
          end
          pdoc
        end
        spec :parse_doc, :parse_ascii, 50 do |doc|
          # TODO: handle unicode correctly?
          next 70 if ((doc.properties[:mime_type] || '').start_with? 'text/')
          next 0 if (doc.properties[:encoding] == 'binary')
          (doc.contents =~ /^[[:print:][:space:]]+$/) ? 30 : 0
        end
      end

    end
  end
end
