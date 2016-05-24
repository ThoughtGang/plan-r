#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::DataSource
=begin rdoc
Specification for data source plugins

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/repo'

module PlanR
  module Plugins
    module Spec

      # Input: A string containing the file path, URI, etc.
      #        A Repo object (required for in-repo data sources) or nil
      # Output: A string containing data from data source
      TG::Plugin::Specification.new( :data_source,
                                     'fn(String origin, Repository)',
                                     [String, [PlanR::Repo, NilClass]],
                                     [String] 
                                   )
    end
  end
end
