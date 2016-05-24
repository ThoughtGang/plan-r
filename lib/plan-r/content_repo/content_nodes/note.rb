#!/usr/bin/env ruby
# :title: PlanR::Content::NoteNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'

module PlanR
  module ContentRepo

=begin rdoc
Text data stored at a path in the Repository
=end

    class NoteNode < ContentNode
      KEY = :note
      PATHNAME = '.CONTENT.note.txt'

      def initialize(tree_path, doc_path)
        super tree_path, File.join(doc_path, PATHNAME)
      end

    end

  end
end
