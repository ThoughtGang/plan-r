#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Ident
=begin rdoc
Specification for file and data ident plugins

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/datatype/ident'

module PlanR
  module Plugins
    module Spec

      # Input: a string containing binary data or an IO object, and a
      #        path. Either can be empty; the plugin will decide whether
      #        to use the buffer, path, or both in doing the ident lookup.
      # Output: an Ident object
      TG::Plugin::Specification.new( :ident,
                                        'fn(String|IO, String)',
                                        [[String, IO, NilClass], String],
                                        [PlanR::Ident] 
                                      )
    end
  end
end
