#!/usr/bin/env ruby
# :title: PlanR::Content::MetadataNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/node'

module PlanR

  module ContentRepo

=begin rdoc
[in-tree documents in a parallel filesystem, allowing document nodes to
 have children such as attached data].
=end

    class MetadataNode < Node
      attr_reader :content_node_type

      @classes = [ ]
      @classes_idx = { }
      @class_keys = nil
      def self.classes() 
        @classes
      end
      def self.find_class(key)
        @classes_idx[key] ||= (@classes.select { |cls| cls.key == key }.first)     
      end
      def self.class_keys
        @class_keys ||= @classes.map { |cls| cls.key }
      end
      def self.inherited(cls)
        if (! @classes.include? cls)
          @classes << cls
          # force cache to rebuild on next access
          @class_keys = nil
        end
      end

      def self.valid?(actual_path)
        node_path = File.join(actual_path, self.const_get(:PATHNAME))
        (File.exist? node_path) and (File.directory? node_path) and
        (Dir.entries(node_path).count > 2) # . and .. == 2
      end
      
=begin rdoc
Key (Symbol) of content tree containing node
=end
      def tree
        # FIXME: REVIEW (obsolete?)
        Content::MetadataTree.key
      end

    end

  end
end

# load all MetadataNode types
Dir.foreach( File.join(File.dirname(__FILE__), 'metadata_nodes') ) do |f|
  require_relative File.join('metadata_nodes', f) if (f.end_with? '.rb')
end
