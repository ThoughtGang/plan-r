#!/usr/bin/env ruby
# :title: PlanR::Content::Node
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

  module ContentRepo

    autoload :DirNode, 'plan-r/content_repo/dir_node'

=begin rdoc
Base class for content tree nodes. A node basicall has the following attributes:
  * path - location of node in the content tree 
  * doc_path - location of the data for the node on-disk
  * contents - the data stored in the node
=end
    class Node

=begin rdoc
An exception arising when Node cannot be deleted.
=end
      class NodeDeleteError < RuntimeError; end

=begin rdoc
Path of node in content tree. This is the relative path of the node within
the content tree of the repo.
=end
      attr_reader :path

=begin rdoc
Path to node contents. This is where the raw data for the node resides.
=end
      attr_reader :doc_path

=begin rdoc
Key (Symbol) identifying content tree. This is either :content or :metadata.
=end
      # FIXME : REVIEW (OBSOLETE?)
      attr :tree

      def self.key
        self.const_get(:KEY)
      end

      def self.pathname
        self.const_get(:PATHNAME)
      end

      def self.default_data
        ''
      end

      def self.valid?(actual_path)
        node_path = File.join(actual_path, self.const_get(:PATHNAME))
        (File.exist? node_path) and (! File.directory? node_path)
      end

      def node_type
        self.class.key
      end

      def initialize(tree_path, actual_path)
        @path = tree_path
        @doc_path = actual_path
      end

=begin rdoc
Remove files for node from content tree.
Note: this only removes the node content itself. parent directory containing
the node (and which may contain other nodes, as attachments) is deleted
by the content tree.
=end
      def remove
        if (File.exist? doc_path)
          if (File.directory? doc_path)
            raise NodeDeleteError, "#{node_type} at #{path} is directory"
          else
            File.delete(doc_path)
          end
        # else : nothing to do
        end
      end

=begin rdoc
Name or label of node. Note: this is not unique in the content tree.
=end
# TODO: is this even useful? There is path/filename, and there is title in props
      def name
        File.basename(path)
      end

=begin rdoc
Raw data stored in tree node. By default, this returns the data stored in
the on-disk file for the node.
=end
      def raw_contents
        buf = nil
        File.open(doc_path, 'rb') { |f| buf = f.read }
        buf
      end

      def contents
        raw_contents
      end

      def contents=(data)
        File.open(doc_path, 'wb') { |f| f.write data }
      end

    end

  end
end
