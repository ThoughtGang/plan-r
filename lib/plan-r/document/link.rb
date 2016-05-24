#!/usr/bin/env ruby
# :title: PlanR::LinkedDocument
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
A Document whose contents are not stored in the Repository (though they are 
indexed).

The location of the document is stored in the origin property. Changing this 
property will update the LinkedDocument to point to a new location.
=end

# WARNING : This class may be obsolete

require 'plan-r/document'

module PlanR

  class LinkedDocument < Document

    def self.tree
      :link
    end

    def self.import(repo, path, origin)
      raise 'Importing requires an origin' if (! origin) || (origin.empty?)
      doc = self.new(repo, path)
      doc.origin = origin
      doc
    end

    def initialize(repo, path)
      super repo, path, self.class.tree
      @disable_fetch = false
      @contents = nil
    end

    def origin=(str)
      # TODO: format origin into a META tag or URI?
      repo.add(path, str, tree)
      super
    end

    def regenerate
      # no-op
    end

    def mime
      'application/json'
    end

=begin rdoc
The original contents of the document
=end
    def contents
      return @contents if @disable_fetch
      Application::DocumentManager.refresh_doc(self)
      @contents
    end

=begin rdoc
Set the contents of the Document. This causes a re-analysis and re-index.
=end
    def contents=(buf)
      return if ! buf
      @contents = buf
      @disable_fetch = true
      Application::DocumentManager.analyze_and_index_doc(self)
      @disable_fetch = false
    end

  end
end

require 'plan-r/application/document_mgr' # ensure DocumentManager is loaded
