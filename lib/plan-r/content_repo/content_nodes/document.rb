#!/usr/bin/env ruby
# :title: PlanR::Content::DocumentNode
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/content_repo/content_node'

module PlanR
  module ContentRepo

=begin rdoc
documents such as .txt and .pdf files]
=end
    class DocumentNode < ContentNode
      KEY = :document
      PATHNAME = '.CONTENT.doc'

      def self.valid?(actual_path)
        node_path = File.join(actual_path, PATHNAME)
        (File.exist? node_path) and (File.directory? node_path) and
        (Dir.entries(node_path).count > 2) # . and .. == 2
      end

      def initialize(tree_path, doc_path)
        # here we do something tricky: we use basename as node dir and
        # as Document-content-dir contents
        actual_path = File.join(doc_path, PATHNAME, File.basename(doc_path))
        super tree_path, actual_path
      end

      def remove
        super  # remove content node
        doc_dir = File.dirname(doc_path)
        if (File.exist? doc_dir) and (File.directory? doc_dir)
          if (Dir.entries(doc_dir).count > 2)
            raise NodeDeleteError, "#{self.class.name}: #{doc_dir} not empty"
          else
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
end
