#!/usr/bin/env ruby
# :title: PlanR::Content::Tree
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'fileutils'

require 'plan-r/content_repo/node'

module PlanR

=begin rdoc
Base class for content trees

Derived classes must implement the following class methods:

  label()
  root()

Content::Tree classes which do not provide these will be ignored by
Repo.
=end

  module ContentRepo

=begin rdoc
Base class (mixin) for Content Tree classes.
=end
    module Tree

=begin rdoc
Node exists and cannot be overwritten.
=end
      class NodeConflict < RuntimeError; end
=begin rdoc
Data provided for node is invalid
=end
      class InvalidNodeData < RuntimeError; end

=begin rdoc
Node type specified is invalid.
=end
      class InvalidNodeType < RuntimeError; end

=begin rdoc
Base (absolute) path for tree contents in repo.
=end
      attr_reader :base_path
=begin rdoc
Connection to repository database, if applicable.
=end
      attr_reader :db

      def initialize(path)
        @base_path = path
        @db = nil
      end

=begin rdoc
Name of content tree. This is displayed in user interfaces.

Example: 'Documents'
=end
      def name() self.class.label; end

=begin rdoc
Name of root dir for data tree in repository

Example: 'documents'
=end
      def root() self.class.root; end

=begin rdoc
Symbol for data tree to use as an index.

Example: :document
=end
      def key() self.class.key; end

=begin rdoc
Array of Node objects which are stored by this tree.
=end
      def node_types() []; end
      def node_type_lookup(sym) nil; end
      def node_type_lookup!(sym) raise "abstract method"; end

=begin rdoc
Register connection to application database
=end
      def db_connect(db_conn)
        @db = db_conn
      end

=begin rdoc
Register callback for notifications
=end
      def notifier=(obj)
        @notify_obj = obj
      end

      # ----------------------------------------------------------------------
=begin rdoc
Notify callback that an add/remove has happened.
=end
      def notify(*args)
        @notify_obj.send(:notify, *args) if @notify_obj
      end

=begin rdoc
Construct a node object given its in-tree path and its on-fs path.
=end
      def node_factory(path, doc_path, ctype=nil)
        raise 'abstract method!'
        ContentRepo::Node.new(path, doc_path)
      end

=begin rdoc
Construct a VirtualNode for path element
=end
      def dir_node_factory(path, doc_path)
        return nil if (! File.exist? doc_path) and (! File.directory? doc_path)
        ContentRepo::DirNode.new(path, doc_path)
      end

=begin rdoc
Return Node object or a DirNode object containing a Node.
cls is a subclass of Node.
=end
      def node_or_dir_factory(cls, path, doc_path)
        if cls and cls.valid?(doc_path)
          obj = cls.new(path, doc_path)
          return obj if (File.exist? obj.doc_path)
        end
        dir_node_factory(path, doc_path)
      end

=begin rdoc
Add a node to the repository.
This raises a NodeConflict if path exists and is not a directory -- which 
should never happen in practice.
=end
      def add(path, data=nil, ctype=:document)
        node_path = fs_path(path)
        if (File.exist? node_path) && (! File.directory? node_path)
          raise Tree::NodeConflict.new("#{path} exists and is not a directory")
        end

        node_write(path, node_path, data, ctype)
      end

=begin rdoc
Create a directory in the tree at the provided path.
This is mostly useful for attaching metadata to an empty directory.
NOTE: The ability to create an empty directory which shows up in a listing
is useful for some UIs, so this functionality should not be removed.
=end
      def mkdir(path)
        dir_path = fs_path(path)
        if (File.exist? dir_path) 
          if (! File.directory? dir_path)
            raise Tree::NodeConflict.new("#{path} exists as a file")
          end
          # nothing to do -- an existing directory is fine
        else
          FileUtils.mkdir_p(dir_path)
        end
      end

      def clone(node, to_path)
        return if (node.kind_of? DirNode)
        add(to_path, node.contents, node.node_type)
      end

=begin rdoc
Default data: this is what gets inserted when an empty (no data) node is created
=end
      def default_data(ctype=nil)
        ''
      end

=begin rdoc
Remove 'path' from content tree. This deletes the document on the filesystem.
=end
      def remove(path, ctype)
        cls = node_type_lookup(ctype)
        cls ||= DirNode
        cls.remove

        remove_node(cls.new(path, fs_path(path)))
      end

      def remove_node(node)
        node.remove
        remove_empty_parent(node.doc_path)
      end

=begin rdoc
Remove parent directory of path if it is empty, and if it is not the root
directory of the tree.
Note: This operates on actual fs-path (node.doc_path), not on node.path.
=end
      def remove_empty_parent(path)
        p_path = File.dirname(path)
        # do not attempt to delete non-existent directories
        return if (! File.exist? p_path) or (! File.directory? p_path)
        # do not delete root, even if empty!
        return if p_path == File.join(base_path, root)
        # is directory even empty?
        return if Dir.entries(p_path).count > 2

        begin 
          Dir.rmdir(p_path)
        rescue Exception => e
          # directory is not empty; just return
          return
        end
      end

=begin rdoc
Remove empty directories in tree, including path.
Raises an error if any of the directories is not empty.
Note: This operates on node.path, not fs-path.
=end
      def remove_empty_dirs(path)
        remove_empty_fs_dirs fs_path(path)
      end

=begin rdoc
Same as remove_empty_dirs, but operates on fs-path.
NOTE: path need not exist, but must be a directory if it does.
=end
      def remove_empty_fs_dirs(path)
        return if (! File.exist? path)
        Dir.entries(path).each do |f|
          next if (f == '.' or f == '..')
          child_path = File.join(path, f)
          next if (! File.directory? child_path)
          remove_empty_fs_dirs(child_path)
        end
        if (! Dir.entries(path).count == 2)
          raise Node::NodeDeleteError, "Dir #{path} @ #{path} not empty"
        end
        Dir.rmdir(path)
      end

=begin rdoc
Return Node for path in content tree.
=end
      def [](path)
        lookup(path)
      end

      def lookup(path, ctype=:document)
        node_factory(path, fs_path(path), ctype)
      end

=begin rdoc
Return true if a Node exists at path.
=end
      def exist?(path, ctype=nil)
        found = false
        each_node_type(ctype) do |key|
          node = lookup(path, key)
          if node and (! node.kind_of? DirNode)
            found = true 
            break
          end
        end
        found
      end

=begin rdoc
Return true if 'path' exists inside the content-tree on the filesystem.
This does not mean that a valid node exists: the path could be an empty
directory.
=end
      def path_exist?(path)
        File.exist?(File.join(base_path, root, path))
      end

=begin rdoc
Return subtree at path, filtered by node type.
If prune is an integer n, then only the first n levels levels of subtree
are returned. To return a single tree level (e.g. a single path item),
set prune to 1.
=end
      def subtree(path, ctype=nil, prune=nil, keep_dirs=false)
        nodes = []
        dirnode = nil

        each_node_type(ctype) do |key|
          node = lookup(path, key)
          # FIXME: this might need a Node.valid? call
          if (node.kind_of? DirNode)
            if (! dirnode)
              dirnode = node
            end
          elsif (node.kind_of? Node)
            nodes << node
          # else : non-extant node : ignore
          end
        end
        if nodes.empty?
          if (dirnode)
            nodes << dirnode if keep_dirs
          else
            return []
          end
        end

        return [] if (! dirnode) and (nodes.empty?)

        prune -= 1 if prune
        if (! prune) or (prune.to_i > 0)
          # NOTE: we only need one node to determine current directory
          node = nodes.first || dirnode

          dir_path = (node || dirnode).path
          dir_path_fs = fs_path(dir_path)
          if (File.exist? dir_path_fs) and (File.directory? dir_path_fs) 
            # iterate through children (which will all be directories)
            Dir.entries( dir_path_fs ).each do |f|
              next if (f.start_with? '.')
              next if (! File.directory? File.join(dir_path_fs, f))
              nodes.concat subtree(File.join(dir_path, f), ctype, prune,
                                   keep_dirs)
            end
          end
        end

        nodes
      end

      def with_subtree(path, ctype=nil, prune=nil, keep_dirs=false, &block)
        subtree(path, ctype, prune, keep_dirs).each { |node| 
          block.call(node)
        }
      end

=begin rdoc
Return true if node_path (an absolute path to an on-disk file in the repo) is
a valid node. Trees can use this to determine if the node contains valid data.
=end
      def valid_node?(node_path, ctype=nil)
        return false if (! File.directory? node_path)
        cls = ctype ? node_type_lookup(ctype) : nil
        cls ? cls.valid?(node_path) : false
      end

=begin rdoc
Return on-disk path in repo for content path.
=end
      def fs_path(path)
        File.join(base_path, root, path)
      end

      protected 

      def node_write(tree_path, fs_path, data=nil, ctype=:document)
        cls = node_type_lookup!(ctype)
        obj = cls.new(tree_path, fs_path)

        node_write_obj(obj, data)
      end

      def node_write_obj(obj, data)
        node_dir = File.dirname(obj.doc_path)
        FileUtils.mkdir_p(node_dir) if (! File.exist? node_dir)
        raise "Node dir #{node_dir} not a directory!" if \
              (! File.directory? node_dir)

        obj.contents=(data || obj.class.default_data)
        obj
      end

      def each_node_type(ctype=nil, &block)
        (ctype ? [ ctype ] : node_type_keys).each { |key| block.call key }
      end
    end

  end
end
