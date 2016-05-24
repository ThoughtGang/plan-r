#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification
=begin rdoc
Standard Plugin Specifications

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

This directory contains Specification definitions used by standard Plan-R 
plugins.

Each Specification definition is an instance of the Specification class.

Example:

PlanR::Plugin::Specification.new( :unary_operation, 'fn(x)', [[Fixnum,String]], [Fixnum,String] )

The list of all Specification definitions can be obtained via
PlanR::Plugin::Specification.specs().
=end

module PlanR
  module Plugins

=begin rdoc
Namespace for defining Specification objects. Just in case.
=end
    module Spec
    end

  end
end

Dir.foreach(File.join(File.dirname(__FILE__), 'specification')) do |f|
    require File.join('plan-r', 'plugins', 'shared', 'specification',
                      File.basename(f, '.rb')) if (f.end_with? '.rb')
end
