#!/usr/bin/env ruby
# :title: PlanR::Plugins::Interpreter::Ruby
=begin rdoc
Interpreter plugin for ruby scripts
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document/script'
require 'plan-r/application/script_mgr'

require 'rbconfig'

module PlanR
  module Plugins
    module Interpreter

=begin rdoc
Plugin for executing ruby scripts
=end
      class Ruby
        extend TG::Plugin
        name 'Ruby Interpreter'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'Ruby script interpreter'
        help 'NOT IMPLEMENTED'

        LANG_NAME = 'Ruby'

        def application_startup(app)
          PlanR::Application::ScriptManager.register_language_interpreter(
                                            LANG_NAME, self)
        end

        def eval_ruby(script, stdin)
          return '' if (! script.abs_path)
          output = []

          # TODO: support script arguments, e.g. doc
          IO.popen("#{RbConfig.ruby} #{script.abs_path}") do |pipe|
            stdin.lines.each { |line| pipe.puts line }
            pipe.each { |line| output << line }
          end

          output.join("\n")
        end

        spec :evaluate, :eval_ruby, 50 #do |script, stdin|
        # TODO: check if script is a ruby script?
        #end
      end

    end
  end
end
