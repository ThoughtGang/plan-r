#!/usr/bin/env ruby
# :title: PlanR::Plugins::Picky Domain-specific Search
=begin rdoc
=Picky Plugins
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/plugins/shared/picky/index'


module PlanR
  module Plugins
    module Search

      class PickyDomainIndex
        extend TG::Plugin
        name 'Domain-Specific Document Index'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'Domain-specific document index based on Picky gem'
        help 'This uses per-repo dictionaries to provide domain-sensitive 
indexing of documents. The user can define dictionaries used to map different
words or phrases (e.g. synonyms, abbreviations) to a single word or phrase.
WARNING: NOT IMPLEMENTED
Based on http://pickyrb.com/'

        INDEX_BASE_NAME = 'dsdoc'
        INDEX_PROP_NAME = :picky_dsdoc_index_name
        include PlanR::Plugins::Picky

=begin rdoc
This is a tab-delimited file with the following format:
  REGEXP\tREPLACEMENT
REGEXP is passed directly to Regexp.new, so it should not be enclosed in slashes
(e.g. /regexp/). The string is not interpolated, so special characters like
\t and \n will be ignored.

This is used to define replacements for terms, e.g. 'assembler' and 'assembly
language' can be replaced with asm:
  assembler\tasm
  assembly language\tasm
Other normalizations can be performed, such as expanding currency symbols:
  \$(\w+)\t\1 USD
=end
        # FIXME: This should be a JSON file of actual regexes
        NORMALIZER_FILE = 'ds-docs_normalizers.dat'

        def tokenize(doc, h)
          begin
            data = doc.plaintext_utf8
            (@normalizers || []).each do |regexp, str|
              data.gsub!(regexp, str)
            end
            # FIXME: options!
=begin
  removes_characters          /regexp/
  stopwords                   /regexp/
  splits_text_on              /regexp/ or "String", default /\s/
  normalizes_words            [[/replace (this)/, 'with this \\1'], ...]
  rejects_token_if            Proc/lambda, default :empty?.to_proc
  substitutes_characters_with Picky::CharacterSubstituter or responds to #substitute(String)
  stems_with                  Instance responds to #stem(String)
  case_sensitive              true/false
=end
            tokenizer = ::Picky::Tokenizer.new {}
            toks, words = tokenizer.tokenize(data)
            PlanR::TokenStream.from_array(name, doc, toks )
          rescue Exception => e
            # FIXME: log
            $stderr.puts "[PICKY PARSER] ERROR: #{e.message}"
            $stderr.puts e.backtrace[0,4].join("\n")
            PlanR::TokenStream.from_array(name, doc, [])
          end
        end
        spec :tokenize_doc, :tokenize, 10 do |doc, h|
          10
        end

        def load_index(repo)
          load_normalizers(repo)

          idx_name = open_index(repo)

          # define index
          idx = DocIndex.new(idx_name, repo, index_base_name) do
            key_format :to_s
            #indexing normalizes_words: @normalizers
            # partial: Picky::Partial::Substring.new(from: 1, to: -1)

            category :tags, tokenize: false
            category :keywords, tokenize: false,
                                weight: ::Picky::Weights::Logarithmic.new(+1)
            category :name
            category :title, weight: ::Picky::Weights::Logarithmic.new(+1)
            category :description, weight: ::Picky::Weights::Logarithmic.new(+1)
            category :summary, weight: ::Picky::Weights::Logarithmic.new(-1)
            category :topics, tokenize: false,
                              weight: ::Picky::Weights::Logarithmic.new(-1)
            category :abstract, weight: ::Picky::Weights::Logarithmic.new(+1)
            category :contents, tokenize: false
            result_identifier 'dsdocs'
          end

          read_index(idx)
        end
        spec :repo_open, :load_index, 50

        def save_index(repo)
          idx = fetch_index(repo)
          return nil if (! idx)
          idx.dump
        end
        spec :repo_close, :save_index, 50

        def index_document(repo, doc, tok_h)
          toks = tok_h[self.name]
          pdoc = PickyDocument.new(doc, toks)
          idx = fetch_index(doc.repo)
          return false if (! idx)
          len = pdoc.contents.length 
          if len > 50000
            # FIXME: log
            $stderr.puts "[PICKY] WARNING: Indexing #{len} tokens"
          end
          idx.add(pdoc)
          true
        end
        spec :index_doc, :index_document, 50

        def copy_document(repo, from_doc, to_doc)
          idx = fetch_index(doc.repo)
          return false if (! idx)
          return true if (! idx.indexed? from_doc)
          idx.add to_doc
        end
        spec :repo_clone_doc, :copy_document, 50

        def remove_document(doc)
          idx = fetch_index(doc.repo)
          return nil if (! idx)
          return true if (! idx.indexed? doc)
          idx.remove doc.id
        end
        spec :repo_remove_doc, :remove_document, 50

        def query(repo, q)
          idx = fetch_index(repo)
          return [] if (! idx)
          begin
            s = ::Picky::Search.new(idx) { 
              #searching normalizes_words: @normalizers
              # FIXME: more complex options
              ignore_unassigned_tokens 
            }
            results = s.search(q.terms.join(' '))
            arr = []
            results.each do |x|
               res = x.to_result 
               next if (! res)  # FIXME: better error checking
               #ident = res[0] # index identifier
               score = res[1]
               #count = res[2] # number of hits
               #combs = res[3] # combinations.to_result

               res[4].each do |id|
                 ctype, path = id.split(':', 2)
                 r = Query::Result.new(path, ctype.to_sym, score)
                 # FIXME:
                 # r.terms = { term -> { :field -> :pos } }
                 arr << r
               end
            end

            arr

          rescue Exception => e
            puts e.message
            puts e.backtrace[0,4].join("\n")
            []
          end
        end
        spec :query_index, :query, 50

        def related_documents(doc)
          # FIXME: TODO
        end
        spec :related_docs, :related_documents, 50

        # TODO: stats
        # QUERY:
        # [default set of categories to boost]
        # boost importance of field/category 'title'
        # boost [:title] => +1
        # boost [:first, :last] => +3  # combo boosted if in this order
        # ignore :title # ignore this category
        # ignore_unassigned_tokens # always use this unless 'strict'

        # ----------------------------------------------------------------------
        # INDEX STATS

        CATEGORIES = [ :tags, :keywords, :name, :title, :description,
                       :summary, :topics, :abstract, :contents ]
        def list_keywords(repo, h)
          idx = fetch_index(repo)
          return [] if (! idx)
          toks = {}
          begin
          # FIXME: make sure this is correct
          CATEGORIES.each do |tag|
            idx.facets(tag).each { |k,v| toks[k] ||= 0; toks[k] += v }
          end
          rescue Exception => e
            $stderr.puts "[DS-DOC] #{e.message}"
            $stderr.puts "[DS-DOC] .. #{e.backtrace[0]}"
            $stderr.puts "[DS-DOC] .. #{e.backtrace[1]}"
          end
          h[:stats] ? toks : toks.keys
        end
        spec :index_keywords, :list_keywords, 50

        def list_docs(repo, h)
          idx = fetch_index(repo)
          return [] if (! idx)
          idx.indexed_ids.map { |id| id.split(':', 2) }
        end
        spec :index_docs, :list_docs, 50

        def generate_stats(repo, h)
          idx = fetch_index(repo)
          return nil if (! idx)
          # FIXME : implement
          #idx.exact.inverted
          #idx.exact.weights
          #idx.partial.inverted
          #idx.partial.weights
          {}
        end
        spec :index_stats, :generate_stats, 50

        def generate_log(repo, h)
          idx = fetch_index(repo)
          return nil if (! idx)

          # FIXME : implement
          ''
        end
        spec :index_log, :generate_log, 50

        def generate_report(repo, h)
          idx = fetch_index(repo)
          return nil if (! idx)
          idx.to_tree_s
        end
        spec :index_report, :generate_report, 50

        def query_to_hash(repo, q)
          idx = fetch_index(repo)
          return nil if (! idx)
          # FIXME: implement
          {}
        end
        spec :query_parse, :query_to_hash, 50

        private
        def load_normalizers(repo)
          @normalizers = nil
          path = File.join(repo.base_path, NORMALIZER_FILE)
          return if (! File.exist? path)
          # FIXME: use JSON and real regexp
          File.open(path) do |f|
            f.each_line do |line|
              regexp, str = line.chomp.split("\t", 2)
              next if regexp.empty?
              @normalizers ||= []
              @normalizers << [Regexp.new(regexp), str]
            end
          end
        end
      end

    end
  end
end
