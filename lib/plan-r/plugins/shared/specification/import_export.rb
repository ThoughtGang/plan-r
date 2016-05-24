#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::ImportExport
=begin rdoc
Specification for plugins to export or import content

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document'
require 'stringio'

module PlanR
  module Plugins
    module Spec

      # Input: The Repo to export, an Array of repo paths to export, an
      #        IO object or String specifying the file or directory to export 
      #        to, and a Hash of plugin-specific options.
      # Output: Array of exported paths
      TG::Plugin::Specification.new( :export_contents,
                         'fn(Repo, Array paths, IO|String dest, Hash opts)',
                         [PlanR::Repo, Array, [IO,StringIO,String], Hash], 
                         [Array]
                                   )

      # Input: The Repo to export, an IO object or String specifying the file 
      #        or directory to import from, a String specifying the repo path
      #        to import to (can be '/'), and a Hash of plugin-specific options.
      # Output: Array of imported paths
      TG::Plugin::Specification.new( :import_contents,
                         'fn(Repo, IO|String origin, String dest, Hash opts)',
                         [PlanR::Repo, [IO,StringIO,String], String, Hash], 
                         [Array]
                                   )
    end
  end
end
