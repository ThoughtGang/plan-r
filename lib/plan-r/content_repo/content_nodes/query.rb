#!/usr/bin/env ruby
# :title: PlanR::Content::QueryNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'
require 'plan-r/datatype/query'

module PlanR
  module ContentRepo

    class QueryNode < ContentNode
      KEY = :query
      PATHNAME = '.CONTENT.query.json'

      def initialize(tree_path, doc_path)
        super tree_path, File.join(doc_path, PATHNAME)
      end

      def self.default_data
        PlanR::Query.new([])
      end

      def contents
        buf = super
        buf ? PlanR::Query.from_json(buf) : default_data
      end

      def contents=(obj)
        # TODO: raise exception if not a Query object?
        super obj.to_json
      end
    end

  end
end
