#!/usr/bin/env ruby
# :title: Plan-R CLI Tab Completion
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end    

require 'readline'
#require 'abbrev' 

require 'plan-r/application/cli/command'

module PlanR
  module Cli

    module Completion

      DEFAULT_PROMPT = '> '

      # TODO: plugin list exec etc - in its own file
      # ----------------------------------------------------------------------


      READLINE_PROC = Proc.new do |input_str|
        command = Readline.line_buffer.chomp(input_str).strip
        str = Regexp.escape(input_str)

        if command.empty?
          # top-level command
          #
          if (str =~ /^\s*$/)
              # print available commands 
              print "\n"
              Command.verbs.map { |cmd| puts( (' ' * @prompt.length) + cmd) }
              print prompt
              nil

          else
            # find closest matching command
            # NOTE: this should maybe be done better with Abbrev
            Command.verbs.grep(/^#{str}/).first
          end

        else
          cmd = Command.find(command)
          cmd ? cmd.complete(str) : nil
        end
      end

      # default options
      @prompt = DEFAULT_PROMPT
      @keep_history = true  # keep track of command history
      @vi_mode = false      # use vi or emacs mode?
      @libedit = false      # is libreadline actually libedit?

      def self.init_readline(options)
        # FIXME: read options
        # @keep_history = true
        # @prompt
        
        Readline.completion_proc = PlanR::Cli::Completion::READLINE_PROC
        Readline.completion_append_character = " "
        #Readline.completer_word_break_characters = ""

        # edit mode (+ libedit detect)
        begin
          @vi_mode ? Readline.vi_editing_mode : Readline.emacs_editing_mode
        rescue NotImplementedError
          @libedit = true
        end
      end

      def self.prompt
        @prompt
      end

      def self.set_prompt(str)
        @prompt = str
      end

      def self.readline
        Readline.readline(@prompt, @keep_history)
      end

      def self.history_remove_last
        Readline::HISTORY.pop
      end

      def self.history_contains?(str)
        # FIXME: TODO
        false
      end

    end
  end
end
