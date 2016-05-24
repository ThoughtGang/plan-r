#!/usr/bin/env ruby
# :title: PlanR::Application::Interpreter
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'open3'
require 'io/wait'

module PlanR
  module Application

=begin rdoc
An object that provides access to a Process running a command interpreter (e.g.
R, Octave, Maxima)
=end
    class Interpreter

      def initialize(cmd)
        @cmd = cmd
      end

      # TODO: make all of this stuff happen in a background thread!
      def start
        @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(@cmd)
        @pid = @wait_thr[:pid]
      end

      def term
        enter_statement( quit_command )
        @stdin.close; @stdout.close; @stderr.close; @wait_thr.value
      end

      def quit_command
        'exit'
      end

      def cmd_done_marker
        "__PID_#{@pid}__"
      end

      def statement_with_marker(cmd)
        cmd + "; echo \"#{cmd_done_marker}\""
      end

      def enter_statement(cmd)
        output = []
        error = []
        begin
          @stdin.puts(statement_with_marker cmd)

          # Wait for response
          while @stdout.wait(10) == false
            sleep 0.10
          end

          while @stdout.ready? || @stderr.ready?
            sleep 0.05  # give child a chance to flush output
            error += @stderr.read(@stderr.nread).split("\n") if @stderr.ready?
            if @stdout.ready?
              @stdout.read(@stdout.nread).split("\n").each do |line|
                output << line if line && (! line.empty?) &&
                                  (! line.end_with? "\"#{cmd_done_marker}\"")
              end
            end
          end
        rescue Errno::EPIPE => e
          error << e.message
        end

        {:stdin => cmd, :stdout => output.join("\n"), 
          :stderr => error.join("\n")}
      end

    end

  end
end
