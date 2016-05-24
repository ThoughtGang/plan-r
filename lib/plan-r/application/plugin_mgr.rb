#!/usr/bin/env ruby
# :title: PlanR::PluginManager
=begin rdoc
Plan R Plugin Manager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'
require 'tg/plugin_mgr'
require 'plan-r/application/service'

module PlanR

  module Application

=begin rdoc
An application service for managing plugins. There are two main reponsibilities
of the service: finding and loading ('read') Ruby module files that contain
Plugin classes, and instantiating ('load') those classes. Additional features
include conveying notifications between the application and the plugins,
resolving Plugin dependencies, and listing or finding Plugins.

The PluginManager acts as a singleton; everything is handled through class
members and class methods. Many functions are delegates for Plugin class 
methods.

Example:

  require 'plan-r/application'

  class TheApplication
    include Application

    attr_reader :plugin_mgr

    def initialize(argv)
      # ... init code ...
      @plugin_mgr.add_base_dir( File.join('the_app', 'plugins') )
      Service.init_services
    end
  end

=end
    class PluginManager < TG::PluginManager
      extend Service

      CONF_NAME = 'plugins'

      # TG::PluginManager assumes one spec dir; add support for more.
      @plan_r_spec_dirs = [ File.join( File.dirname(File.dirname(__FILE__)), 
                                       'plugins/shared/specification' ) ]
      def self.add_spec_dir(dir)
        @plan_r_spec_dirs << dir
      end

      # ----------------------------------------------------------------------
=begin rdoc
Initialize the Plugin Manager.
This reads the ruby modules in all plugin directories, then loads all plugins 
that are not blacklisted.
=end
      def self.init
        # load built-in specifications
        @plan_r_spec_dirs.each do |spec_dir|
          load_specification_dir spec_dir
        end

        # load built-in plugin directories
        add_base_dir File.join('plan-r', 'plugins')

        read_config
        app_init
      end

=begin rdoc
Read PluginManager configuration from Application config file
=end
      def self.read_config
        @config = Application.config.read_config(CONF_NAME)
        read_config_hash(@config, true)
      end

=begin rdoc
Convenience method returning either the named plugin or all plugins which
implement spec.
Returns an empty array if no plugins implement spec, or if the specified
plugin does not implement spec.
NOTE: plugin_name can be a String or an Array of String.
=end
      def self.named_or_providing(spec, plugin_name=nil)
        if plugin_name
          names = [ plugin_name ].flatten
          names.map { |name| p = find(name) 
                    }.select { |p| (p.spec_supported? spec).to_i > 0 }
        else
          providing(spec).map { |p,r| p }
        end
      end

      # ----------------------------------------------------------------------
      # EVENT HANDLERS
=begin rdoc
Invoke Plugin#application_startup(app) in every loaded plugin.

This should be invoked after an application has completed startup.
=end
      def self.startup(app)
        app_startup(app)
        self.providing(:app_startup).each do |p, rating|
          p.spec_invoke(:app_startup, app)
        end
      end

=begin rdoc
Invoke Plugin#application_object_load(app, obj) in every loaded plugin.

This is invoked by the application whenever a new document or repo is
loaded. This gives plugins a chance to register themselves with new
document windows.
=end
      def self.object_loaded(app, obj)
        # read object-specific config. this can be a repo config that
        # enables or disables plugins
        if obj.respond_to? :config
          read_config_hash((obj.config || {})[CONF_NAME])
        end

        app_object_loaded(obj, app)
        if (obj.kind_of? PlanR::Repo)
          self.providing(:repo_open).each do |p, rating|
            p.spec_invoke(:repo_open, obj)
          end
          subscribe_to_repo(obj)
        end
      end

=begin rdoc
Invoke Plugin#application_shutdown(app) in every loaded plugin.

This should be invoked after an application is about to commence shutdown.
=end
      def self.shutdown(app)
        app_shutdown(app)
        self.providing(:app_shutdown).each do |p, rating|
          p.spec_invoke(:app_shutdown, app)
        end
      end

      # ----------------------------------------------------------------------
      # NOTIFICATIONS

      # map an event symbol to a specification
      EVENT_TO_SPEC_MAP = {
        Repo::EVENT_ADD    => :repo_add_doc,
        Repo::EVENT_CLONE  => :repo_clone_doc,
        Repo::EVENT_REMOVE => :repo_remove_doc,
        Repo::EVENT_UPDATE => :repo_update_doc,
        Repo::EVENT_REV    => :repo_doc_revision,
        Repo::EVENT_INDEX  => :repo_doc_index,
        Repo::EVENT_PROPS  => :repo_doc_prop_change,
        Repo::EVENT_TAG    => :repo_doc_tag_change,
        Repo::EVENT_META   => :repo_doc_meta_change,
        Repo::EVENT_DB     => :repo_db_connect,
        Repo::EVENT_SAVE   => :repo_save,
        Repo::EVENT_CLOSE  => :repo_close
      }
      DOC_EVENTS = [
        Repo::EVENT_ADD, Repo::EVENT_CLONE, Repo::EVENT_REMOVE, 
        Repo::EVENT_UPDATE, Repo::EVENT_REV, Repo::EVENT_INDEX, 
        Repo::EVENT_PROPS, Repo::EVENT_TAG, Repo::EVENT_META
      ]
=begin rdoc
Plugin notifications
This will invoke all plugins that implement and event spec.
=end
      def self.subscribe_to_repo(repo)
        repo.subscribe(self) do |event, *args|
          sym = EVENT_TO_SPEC_MAP[event]
          next if (! sym)
          subscribers = self.providing(sym)
          spec_args = (DOC_EVENTS.include? event) ? 
                      gen_doc_args(repo, event, args.dup) : args
          subscribers.each do |p, rating|
            p.spec_invoke(sym, *spec_args)
          end
        end
      end

      private
      def self.gen_doc_args(repo, event, args)
        arr = []
        path = args.shift
        ctype = args.shift
        doc = DocumentManager.doc_factory(repo, path, ctype)
        arr << doc if doc
        # FIXME: logging if ! doc
        if event == Repo::EVENT_CLONE
          doc =  DocumentManager.doc_factory(repo, args.shift, ctype)
          arr << doc if doc
        end
        arr.concat args
        arr
      end

      # init means this is being read before plugin manager service has started
      def self.read_config_hash(h, init=false)
        h ||= {}

        $TG_PLUGIN_FORCE_VALID_RETURN=true if h['strict_return']
        $TG_PLUGIN_DEBUG_STREAM=$stderr if h['debug']
        $TG_PLUGIN_DEBUG=false if h['debug']

        (h['prevent_loading'] || []).each do |path|
          blacklist_file(path)
        end

        (h['base_dirs'] || []).each do |path|
          # NOTE: This has no effect after init
          add_base_dir( path ) if (File.directory? path)
        end

        (h['plugin_dirs'] || []).each do |path|
          next if (! File.directory? path)
          add_plugin_dir(path)
          # if already initialized, load path
          read_dir(path) if (! init)
        end

        (h['plugin_files'] || []).each do |path|
          self.read_file(path) if (File.exist? path)
        end

        (h['enable'] || []).each do |name|
          # plugins are enabled by default, so this just un-disables plugins
          blacklist_remove(name)
        end
        (h['disable'] || []).each do |name|
          blacklist(name)
        end

        (h['bias'] || {}).each do |plugin_name, p_h|
          (p_h || {}).each do |spec_name, bias|
            set_spec_bias(spec_name, plugin_name, bias.to_i)
          end
        end
      end
    end

  end
end
