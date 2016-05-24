#!/usr/bin/env ruby
# :title: PlanR::Application::ScriptManager
=begin rdoc
=PlanR ScriptManager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

# WARNING: this code is under active development and highly subject to change

require 'thread'

require 'plan-r/document/script'

require 'plan-r/application'
require 'plan-r/util/json'

module PlanR

  module Application

=begin rdoc
An application utility for managing Scripts in a repo.
Uses PluginManager to do everything.
=end
    module ScriptManager

      @@languages = {}

      # ----------------------------------------------------------------------
      # Script Instantiation

      def self.script(repo, path)
        Document.factory(repo, path, :script)
      end

      def self.create(repo, path, contents, language, interpreter=nil, 
                      editor=nil, props=nil)
        props ||= Script.default_properties
        props[:language] = language
        props[:interpreter] = interpreter if interpreter
        props[:editor] = editor if editor
        Document.create(repo, path, :script, contents, props) 
      end

      # ----------------------------------------------------------------------
      # Execution

=begin rdoc
Execute script in a child process and return STDOUT.
=end
      def self.exec(scpt, data)
        p = interpreter(scpt)
        p.spec_invoke(:evaluate, scpt, (data || '')) if p
      end

=begin rdoc
Execute script, using contents of document as input.
NOTE: If 'doc' is nil, this passes straight through to exec().
=end
      def self.exec_on_doc(scpt, doc)
        data = nil
        if doc
          data = doc.contents
        end
        exec(scpt, data)
      end

=begin rdoc
Execute script and store output in specified doc.
=end
      def self.exec_to_doc(scpt, doc, in_doc=nil)
        execute_to_path(scpt, doc.path, doc.node_type)
      end

      def self.execute_to_path(scpt, to_path, ctype=nil, in_doc=nil)
        ctype ||= in_doc.node_type if in_doc
        ctype ||= :document
        rv = exec_on_doc(scpt, in_doc)
        return if ! to_path

        ctype = scpt.output_doc_type
        # FIXME: verify that query is a viable origin
        query = ["doc_path=#{(in_doc && in_doc.path) || ''}",
                 "doc_type=#{(in_doc && in_doc.node_type) || ''}",
                 "output_path=#{to_path}"].join('&')
        props = {
          :title => scpt.output_doc_title,
          :origin => "script:///#{scpt.path}?#{query}"
        }
        PlanR::Document.create(scpt.repo, to_path, ctype, rv, props)
        # in case command-qithin-command causes problems:
        #PlanR::Document.create_simple(repo, to_path, tree, props)
      end

      # return interpreter for script
      def self.interpreter(scpt)
        name = scpt.interpreter
        if ! name
          lang = language(scpt.language)
          name = lang.default_interpreter if lang
        end
        if ! name
          # TODO: log
          $stderr.puts "Unsupported language #{scpt.language.inspect}"
        end

        PluginManager.find(name)
      end

      # return editor for script
      def self.editor(scpt)
        name = scpt.editor
        if ! name
          lang = language(scpt.language)
          name = lang.default_editor if lang
        end
        if ! name
          # TODO: log
          $stderr.puts "Unsupported language #{scpt.language.inspect}"
        end

        PluginManager.find(name)
      end

      # ----------------------------------------------------------------------
      # Languages
      # TODO: method for getting default language interp/edit from config

      def self.language(str)
        @@languages[str.to_sym]
      end

=begin rdoc
Invoked by interpreter plugins during application startup
=end
      def self.register_language_interpreter(name, plugin)
        lang = self.language(name) || add_language(name)
        lang.interpreters << plugin.name
      end

=begin rdoc
Invoked by editor plugins during application startup
=end
      def self.register_language_editor(name, plugin)
        lang = self.language(name) || add_language(name)
        lang.editors << plugin.name
      end

      def self.add_language(name)
        sym = name.to_sym
        return if (@@languages.include? sym)
        @@languages[sym] = PlanR::ScriptLanguage.new(name)
      end

=begin rdoc
List available languages
=end
      def self.languages
        @@languages.values.map { |lang| lang.name }
      end

      # ----------------------------------------------------------------------
      # File Management

=begin rdoc
List all scripts at or under 'path' in repo.
=end
      def self.list(repo, path='/', &block)
        entries = repo.lookup(path, :script, true, true, false).map { |k,v| v }
        entries.each { |p| yield p } if block_given?
        entries
      end

=begin rdoc
Move Script object to new path. Note that dest_path is a *full* path to 
the new Script, not to the directory containing it.
=end
      def self.move(scpt, dest_path, replace=true)
        scpt.repo.move(scpt.path, dest_path, :script, false, replace)
        # FIXME: if index...
        #update_doc_index(scpt.repo, scpt.path, dest_path)
      end

=begin rdoc
Copy Script object to new path. Note that dest_path is a *full* path to 
the new script, not to the directory containing it.
=end
      def self.copy(scpt, dest_path, replace=false)
        scpt.repo.move(scpt.path, dest_path, :script, false, replace)
        # FIXME: if index...
        #update_doc_index(scpt.repo, scpt.path, dest_path)
      end

=begin rdoc
Remove script from repository.
=end
      def self.remove(scpt)
        scpt.repo.remove(scpt.path, :script, false)
        # FIXME: if indexed...
      end

    end
  end
end
