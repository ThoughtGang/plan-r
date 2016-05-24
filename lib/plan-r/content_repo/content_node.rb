#!/usr/bin/env ruby
# :title: PlanR::Content::ContentNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/node'

module PlanR

  module ContentRepo

    class ContentNode < Node

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

=begin rdoc
Key (Symbol) of content tree containing node
=end
      def tree
        Content::ContentTree.key
      end

    end

  end
end

# load all ContentNode types
Dir.foreach( File.join(File.dirname(__FILE__), 'content_nodes') ) do |f|
  require_relative File.join('content_nodes', f) if (f.end_with? '.rb')
end 
