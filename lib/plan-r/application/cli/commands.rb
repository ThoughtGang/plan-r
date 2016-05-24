#!/usr/bin/env ruby
# :title: Plan-R CLI Commands
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end    

module PlanR
  module Cli

    # this should never be needed, but just in case...
    autoload :Command, 'plan-r/application/cli/command'

=begin rdoc
=end
    module Commands
      FILE_COMPLETER = Proc.new { |str|
        Dir[str+'*'].grep(/^#{str}/)
      }

      # FIXME: extract to modules in commands dir

      # ----------------------------------------------------------------------
      # help
      Command.new('help', 'Help on various commands', 'COMMAND', '',
                  Proc.new { |str| 
                    Command.help_verbs.grep(/^#{str}/)
                  },
                  Proc.new { |str| 
                    # FIXME: actually parse command name!
                    [str]
                  },
                  Proc.new { |str, args| 
                    puts "help document for #{str}..." 
                    true
                  } )

      # history
      Command.new('history', 'Manage history', '[-c]', 
                  'command history use -c to clear', nil,
                  Proc.new { |str|
                    # FIXME : parse args if any
                    [str]
                  },
                  Proc.new { |args, app| 
                    puts "history ..." 
                    true
                  } )

      # version
      Command.new('version', 'Display version number', '', '', nil, nil,
                  Proc.new { |args, app|
                    h = app.version
                    h = { 'Application' => h } if (! h.kind_of? Hash)
                    h.each { |k,v| app.cmd_print("#{k}: #{v}\n") }
                    true
                  } )

      # quit
      Command.new('quit', 'Quit', '', '', nil, nil,
                  Proc.new { |args, app| 
                    # NOTE: app is responsible for confirm
                    app.quit 
                    # FIXME: remove from history?
                    true
                  } )

      # open
      Command.new('open', 'Open a', 'REPO', 'Documentation for open', 
                  FILE_COMPLETER,
                  Proc.new { |str|
                    # FIXME: parse filename!
                    [str]
                  },
                  Proc.new { |args, app|
                    puts "open repo" 
                    true
                  } )
      # TODO: plugin list exec etc - in its own file
       # TODO: service lst start stop
      # inspect
      # git ...
      # sql ... [pass cm to git/sqlite]
    end

  end
end

# load everything in commands dir
Dir.foreach( File.join(File.dirname(__FILE__), 'commands') ) do |f|
  require_relative File.join('commands', f) if (f.end_with? '.rb') 
end
