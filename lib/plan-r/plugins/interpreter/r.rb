#!/usr/bin/env ruby
# :title: PlanR::Plugins::Interpreter::R
=begin rdoc
Interpreter plugin for R scripts and the R process.
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'plan-r/document/script'
require 'plan-r/application/interpreter'
require 'plan-r/application/script_mgr'

module PlanR
  module Plugins
    module Interpreter

=begin rdoc
Plugin for executing R scripts and launching R interpreters
=end
      class R
        extend TG::Plugin
        name 'R Interpreter'
        author 'dev@thoughtgang.org'
        version '0.01'
        description 'Interpreter for R language'
        help 'NOT IMPLEMENTED'

        LANG_NAME = 'R'

        class Interpreter < Application::Interpreter
          def initialize
            cmd = `which R`.chomp + ' --vanilla --no-readline --slave'
            super cmd
          end

          def quit_command
            'q()'
          end

          def cmd_done_marker
            "$PID$#{@pid}$"
          end

          def statement_with_marker(cmd)
            cmd + "; print(\"#{cmd_done_marker}\")"
          end
        end

        def application_startup(app)
          PlanR::Application::ScriptManager.register_language_interpreter(
                                            LANG_NAME, self)
        end

        def application_shutdown(app)
          (@instances || []).each { |r| r.term }
        end

        def launch_r
          @instances ||= []
          r = Interpreter.new
          r.start
          @instances << r
          r
        end
        spec :interpreter, :launch_r, 70

=begin
        def eval_r(script, args)
          # FIXME: actually evaluate script using R
          #        keep interpreter running?
          output = []
          #IO.popen("R #{script.abs_path}") do |pipe|
          #  args.contents.lines.each { |line| pipe.puts line }
          #  pipe.each { |line| output << line }
          #end
          output.join("\n")
        end

        spec :evaluate, :eval_r, 50 # do |script, args|
        # TODO: check if script is an R script?
=end
      end

    end
  end
end
