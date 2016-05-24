#!/usr/bin/env ruby
# :title: PlanR::Content::PropertyNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/metadata_node'

module PlanR
  module ContentRepo

    class PropertyNode < MetadataNode
      KEY = :properties
      PATHNAME = '.META.properties'
      EXT='json'

      def self.default_data
        {}
      end

      def initialize(tree_path, doc_path, ctype=:document)
        @content_node_type = ctype
        super tree_path, File.join(doc_path, PATHNAME, "#{ctype.to_s}.#{EXT}")
      end

      def contents
        buf = super
        # NOTE: we only want to symbolize top level of keys
        buf ? JSON.parse(buf).inject({}) { |h,(k,v)| h[k.to_sym] = v; h } :
              default_data 
      end

      def contents=(h)
        super h.to_json
      end
    end

  end
end
