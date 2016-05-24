#!/usr/bin/env ruby
# :title: PlanR::Plugins::Search::Tag
=begin rdoc
=Tag Search Plugin
Search for documents by tag
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/plugins/shared/picky/index'

require 'plan-r/datatype/query'

require 'picky'

module PlanR
  module Plugins
    module Search

=begin rdoc
NOTE: This is implemented in a non-standard way: hooks are used on tag-change
and doc-remove, rather than implementing the :index_doc and :index_relocate
specifications.
=end
      class PickyTag
        extend TG::Plugin
        name 'Tag Index'
        author 'dev@thoughtgang.org'
        version '0.5'
        description 'Query documents by tag using Picky gem'
        help 'A search plugin that performs a search of OR-ed tag names.
See http://pickyrb.com/'

        INDEX_BASE_NAME = 'tags'
        INDEX_PROP_NAME = :picky_tag_index_name
        include PlanR::Plugins::Picky

        # need to use a standard tokenizer, because the first thing the Picky
        # tokenizer does is call to_s on the input (an array of tags)
        class LowercaseTokenizer
          def tokenize(arr)
            [ arr.map { |x| x.downcase } ]
          end

          def stemmer?
            false
          end
        end

        def load_index(repo)
          idx_name = open_index(repo)

          idx = DocIndex.new(idx_name, repo, index_base_name) do
            key_format :to_s
            indexing LowercaseTokenizer.new
            category :tags
            #                partial: Partial::Substring.new(from: 1),
            #                similarity: Similarity::None.new
            # tag_logger.info results
            result_identifier 'tags'
            # TODO: more? path?
          end

          read_index(idx)
        end
        spec :repo_open, :load_index, 50

        def save_index(repo)
          idx = fetch_index(repo)
          return nil if (! idx)
          # WTF why does this print "D" ??
          idx.dump
        end
        spec :repo_close, :save_index, 50

        # NOTE: This uses a hook instead of move_index_doc
        def update_document_tags(doc)
          idx = fetch_index(doc.repo)
          return nil if (! idx)
          # no way to check if doc exists in index! just call replace (add/del)
          idx.replace(doc)
          # FIXME: update cached list of known tags, if cached
        end
        spec :repo_doc_tag_change, :update_document_tags, 50

        def remove_doc_from_index(doc)
          idx = fetch_index(doc.repo)
          return nil if (! idx)
          idx.remove doc.id
        end
        spec :repo_remove_doc, :remove_doc_from_index, 50

        def query(repo, q)
          idx = fetch_index(repo)
          return [] if (! idx)
          begin
            # FIXME: make this a saved object? part of index?
            s = ::Picky::Search.new(idx) do 
              searching LowercaseTokenizer.new
            end
            # FIXME: more complex options
            results = s.search(q.terms)
=begin
This returns ids [3, 1] and the allocations [ [:people, 0.0, 2, [ [:first, "donald", "donald"] ], [3, 1]] ]. That might look a little funny, so let me explain: :people is the index name where it was found. 0.0 is the total weight. 2 is the total number of ids in this “allocation” (combination of categories). [:first, "donald", "donald"] is the category the query word was found in, together with the token and the original.
=end
            # NOTE: following info might be useful:
            #  results.duration
            #  results.offset
            #  results.amount
            #  results.query
            #  results.sorting
            # This is results#allocations:
            arr = []
            results.each do |x| 
               res = x.to_result
               #ident = res[0] # index identifier
               score = res[1]
               #count = res[2] # number of hits
               #combs = res[3] # combinations.to_result

               res[4].each do |id|
                 ctype, path = id.split(':', 2)
                 r = Query::Result.new(path, ctype.to_sym, score)
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

        def related_docs(doc)
          # FIXME: implement
          # ratio: (tag-overlap / tags-in-doc) : always 0..1
          PlanR::RelatedDocuments.new
        end
        # tags has a fairly high related-documents score
        spec :related_docs, :related_docs, 70

        # ----------------------------------------------------------------------
        # INDEX STATS
        def list_keywords(repo, h)
          idx = fetch_index(repo)
          return [] if (! idx)
          rv = idx.facets(:tags)
          # FIXME: cache list of known tags for repo
          h[:stats] ? rv : rv.keys
        end
        spec :index_keywords, :list_keywords, 50

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

      end

    end
  end
end
