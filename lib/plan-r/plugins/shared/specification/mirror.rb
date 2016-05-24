#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Mirror
=begin rdoc
Specification for plugins to mirror remote content to local repo

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'

module PlanR
  module Plugins
    module Spec

      # Input: The Document (with ident, origin, and repo info) to mirror, 
      #        a String containing the fetched contents, and a PluginObject
      #        to use for fetching resources (stylesheets, images, etc). 
      #        This object must define the :data_source Plugin specification.
      # Output: A Hash containing a mirrored copy of the object. The Hash
      #         keys will be as follows:
      #           contents: a String containing the document contents rewritten
      #                     to reference paths under 'files'
      #           resources:  a Hash [ String -> String ] of relative path to
      #                   file contents
      TG::Plugin::Specification.new( :mirror_doc,
                         'fn(Document, String contents, Plugin loader)',
                         [PlanR::Document, String, TG::PluginObject], [Hash]
                                   )
    end
  end
end
