#!/usr/bin/env ruby
# :title: PlanR::Content::DictNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'
require 'plan-r/datatype/dict'

module PlanR
  module ContentRepo

    class DictNode < ContentNode
      KEY = :dict
      PATHNAME = '.CONTENT.dict.json'

      def initialize(tree_path, doc_path)
        super tree_path, File.join(doc_path, PATHNAME)
      end

      def self.default_data
        PlanR::Dict.new
      end

      def contents
        buf = super
        buf ? PlanR::Dict.from_json(buf) : default_data
      end

      def contents=(obj)
        # TODO: raise exception if not a Dict or Hash object?
        super obj.to_json
      end
    end

  end
end
