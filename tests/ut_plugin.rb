#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR plugin API

require 'test/unit'

require 'plan-r/plugin'
$TG_PLUGIN_FORCE_VALID_RETURN = true

# ===========================================================================
# Interfaces
SPEC_UNARY=:unary_operation
SPEC_UNARY_PROTO ='fn(x)'
SPEC_UNARY_IN =[[Fixnum,String]]
SPEC_UNARY_OUT =[Fixnum, String]

SPEC_BINARY=:binary_operation
SPEC_BINARY_PROTO='fn(a, b)'
SPEC_BINARY_IN=[[Fixnum,String],[Fixnum,String]] 
SPEC_BINARY_OUT=[Fixnum, String]

A_API_IN = ['Integer a, Integer b']
A_API_OUT = 'Product'
A_API_DESCR = 'Multiple two numbers'

# Plugin A
A_NAME = 'A'
A_AUTHOR = 'A. Author'
A_VERSION = '1.0.1'
A_DESCR = 'A plugin'
A_HELP = 'Some help available'

class PluginA
  extend PlanR::Plugin

  name A_NAME
  author A_AUTHOR
  version A_VERSION
  description A_DESCR
  help A_HELP

  def succ(a) a + 1; end
  spec SPEC_UNARY, :succ

  def sum(a, b) a + b; end
  spec SPEC_BINARY, :sum, 60 do |a,b|
    (a.kind_of? Fixnum) && (b.kind_of? Fixum) ? 100 : 0
  end

  # this will be documented
  def product(a, b) a * b; end
  api_doc :product, A_API_IN, A_API_OUT, A_API_DESCR

  # this will not be documented
  def quotient(a, b) a / b; end

  private

  # this will not appear in api()
  def difference(a, b) a - b; end
end

# Plugin B
B_NAME = 'B'
B_AUTHOR = 'B. Author'
B_VERSION = '2.99-pre'
B_DESCR = 'B plugin'
B_HELP = 'no help available'

class PluginB
  extend PlanR::Plugin

  name B_NAME
  author B_AUTHOR
  version B_VERSION
  description B_DESCR
  help B_HELP

  dependency A_NAME, '=', A_VERSION

  # this should cause a bad return value error (spec returns Fixnum or String)
  def succ(a) false; end
  spec SPEC_UNARY, :succ
end

# should pass dependency
class PluginC
  extend PlanR::Plugin

  name 'Pass C'
  version '1.0'
  dependency A_NAME, '>=', A_VERSION
  dependency B_NAME, '<=', B_VERSION
end

# should fail dependency
class PluginD
  extend PlanR::Plugin

  name 'Fail D'
  version '1.0'
  dependency A_NAME, '>', A_VERSION
end

# should fail dependency
class PluginE
  extend PlanR::Plugin

  name 'Fail E'
  version '1.0'
  dependency A_NAME, '<', A_VERSION
end

# should fail dependency
class PluginF
  extend PlanR::Plugin

  name 'Fail F'
  version '1.0'
  dependency 'Non-Existent Plugin', '>=', '0.01'
end
# ----------------------------------------------------------------------

class TC_ApiDevTest < Test::Unit::TestCase

  def test_plugin
    u_spec = PlanR::Plugin::Specification.new(SPEC_UNARY, SPEC_UNARY_PROTO,
                                              SPEC_UNARY_IN, SPEC_UNARY_OUT)
    b_spec = PlanR::Plugin::Specification.new(SPEC_BINARY, SPEC_BINARY_PROTO,
                                              SPEC_BINARY_IN, SPEC_BINARY_OUT)
    assert_equal(u_spec, PlanR::Plugin::Specification.specs[SPEC_UNARY])
    assert_equal(u_spec.name, SPEC_UNARY)
    assert_equal(u_spec.proto, SPEC_UNARY_PROTO)
    assert_equal(u_spec.input, SPEC_UNARY_IN)
    assert_equal(u_spec.output, SPEC_UNARY_OUT)

    assert_equal(b_spec, PlanR::Plugin::Specification.specs[SPEC_BINARY])
    assert_equal(b_spec.name, SPEC_BINARY)
    assert_equal(b_spec.proto, SPEC_BINARY_PROTO)
    assert_equal(b_spec.input, SPEC_BINARY_IN)
    assert_equal(b_spec.output, SPEC_BINARY_OUT)

    # Plugin A
    assert(PlanR::Plugin.available_plugins.include? PluginA)
    a = PluginA.new
    assert_equal(PlanR::Plugin.available_plugins.select { |x| x == PluginA 
                                                        }.first, a.class)
    assert_equal(A_NAME, a.name)
    assert_equal(A_AUTHOR, a.author)
    assert_equal(A_VERSION, a.version)
    assert_equal(A_DESCR, a.descr)
    assert_equal(A_HELP, a.help)

    # A API
    assert(! (a.api.include? :difference) )

    assert( (a.api.include? :sum) )
    assert(! (a.api(true).include? :sum) )
    assert_equal( 'Not documented', a.api[:sum].descr )

    assert( (a.api.include? :product) )
    assert( (a.api(true).include? :product) )
    assert_not_equal( 'Not documented', a.api[:product].descr )
    assert_equal( A_API_IN, a.api[:product].arguments )
    assert_equal( A_API_OUT, a.api[:product].return_value )
    assert_equal( A_API_DESCR, a.api[:product].descr )

    assert( (a.api.include? :quotient) )
    assert(! (a.api(true).include? :quotient) )
    assert_equal( 'Not documented', a.api[:quotient].descr )

    # A Specs
    assert( (a.spec_supported? SPEC_UNARY) != nil )
    assert( (a.spec_supported? SPEC_BINARY) != nil )
    assert( (a.spec_supported? :fake_spec) == nil )

    assert_equal( 6, (a.spec_invoke(SPEC_UNARY, 5)) )
    assert_equal( 5, (a.spec_invoke(SPEC_BINARY, 2, 3)) )
    assert_raises(PlanR::Plugin::InvalidSpecificationError) {
      a.spec_invoke(:fake_spec, 0)
    }
    assert_raises(PlanR::Plugin::ArgumentTypeError) {
      a.spec_invoke(SPEC_UNARY, false)
    }
    assert_raises(PlanR::Plugin::ArgumentTypeError) {
      a.spec_invoke(SPEC_BINARY, 1)
    }

    assert(PlanR::Plugin.available_plugins.include? PluginB)
    b = PluginB.new
    assert_equal(PlanR::Plugin.available_plugins.select { |x| x == PluginB 
                                                        }.first, b.class)
    # Plugin B

    assert_equal(B_NAME, b.name)
    assert_equal(B_AUTHOR, b.author)
    assert_equal(B_VERSION, b.version)
    assert_equal(B_DESCR, b.descr)
    assert_equal(B_HELP, b.help)
    
    # NOTE: this is only raised if $TG_PLUGIN_FORCE_VALID_RETURN is true
    assert_raises(PlanR::Plugin::ArgumentTypeError) {
      b.spec_invoke(SPEC_UNARY, 1)
    }
  end

  def test_plugin_version_cmp
    a = PluginA.new

    assert_equal(-1, a.class.version_cmp('1', '2'))
    assert_equal(-1, a.class.version_cmp('1.0', '2.0'))
    assert_equal(-1, a.class.version_cmp('1.0.1', '2.0.1'))
    assert_equal(-1, a.class.version_cmp('1.0.1-pre', '2.0'))
    assert_equal(-1, a.class.version_cmp('1.0.1', '2'))
    assert_equal(-1, a.class.version_cmp('1.0.1', '1.2'))
    assert_equal(-1, a.class.version_cmp('1.0.1', '1.1.0'))
    assert_equal(-1, a.class.version_cmp('1.0.1', '1.0.2'))
    assert_equal(-1, a.class.version_cmp('1.0.1-pre', '1.0.2'))
    assert_equal(-1, a.class.version_cmp('1.0.1-pre', '1.0.1-release'))

    assert_equal(0, a.class.version_cmp('1', '1'))
    assert_equal(0, a.class.version_cmp('1.0', '1.0'))
    assert_equal(0, a.class.version_cmp('1.0.1', '1.0.1'))
    assert_equal(0, a.class.version_cmp('1.0.1.0', '1.0.1.0'))
    assert_equal(0, a.class.version_cmp('1.0.1.0-pre', '1.0.1.0-pre'))

    assert_equal(1, a.class.version_cmp('2', '1'))
    assert_equal(1, a.class.version_cmp('2.0', '1.9'))
    assert_equal(1, a.class.version_cmp('2.0', '1.9.9'))
    assert_equal(1, a.class.version_cmp('2.0', '1.9.9.9'))
    assert_equal(1, a.class.version_cmp('1.9', '1.8.9'))
  end

  def test_plugin_manager
  end
end
