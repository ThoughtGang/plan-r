#!/usr/bin/env ruby
# :title: PlanR::Document::Table
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/document'
require 'plan-r/datatype/data_table'

module PlanR

=begin rdoc
A Table Document.
=end
  class TableDocument < Document

    def self.node_type
      :table
    end

    def self.default_properties
      props = super
      props[PROP_INDEX] = false
      props[PROP_SYNCPOL] = PlanR::Application::DocumentManager::SYNC_MANUAL
      props
    end

    def initialize(repo, path, data=nil)
      @data = data
      super repo, path, self.class.node_type
    end

    def mime
      'application/json'
    end

    def contents=(obj)
      invalid_content!(obj) if (! obj.kind_of? DataTable)
      super obj
    end

=begin rdoc
The original contents of the document
=end
    def contents
      super || DataTable.new(1, 1, '')
    end
  end

end
