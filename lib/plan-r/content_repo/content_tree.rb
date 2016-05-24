#!/usr/bin/env ruby
# :title: PlanR::Content::Tree
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/tree'
require 'plan-r/content_repo/content_node'

module PlanR

  module ContentRepo

    class ContentTree
      include Tree

      def self.label() 'Documents'; end
      def self.root() 'content'; end
      def self.key() :content; end

      def self.node_types
        ContentNode.classes
      end

      def node_types
        self.class.node_types
      end

      def node_type_lookup(sym)
        ContentNode.find_class(sym)
      end

      def node_type_lookup!(sym)
        cls = node_type_lookup(sym)
        raise Tree::InvalidNodeType, "#{sym} not in #{self.class.root}" if ! cls
        cls
      end

      def node_type_keys
        ContentNode.class_keys
      end

      # Node types that should be ignored by list or factory.
      # These nodes get excluded from each_node_type helper method
      def hidden_node_types
        [ ResourceNode.key ]
      end

      def node_factory(path, doc_path, ctype=:document)
        cls = node_type_lookup(ctype) 
        # NOTE: if cls is nil, a DirNode will be created if directory exists
        node_or_dir_factory cls, path, doc_path
      end

      def default_data(ctype=nil)
        cls = node_type_lookup!(ctype) 
        cls.default_data
      end

=begin rdoc
Note: The document tree supports empty directories, unlike the other data
trees -- so any directory returns True.
=end
      def valid_node?(node_path, ctype=nil)

        return true if super(node_path)
        return false if (! File.directory? node_path)
        ## Accept only directories that are empty or contain only subdirs
        Dir.entries(node_path).reject { |fname|
          File.directory? File.join(node_path, fname) 
        }.count == 0
      end

      # NOTE: resources have to be treated special
      def add_resource(doc_path, res_path, data)
        doc_node_path = fs_path(doc_path)
        if (File.exist? doc_node_path) && (! File.directory? doc_node_path)
          raise Tree::NodeConflict,
                "#{doc_path} exists and is not a directory"
        end

        obj = ResourceNode.new(doc_path, res_path, doc_node_path)

        node_write_obj(obj, data)
      end

      def resource(doc_path, res_path)
        ResourceNode.new(doc_path, res_path, fs_path(doc_path))
      end

      # return list of all paths under resource dir for document
      def resources(path)
        res_path = File.join(fs_path(path), ResourceNode::PATHNAME)
        return [] if (! File.exist? res_path) or (! File.directory? res_path)
        Find.find(res_path).reject { |f| File.directory? f 
                                   }.map { |f| f.split(res_path + '/', 2)[1] }
      end

      def remove_resource(doc_path, res_path)
        node = ResourceNode.new(doc_path, res_path, fs_path(doc_path))
        remove_node(node)
      end

      def each_node_type(ctype=nil, &block)
        (ctype ? [ctype] : (node_type_keys - hidden_node_types)).each { |key|
          block.call key
        }
      end

    end
  end
end

