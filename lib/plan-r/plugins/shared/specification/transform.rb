#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Transform
=begin rdoc
Specifications for Document Transform plugins
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

module PlanR
  module Plugins
    module Spec

      # ----------------------------------------------------------------------
      # TRANSFORM DOCUMENT
      #
      # Input: A PlanR::Document to apply the transformation to.
      # Output: A PlanR::Document containing the transformed document.
      #         Note that this may be a different document type from
      #         the original.
      TG::Plugin::Specification.new( :transform_doc,
                                     'fn(Document)',
                                     [PlanR::Document],
                                     [PlanR::Document]
                                   )


    end
  end
end
