#!/usr/bin/env ruby
# :title: PlanR::Content::ScriptNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'

module PlanR
  module ContentRepo

    class ScriptNode < ContentNode
      KEY = :script
      PATHNAME = '.CONTENT.script'
      DEFAULT_EXT='txt'

      def self.valid?(actual_path)
        return false if (! File.exist? actual_path) or
                        (! File.directory? actual_path)
        Dir.entries(actual_path).select { |n| n.start_with? PATHNAME }.count > 0
      end

      def initialize(tree_path, doc_path)
        ext = File.extname(doc_path)[1..-1]
        ext = DEFAULT_EXT if (! ext) or (ext.empty?)
        actual_path = File.join(doc_path, PATHNAME + '.' + ext )
        super tree_path, actual_path
      end

    end

  end
end
