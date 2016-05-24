#!/usr/bin/env ruby
# :title: PlanR::Content::TagNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/metadata_node'

module PlanR
  module ContentRepo

    class TagNode < MetadataNode
      KEY = :tags
      PATHNAME = '.META.tags'
      EXT='txt'

      def self.default_data
        []
      end

      def initialize(tree_path, doc_path, ctype=:document)
        @content_node_type = ctype
        super tree_path, File.join(doc_path, PATHNAME, "#{ctype.to_s}.#{EXT}")
      end

      def contents
        buf = super
        buf.lines.map { |line| line.chomp }
      end

      def contents=(arr)
        super arr.join("\n")
      end
    end

  end
end
