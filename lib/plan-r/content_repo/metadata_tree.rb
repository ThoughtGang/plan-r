#!/usr/bin/env ruby
# :title: PlanR::Content::MetadataTree
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/tree'

module PlanR

  module ContentRepo

=begin rdoc
Tree containing metadata for nodes (files or directories) in ContentTree.
=end
    class MetadataTree
      include Tree

      def self.label() 'Metadata'; end
      def self.root() 'metadata'; end
      def self.key() :metadata; end

      def self.node_types
        MetadataNode.classes
      end

      def node_types
        self.class.node_types
      end

      def node_type_lookup(sym)
        MetadataNode.find_class(sym)
      end

      def node_type_lookup!(sym)
        cls = node_type_lookup(sym)
        raise Tree::InvalidNodeType, "#{sym} not in #{self.class.root}" if ! cls
        cls 
      end

      def node_type_keys
        MetadataNode.class_keys
      end

      def node_factory(path, doc_path, mtype=:properties, ctype=:document)
        cls = node_type_lookup(mtype)
        node_or_dir_factory cls, path, doc_path, ctype
      end

      def node_or_dir_factory(cls, path, doc_path, ctype)
        if cls and cls.valid?(doc_path) 
          obj = cls.new(path, doc_path, ctype)
          return obj if (File.exist? obj.doc_path)
        end
        dir_node_factory(path, doc_path)
      end

=begin rdoc
Empty node is created using an empty Hash
=end
      def default_data(mtype=nil)
        cls = node_type_lookup!(mtype)
        cls.default_data
      end

=begin rdoc
Add a Property Node to the tree (i.e. set an Item properties). This takes a
Hash of properties as an argument.
=end
      def add(path, ctype, data=nil, mtype=:properties)
        node_path = fs_path(path)
        if (File.exist? node_path) && (! File.directory? node_path)
          raise Tree::NodeConflict.new("#{path} exists and is not a directory")
        end

        node_write(path, node_path, ctype, data, mtype)
      end

      def clone(node, to_path)
        return if (node.kind_of? DirNode)
        add(to_path, node.content_node_type, node.contents, node.node_type)
      end

      def remove(path, ctype, mtype)
        cls = node_type_lookup(mtype)
        cls ||= DirNode
        remove_node(cls.new(path, fs_path(path), ctype))
      end

      def lookup(path, mtype=:properties, ctype=:document)
        node_factory(path, fs_path(path), mtype, ctype)
      end

      def subtree(path, ctype=nil, mtype=nil, prune=nil, keep_dirs=false)
        nodes = []
        dirnode = nil

        each_node_type(mtype) do |key|
          each_content_node_type(ctype) do |ckey|
            node = lookup(path, key, ckey)
            if (node.kind_of? DirNode)
              if (! dirnode)
                dirnode = node
              end
            elsif (node.kind_of? Node)
              nodes << node
            end
          end
        end
        if nodes.empty?
          if (dirnode)
            nodes << dirnode if keep_dirs
          else
            return []
          end
        end


        # FIXME: REFACTOR: extract-method
        prune -= 1 if prune
        if (! prune) or (prune.to_i > 0)
          # NOTE: we only need one node to determine current directory
          dir_path = (nodes.first || dirnode).path
          dir_path_fs = fs_path(dir_path)
          if (File.exist? dir_path_fs) and (File.directory? dir_path_fs)
            # iterate through children (which will all be directories)
            Dir.entries( dir_path_fs ).each do |f|
              next if (f.start_with? '.')
              next if (! File.directory? File.join(dir_path_fs, f))

              nodes.concat subtree(File.join(dir_path, f), ctype, mtype, prune,
                                   keep_dirs)
            end
          end
        end 

        nodes
      end

      def with_subtree(path, ctype=nil, mtype=nil, prune=nil, keep_dirs=false,
                       &block)
        subtree(path, ctype, mtype, prune, keep_dirs).each { |node| 
          block.call node 
        }
      end

      protected
      def node_write(tree_path, fs_path, ctype, data=nil, mtype=:properties )
        cls = node_type_lookup!(mtype)
        obj = cls.new(tree_path, fs_path, ctype)

        node_write_obj(obj, data)
      end

      def each_content_node_type(ctype=nil, &block)
        (ctype ? [ ctype ] : ContentNode.class_keys).each { |key| 
                                                             block.call key }
      end
    end

  end
end
