#!/usr/bin/env ruby
# :title: Plan-R CLI Command object
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end    

module PlanR
  module Cli

    class Command

      attr_reader :verb
      attr_reader :descr
      attr_reader :usage
      attr_reader :doc
      attr_reader :completer
      attr_reader :parser
      attr_reader :action

      @commands = []

      def self.list
        @commands
      end

      @verbs = nil
      def self.verbs
        @verbs ||= @commands.map { |x| x.verb }
      end

      @help_verbs = nil
      def self.help_verbs
        @help_verbs ||= @commands.reject { |x| x.doc.empty? }.map { |x| x.verb }
      end

      def self.find(name)
        @commands.select { |x| x.verb == name }.first
      end

      def self.add_command(obj)
        @commands << obj
      end

      @null_command = nil

=begin rdoc
A NULL object representing commands that do not exist (e.g. Not Found).
=end
      def self.null_command
        @null_command ||= self.new('command', '', '', '', nil, nil, nil) 
      end

      # NOTE: app must respond to options (an Openstruct),
      #       repo, repo=, cmd_print, cmd_log, cmd_error,
      #       version
      # returns true or false (success)
      def self.perform(stmt, app)
        begin
          cmd, args = stmt.split(/\s/, 2)
          cmd_obj = @commands.select { |x| x.verb == cmd }.first
          if cmd_obj
            cmd_obj.perform(args, app)
          else
            # No such command
            app.cmd_error( null_command, "'#{cmd}' not found" )
            false
          end
        rescue Exception => e
          app.cmd_error( cmd_obj, e.message, false )
          # FIXME: if --debug
          app.cmd_error( cmd_obj, 'Trace:' + e.backtrace[0,4].join("\n") )
          false
        end
      end

      def initialize( cmd, descr, usage, doc, completion_proc, parse_proc, 
                      action_proc)
        @verb = cmd
        @descr = descr
        @usage = usage
        @doc = doc
        @completer = completion_proc
        @parser = parse_proc
        @action = action_proc
        self.class.add_command self
      end

      def complete(str)
        return nil if (! completer)
        completer.call str
      end

      def parse(argstr, app)
        return [argstr] if (! parser)
        begin
          @parser.call argstr #, app
        rescue Exception => e
          # print error with usage string
          app.cmd_error(verb, "Invalid arguments '#{argstr}'", true)
          nil
        end
      end

      # must return success or failure
      def perform(argstr, app)
        return true if (! action)
        toks = parse(argstr, app)
        toks ? action.call(toks, app) : false
      end

    end

  end
end

# load all command definitions
require 'plan-r/application/cli/commands'
