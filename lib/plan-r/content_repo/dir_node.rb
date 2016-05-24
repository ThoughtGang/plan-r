#!/usr/bin/env ruby
# :title: PlanR::ContentRepo::DirNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/node'

module PlanR

  module ContentRepo

=begin rdoc
A "virtual" node containing no data.
This is given its own class for Object#kind_of? purposes.
=end
    class DirNode < Node
      KEY = :folder
      PATHNAME = ''

      def initialize(path, doc_path)
        @path = path
        @doc_path = doc_path
      end

      def remove
        if (File.exist? doc_path)
          if (! File.directory? doc_path)
            raise NodeDeleteError, "#{self.class.name} at #{path} not directory"
          elsif (Dir.entries(doc_path).count > 2)
            raise NodeDeleteError, "#{self.class.name} at #{path} not empty"
          else
            Dir.rmdir(doc_path) 
          end
        end
      end

      def contents
        nil
      end

      def contents=
        raise Tree::InvalidNodeData, "Directory is not writeable"
      end
    end

  end
end
