#!/usr/bin/env ruby
# :title: PlanR::Document::Dict
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/document'
require 'plan-r/datatype/dict'

module PlanR

=begin rdoc
A Dict Document.
=end
  class DictDocument < Document

    def self.node_type
      :dict
    end

    def self.default_properties
      props = super
      props[PROP_INDEX] = false
      props[PROP_SYNCPOL] = PlanR::Application::DocumentManager::SYNC_MANUAL
      props
    end

    def initialize(repo, path, data=nil)
      # FIXME : REVIEW (DATA is obsolete?)
      @data = data
      super repo, path, self.class.node_type
    end

    def mime
      'application/json'
    end

    def contents=(buf)
      invalid_content!(buf) if (! buf.kind_of? Dict)
      super buf
    end

=begin rdoc
The original contents of the document
=end
    def contents
      tbl = super
      # sane default:
      tbl ||= Dict.new()
    end
  end

end
