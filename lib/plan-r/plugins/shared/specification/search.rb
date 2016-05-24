#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Search
=begin rdoc
Specifications for Search Engine plugins

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/datatype/analysis_results'
require 'plan-r/document'
require 'plan-r/datatype/query'
require 'plan-r/datatype/token_stream'
require 'plan-r/repo'

# TODO: document clusters?

module PlanR
  module Plugins
    module Spec

      # ----------------------------------------------------------------------
      # ANALYZE DOCUMENT
      # Input: A PlanR::ParsedDocument object to be analyzed.
      # Output: an AnalysisResults object
      TG::Plugin::Specification.new( :analyze_doc,
                                     'fn(ParsedDocument)',
                                     [PlanR::ParsedDocument],
                                     [PlanR::AnalysisResults] 
                                   )

      # ----------------------------------------------------------------------
      # TOKENIZE DOCUMENT
      # A tokenizer plugin can apply the results of an analysis plugin to a
      # Parsed Document in the generation of a tokenstream.
      # tokenizer -> stemmer -> stop-words filter
      #
      # Input: A PlanR::ParsedDocument object to be analyzed, and a Hash
      # [ Name -> AnalysisResults] of Analysis plugin output (can be empty).
      # Output: a PlanR::TokenStream object
      TG::Plugin::Specification.new( :tokenize_doc,
                                     'fn(ParsedDocument, Hash)',
                                     [PlanR::ParsedDocument, Hash],
                                     [PlanR::TokenStream] 
                                   )
      # ----------------------------------------------------------------------
      # INDEX DOCUMENT
      # Input: A PlanR::Repo, a Document object, and a
      #        Hash [Name -> TokenStream] of tokenized documents.
      # Output: Success/Failure
      TG::Plugin::Specification.new( :index_doc,
                                     'fn(Repository, Document, Hash)',
                                     [PlanR::Repo, 
                                      PlanR::Document, 
                                      Hash],
                                     [TrueClass,FalseClass] 
                                   )

      # ----------------------------------------------------------------------
      # QUERY INDEX
      # Input: A PlanR::Repo, Query
      # Output: Array of QueryResult objects

      TG::Plugin::Specification.new( :query_index,
                                     'fn(Repository, Query)',
                                     [PlanR::Repo, PlanR::Query],
                                     [Array] 
                                   )

      # ----------------------------------------------------------------------
      # QUERY PARSE
      # Parse a query into an intermediate form for diagnostic purposes.
      # Input: A PlanR::Repo, Query
      # Output: Hash representing parsed query

      TG::Plugin::Specification.new( :query_parse,
                                     'fn(Repository, Query)',
                                     [PlanR::Repo, PlanR::Query],
                                     [Hash] 
                                   )

      # ----------------------------------------------------------------------
      # RELATED DOCS
      # Input: A Document
      # Output: RelatedDocuments collection
      # NOTE: doc.repo is used to access Repository object
       TG::Plugin::Specification.new( :related_docs, 'fn(Document)',
                                      [PlanR::Document], 
                                      [PlanR::RelatedDocuments] 
                                   )


      # ----------------------------------------------------------------------
      # INDEX KEYWORDS
      # Input: A PlanR::Repo, Hash [Symbol -> value] of options
      #        Supported Options:    
      #          :stats => [true|false]
      # Output: Array of keywords or Hash [String -> Hash] of keywords to stats

      TG::Plugin::Specification.new( :index_keywords, 'fn(Repository, Hash)',
                                     [PlanR::Repo, Hash],
                                     [Array,Hash] 
                                   )

      # ----------------------------------------------------------------------
      # SEARCH INDEX STATS
      # Diagnostic information returned by an index
      # Input: A PlanR::Repo, Hash [Symbol -> value] of options
      # Output: A Hash [String -> Object] of plugin-specific index stats
      TG::Plugin::Specification.new( :index_stats, 'fn(Repository, Hash)',
                                     [PlanR::Repo, Hash],
                                     [Hash] 
                                   )

      # ----------------------------------------------------------------------
      # SEARCH INDEX DOCUMENTS
      # Return Array of documents [ctype, path] indeed by Search Index
      # Input: A PlanR::Repo, Hash [Symbol -> value] of options
      # Output: An Array of [ctype, path] pairs
      TG::Plugin::Specification.new( :index_docs, 'fn(Repository, Hash)',
                                     [PlanR::Repo, Hash],
                                     [Array] 
                                   )

      # ----------------------------------------------------------------------
      # SEARCH INDEX REPORT
      # Printable diagnostic information returned by an index
      # Input: A PlanR::Repo, Hash [Symbol -> value] of options
      # Output: A String
      TG::Plugin::Specification.new( :index_report, 'fn(Repository, Hash)',
                                     [PlanR::Repo, Hash],
                                     [String] 
                                   )

      # ----------------------------------------------------------------------
      # SEARCH INDEX LOG
      # Logfiles for an index
      # Input: A PlanR::Repo, Hash [Symbol -> value] of options
      # Output: A String
      TG::Plugin::Specification.new( :index_log, 'fn(Repository, Hash)',
                                     [PlanR::Repo, Hash],
                                     [String] 
                                   )
       

    end
  end
end
