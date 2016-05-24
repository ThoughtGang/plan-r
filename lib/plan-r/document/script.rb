#!/usr/bin/env ruby
# :title: PlanR::Script
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/document'
require 'plan-r/repo'

module PlanR

=begin rdoc
A Language definition for Script objects. This associates a language name
(e.g. Ruby or R) with a list of plugins that can evalute or edit Scripts
for that language.
=end
  # FIXME: move to ScriptManager
  class ScriptLanguage
    attr_reader :name
    attr_reader :interpreters
    attr_writer :default_interpreter
    attr_reader :editors
    attr_writer :default_editor
    # FIXME: add mime-type attribute

    def initialize(name)
      @name = name
      @editors = []
      @interpreters = []
    end

    def default_interpreter
      @default_interpreter || @interpreters.first
    end

    def default_editor
      @default_editor || @editors.first
    end
  end

=begin rdoc
Note: A Script does NOT have access to a PlanR Repository or to PlanR objects.
A script is passed Document contents as input (usually via STDIN, though it 
depends on the Interpreter plugin) and returns Document contents as output 
(usually via STDOUT).

=end
  class Script < Document
    PROP_LANG   = :language         # name of ScriptLanguage object
    PROP_INTERP = :interpreter      # optional -- interpreter override
    PROP_EDIT   = :editor           # optional -- editor override
    PROP_OUT    = :output_doc_type  # optional -- output document type
    PROP_TITLE  = :output_doc_title # optional -- output document title

    def self.node_type
      :script
    end

    def self.default_properties
      props = super
      props[PROP_INDEX] = false
      props[PROP_SYNCPOL] = PlanR::Application::DocumentManager::SYNC_MANUAL
      props
    end

    def initialize(repo, path)
      super repo, path, self.class.node_type
    end

    def mime
      # FIXME: language-specific, e.g. text/python
      'text/plain'
    end

    def regenerate
      # nop
    end

    def language
      properties[PROP_LANG]
    end

    def language=(name)
      properties[PROP_LANG] = name
    end

    def output_doc_type
      properties[PROP_DOC] || :document
    end

    def output_doc_type=(tree)
      properties[PROP_DOC] = tree.to_sym
    end

    def output_doc_title
      properties[PROP_TITLE] || "Output of #{path}"
    end

    def output_doc_title=(str)
      properties[PROP_TITLE] = str
    end

    def interpreter
      properties[PROP_INTERP]
    end

    def interpreter=(name)
      properties[PROP_INTERP] = name
    end

    def editor
      properties[PROP_EDIT]
    end

    def editor=(name)
      properties[PROP_EDIT] = name
    end
  end

end
