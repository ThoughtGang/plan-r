#!/usr/bin/env ruby
# :title: PlanR::Query
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/document'
require 'plan-r/datatype/query'

module PlanR

=begin rdoc
A query storedin the Repository for later use.
=end
  class StoredQuery < Document
    PROP_ENGINE   = :engines      # Plugin or list of :query_index Plugins

    def self.node_type
      :query
    end

    def self.default_properties
      props = super
      props[PROP_INDEX] = false
      props[PROP_SYNCPOL] = PlanR::Application::DocumentManager::SYNC_MANUAL
      props[PROP_CACHE] = true
      props
    end

    def initialize(repo, path, query=nil)
      @query = query
      super repo, path, self.class.node_type
    end

    def mime
      'application/json'
    end

    def perform
      Application::QueryManager.perform(repo, query, engines)
    end

    def contents
      super || Query.new('')
    end
    alias :query :contents

    def contents=(buf)
      invalid_content!(buf) if (! buf.kind_of? Query)
      super buf
    end
    alias :query= :contents=

=begin rdoc
Plugins which the query is run on.
=end
    def engines
      properties[PROP_ENGINE] || [ ]
    end

    def engines=(name)
      properties[PROP_ENGINE] = [name].flatten
    end

  end
end

require 'plan-r/repo'    # not needed until runtime
