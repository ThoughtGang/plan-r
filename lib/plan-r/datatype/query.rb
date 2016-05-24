#!/usr/bin/env ruby
# :title: PlanR::Query
=begin rdoc
Object representing an index Query.

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

# WARNING: this code is under active development and highly subject to change

require 'plan-r/util/json'

# TODO: Generic Stats object to be returned by :index plugins. Will be used for
#       keywords, document count, document keywords, and related_docs.
#       Spec for :keywords provides for options that determine extent of results

module PlanR

=begin rdoc
Object representing a search query.
=end
  class Query
    extend JsonClass
    include JsonObject

    # field, weight?
    #class QueryField
    #end
    #class QueryTerm
    # * weight
    # * proximity
    # * required
    #end
=begin rdoc
A query result.
This associates a document in the repo (via path) with a score and a list
of terms
=end
    class Result
      attr_accessor :path
      attr_accessor :ctype
      attr_accessor :score
      attr_accessor :terms # { term -> { :field -> :pos } }

      # TODO: return hash of term -> freq ?
      def initialize(path, ctype, score)
        @path = path
        @ctype = ctype
        @score = score
        @terms = {}
      end

      def add_term( term, field, pos )
        terms[term] ||= {}
        terms[term][field] = [pos].flatten
      end

      def to_h
        { :path => path,
          :ctype => ctype,
          :score => score,
          :terms => terms
        }
      end

      def self.from_hash(h)
        obj = self.new(h[:path], h[:score])
        h.terms.each do |term,v|
          v.each { |field,pos| obj.add_term(k, field, pos) }
        end
        obj
      end

      def inspect
        "[%s] %s (%0.4f): %s" % [ctype, path, score, terms.inspect]
      end
    end

    attr_reader :max_results

    # search terms
    # * weights?
    # * proximity?
    # * required?
    attr_reader :terms

    # fields to search in. can be empty -- plugin should proivide defaults
    # examples: Document::PROP_DESCRIPTION Document::PROP_TITLE
    attr_reader :fields

    attr_reader :results

    # raw query string. applications should set this if they want to give
    # the search engine a chance to parse the query string themselves
    attr_accessor :raw_query

# TODO: field weights, fields to ignore 

    # terms is an Array or String
    # fields is an array of symbols
    def initialize(terms, fields=[], max_results=100)
      @terms = terms_from_arg(terms)
      @fields = fields # fields_from_array(fields)
      @max_results = max_results.to_i
      @results = []
      @raw_query = nil
    end

    def terms_from_arg(arg)
      # TODO: generate some kind of QueryTerm object
      if arg.kind_of? Array
          arg
      elsif arg.kind_of? Hash
          arg.keys
      elsif arg.kind_of? String
        [arg]
      else
        []
      end
    end

=begin THIS IS LUCENE SPECIFIC -- KEEP IT IN LUCENE
    def fields_from_array(arr)
      arr = [:contents] if (! arr || (arr.empty?))
      arr.map do |f|
        case f.to_sym
          when :contents
            'body'
          else
            f.to_s
        end
      end
    end
=end

    def add_result(r)
      @results << r
    end

    # ----------------------------------------------------------------------

=begin rdoc
Convert Query object to a Hash.
=end
    def to_h
      { :terms => terms,
        :fields => fields,
        :results => results,
        :max_results => max_results
      }
    end

=begin rdoc
Instantiate a Query object from a Hash.
=end
    def self.from_hash(h)
      obj = self.new(h[:terms], h[:fields], h[:max_results])
      h[:results].each { |r| obj.add_result r }
      obj
    end

    # ----------------------------------------------------------------------
    #def to_s
    #end

    #def inspect
    #end
  end

=begin rdox
Hash [path -> Query::Result]
=end
  class RelatedDocuments < Hash

    def add_doc(path, result)
      @docs[path] = result
    end

    # TODO: return keywords mapping to lists of documents
    def keywords
    end

    # TODO: sort by score
    def by_score
    end

    def self.from_keyword_stats(stats)
      stats.inject(self.new) do |h,(key,docs)|
        docs.each do |path, rec|
          next if ! path
          h[path] ||= PlanR::Query::Result.new(path, 0)
          h[path].add_term(key, :body, rec[:positions])
          h[path].score += rec[:frequency]
        end
        h
      end
    end
  end

end
