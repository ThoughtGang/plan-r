#!/usr/bin/env ruby
# :title: PlanR::Content::ResourceNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'
require 'find'

module PlanR
  module ContentRepo

=begin rdoc
Document resource, e.g. an image, stylesheet, or template.
=end

    class ResourceNode < ContentNode
      KEY = :resource
      PATHNAME = '.CONTENT.rsrc'

      def self.valid?(actual_path)
        node_path = File.join(actual_path, PATHNAME)
        (File.exist? node_path) and (File.directory? node_path)
      end 

      # NOTE: 'tree_path' is the path to the document. this makes 
      #       :resource a directory of resource attachments.
      def initialize(tree_path, res_path, fs_path)
        @resource_dir = File.join(fs_path, PATHNAME)
        actual_path = File.join(@resource_dir, res_path)
        # FIXME: should tree_path encode resource location?
        super tree_path, actual_path
      end

      def remove
        super
        doc_dir = @resource_dir
        if (File.exist? doc_dir) and (File.directory? doc_dir) and
           (Dir.entries(doc_dir).count <= 2)
          if (File.basename(doc_dir) != PATHNAME)
              raise NodeDeleteError,
                    "#{self.class.name} #{doc_dir} != #{PATHNAME}"
            else
              Dir.rmdir(doc_dir)
            end
        end
      end

    end

  end
end
