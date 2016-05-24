#!/usr/bin/env ruby
# :title: PlanR::Content::TableNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end


require 'plan-r/content_repo/content_node'

module PlanR
  module ContentRepo

    class TableNode < ContentNode
      KEY = :table
      PATHNAME = '.CONTENT.table.json'

      def initialize(tree_path, doc_path)
        super tree_path, File.join(doc_path, PATHNAME)
      end

      def self.default_data
        PlanR::DataTable.new(1, 1, '')
      end

      def contents
        json_str = super
        json_str ? PlanR::DataTable.from_json(json_str) : default_data
      end

      def contents=(obj)
        # TODO: raise exception if not a DataTable object?
        super obj.to_json
      end

    end

  end
end
