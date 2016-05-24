#!/usr/bin/env ruby
# :title: PlanR::Document::Note
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/document'

module PlanR

=begin rdoc
A Note document
=end
  class NoteDocument < Document

    def self.node_type
      :note
    end

    def self.default_properties
      props = super
      # TODO: check repo config to determine if notes should be indexed?
      #props[PROP_INDEX] = false
      props[PROP_SYNCPOL] = PlanR::Application::DocumentManager::SYNC_MANUAL
      props
    end

    def initialize(repo, path, text=nil)
      super repo, path, self.class.node_type
      title = text.lines.first if text
    end

    def mime
      'text/plain'
    end
  end

end
