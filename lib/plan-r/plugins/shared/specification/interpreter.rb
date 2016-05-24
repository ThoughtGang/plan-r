#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Interpreter
=begin rdoc
Specifications for Script Interpreter plugins
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/application/interpreter'
require 'plan-r/document/script'

module PlanR
  module Plugins
    module Spec

      # ----------------------------------------------------------------------
      # EVALUATE SCRIPT
      #
      # Input: A PlanR::Script to evaulate, Object (usually a Document)
      # Output: Output of script
      TG::Plugin::Specification.new( :evaluate,
                                     'fn(Script, Object)',
                                     [PlanR::Script, Object],
                                     [String]
                                   )

      # ----------------------------------------------------------------------
      # INTERPRETER
      #
      # Launch a long-running interpreter in a separate process.
      # Input: No input
      # Output: An Interpreter object used to communicate with the Process.
      TG::Plugin::Specification.new( :interpreter, 'fn()', [],
                                     [PlanR::Application::Interpreter]
                                   )
    end
  end
end
