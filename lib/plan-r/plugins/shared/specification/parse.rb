#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Parse
=begin rdoc
Specification for file parser plugins

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

module PlanR
  module Plugins
    module Spec

      # ----------------------------------------------------------------------
      # PARSE DOCUMENT
      # Generates a ParsedDocument object from a Document.
      #
      # Input: A PlanR::Document object to be parsed.
      # Output: A PlanR::ParsedDocument object
      TG::Plugin::Specification.new( :parse_doc,
                                     'fn(Document)',
                                     [PlanR::Document],
                                     [PlanR::ParsedDocument] 
                                   )

      # ----------------------------------------------------------------------
      # UNPACK DOCUMENT
      # Used to build compound documents. This is intended to create child
      # documents such as Notes or Tables under the original Document.
      #
      # Input: A PlanR Document
      # Output: Success/Failure
      TG::Plugin::Specification.new( :unpack_doc, 'fn(Document)',
                                  [PlanR::Document],
                                  [TrueClass,FalseClass] 
                                  )

      # ----------------------------------------------------------------------
      # REBASE DOCUMENT
      # This repairs links to resources in a document that has been moved
      # in the Repository. The plugin should update the relative path to the
      # Repository resources directory in all links.
      #
      # Input: A PlanR Document
      # Output: Success/Failure
      TG::Plugin::Specification.new( :rebase_doc, 'fn(Document)',
                                  [PlanR::Document],
                                  [TrueClass,FalseClass] 
                                  )
    end
  end
end
