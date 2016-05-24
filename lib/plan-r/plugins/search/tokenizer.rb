#!/usr/bin/env ruby
# :title: PlanR::Plugins::Tokenizer
=begin rdoc
=Failsafe Tokenizer Plugin
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Plugins
    module Tokenize

=begin rdoc
This is a no-op tokenizer that extracts the plaintext from a parsed document
and splits it on whitespace (via regex /\s/).
=end
      class Plaintext
        extend TG::Plugin
        name 'Plaintext Tokenizer'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Plaintext whitespace tokenizer'
        help 'Extracts doc#plaintext_ascii and splits it on whitespace.'

=begin rdoc
Failsafe tokenizer. This just splits doc.plaintext on whitespace.
=end
        def tokenize(doc, h)
          begin
            PlanR::TokenStream.from_array(name, doc, 
                                          doc.plaintext_ascii.split(/\s/) )
          rescue Exception => e
            # FIXME: log
            $stderr.puts "[PLAINTEXT PARSER] ERROR: #{e.message}"
            $stderr.puts e.backtrace[0,4].join("\n")
            # FIXME: better default return value
            PlanR::TokenStream.from_array(name, doc, [])
          end
        end
        spec :tokenize_doc, :tokenize, 10 do |doc, h|
          10
        end
      end

    end
  end
end
