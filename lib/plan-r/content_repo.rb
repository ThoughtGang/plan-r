#!/usr/bin/env ruby
# :title: PlanR::ContentRepo
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

ContentRepo module. The repository of all documents and metadata.
=Content Repo

==Repository
The Content Repository contains two types of trees: Data trees and Metadata 
trees.

Each tree contains objects identified by a path. Any specific path can be
present in more than one tree; this represents discrete but related data 
objects (e.g. a document and notes/table data).

A full UUID for a repository object is therefore tree + path.

===Path
Every object in the reository is referenced by a path, much like a filesystem
path. A path may resolve to a node in one or more trees.

===Data Tree
A Data tree contains user data objects.

  * Imported documents
  * Text/RTF "notes"
  * Tables of arbitrary data
  * Dictionaries of arbitrary data

===Metadata Tree
A Metadata tree contains attributes or metadata applied to objects in a 
Data tree.

  * Dictionary of properties (could be a sub-tree?)
  * Tags
=end

module PlanR

=begin rdoc
The per-Repo content repository.
The Repo consists of two trees which contain path-addressable content nodes:
 * content : Document, Note, Table, etc nodes
 * metadata : Properties, etc nodes which describe content nodes
  
=end

  module ContentRepo
    autoload :Tree, 'plan-r/content_repo/tree.rb'
    autoload :Node, 'plan-r/content_repo/node.rb'

    autoload :ContentTree, 'plan-r/content_repo/content_tree.rb'
    autoload :MetadataTree, 'plan-r/content_repo/metadata_tree.rb'

    autoload :DirNode, 'plan-r/content_repo/node.rb'
    autoload :ContentNode, 'plan-r/content_repo/content_node.rb'
    autoload :MetadataNode, 'plan-r/content_repo/metadata_node.rb'
                                                                                
  end

end
