#!/usr/bin/env ruby
# :title: PlanR::Plugins::Interpreter::Shell
=begin rdoc
Interpreter plugin for shell scripts
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document/script'
require 'plan-r/application/script_mgr'

module PlanR
  module Plugins
    module Interpreter

=begin rdoc
Plugin for executing shell scripts
=end
      class Shell
        extend TG::Plugin
        name 'Shell Interpreter'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'Shell script interpreter'
        help 'NOT IMPLEMENTED'

        LANG_NAME = 'sh'

        def application_startup(app)
          PlanR::Application::ScriptManager.register_language_interpreter(
                                            LANG_NAME, self)
        end

        def eval_shell(script, stdin)
          #`/bin/sh #{script.abs_path} #{args.join(' ')}`
          output = []
          # TODO : handle doc correctly
          IO.popen("/bin/sh #{script.abs_path}") do |pipe|
            stdin.lines.each { |line| pipe.puts line }
            pipe.each { |line| output << line }
          end

          output.join("\n")
        end

        spec :evaluate, :eval_shell, 50 # do |script, args|
        # TODO: check if script is a shell script?
      end

    end
  end
end
