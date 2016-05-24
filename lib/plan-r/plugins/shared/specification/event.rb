#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::Event
=begin rdoc
Specifications for event-based plugins
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
These specifications are used by the PluginManager to register plugins with
event notifications (e.g. Application Start, Repo Create, etc)
=end

require 'tg/plugin'
require 'plan-r/application'

module PlanR
  module Plugins
    module Spec

      # ----------------------------------------------------------------------
      # Application Startup
      #
      # Input: A PlanR::Application object
      # Output: nil
      TG::Plugin::Specification.new( :app_startup, 'fn(Application)',
                                     [PlanR::Application], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Application Startup
      #
      # Input: A PlanR::Application object
      # Output: nil
      TG::Plugin::Specification.new( :app_shutdown, 'fn(Application)',
                                     [PlanR::Application], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Repo Open
      # Input: A PlanR::Repo object
      # Output: nil
      TG::Plugin::Specification.new( :repo_open, 'fn(Repo)',
                                     [PlanR::Repo], [Object]
                                   )


      # ----------------------------------------------------------------------
      # Repo Save
      # Input: A PlanR::Repo object
      # Output: nil
      TG::Plugin::Specification.new( :repo_save, 'fn(Repo)',
                                     [PlanR::Repo], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Repo Close
      # Input: A PlanR::Repo object
      # Output: nil
      TG::Plugin::Specification.new( :repo_close, 'fn(Repo)',
                                     [PlanR::Repo], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Repo DB Connect
      # Input: A database connection (e.g. Sequel::DbConnection)
      # Output: nil
      # FIXME: OBSOLETE?
      TG::Plugin::Specification.new( :repo_db_connect, 'fn(Object)',
                                     [Object], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Repo Document-Added
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_add_doc, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )

      # ----------------------------------------------------------------------
      # Repo Document-Clones
      # This is invoked instead of :repo_add_doc when a document in a Repo
      # is copied (cloned). This operation is distinct from add, in that
      # Document.contents= has not been invoked (meaning that
      # DocumentManager.analyze_and_index_doc has not been invoked either).
      # Plugins which index documents should hook this in order to copy the
      # index entries for the cloned document.
      # Input: A PlanR::Document object representing the original, and a
      #        PlanR::Document object representing the clone
      # Output: nil
      TG::Plugin::Specification.new( :repo_add_doc, 
                                    'fn(Document orig, Document clone)',
                                     [PlanR::Document, PlanR::Document], 
                                     [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Removed
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_remove_doc, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Content-Updated
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_update_doc, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Revision-Created
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_doc_revision, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Indexed
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_doc_index, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Properties-Changed
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_doc_prop_change, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Tags-Changed
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_doc_tag_change, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
      
      # ----------------------------------------------------------------------
      # Repo Document-Metadata-Changed
      # Input: A PlanR::Document object
      # Output: nil
      TG::Plugin::Specification.new( :repo_doc_meta_change, 'fn(Document)',
                                     [PlanR::Document], [Object]
                                   )
    end
  end
end
