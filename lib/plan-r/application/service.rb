#!/usr/bin/env ruby
# :title: PlanR::Application::Service
=begin rdoc
Plan R base class for Application services

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

# TODO: dependency keyword. causes other service to be loaded first

require 'yaml'

module PlanR

  module Application

=begin rdoc
A singleton (i.e. module, non-instantiated class.

Example:

  class TheApplication
    include PlanR::Application

    def initialize(argv)
      # ... init code ...
      Service.init_services
    end

    def run
      Service.startup_services(self)
      # ... event loop ...
      Service.shutdown_services(self)
    end

    def new_repo_window(repo)
      # ... create a new repo window ...
      Service.broadcast_object_loaded(self, repo)
    end
=end
    module Service

      @service_classes = []
      def self.extended(cls)
        if ! (@service_classes.include? cls)
            @service_classes << cls
        end
      end

=begin rdoc
Array of Service classes that have been loaded by the application.
=end
      def self.services
        @service_classes.dup
      end

=begin rdoc
Array of names of Service classes that have been loaded by the application.
=end
      def self.service_names
        @service_classes.map { |cls| cls.name.split(':').last }
      end

=begin rdoc
Return true if specified service has been loaded by the application.
Use this instead of Object.defined?:
  if (Service.available? :PluginManager) ...
The service is specified by (non-qualified) class name, as a String or Symbol.
=end
      def self.available?(sym)
        service_names.include? sym.to_s
      end

      @enabled_services = []
      def self.enable(cls)
        if (cls.is_a? Symbol) or (cls.is_a? String)
          cls = service_class_lookup(cls)
        end
        @enabled_services << cls if (! @enabled_services.include? cls)
      end

      def self.disable(sym)
        name = sym.to_s.split(':').last
        @enabled_services.reject! { |cls| cls.name.split(':').last == name }
        # FIXME: if already running...
      end

      def self.service_class_lookup(sym)
        name = sym.to_s.split(':').last
        @service_classes.select { |cls| cls.name.split(':').last == name }.first
      end

=begin rdoc
Invoke the init class method for every registered service.
=end
      def self.init_services
        @enabled_services.each { |cls| cls.init if cls.respond_to? :init }
      end

=begin rdoc
This should be invoked after an application has completed startup.
=end
      def self.startup_services(app)
        @enabled_services.each { |cls| 
          cls.startup app if cls.respond_to? :startup 
        }
      end

=begin rdoc
=end
      def self.broadcast_object_loaded(app, obj)
        @enabled_services.each { |cls| 
          cls.object_loaded(app, obj) if cls.respond_to? :object_loaded
        }
      end

      # default implementation of object-loaded class method: no-op
      def self.object_loaded(app, obj)
      end

=begin rdoc
This should be invoked after an application is about to commence shutdown.
=end
      def self.shutdown_services(app)
        @enabled_services.each { |cls| 
          cls.shutdown app if cls.respond_to? :shutdown
        }
        Process.waitall
      end

    end

  end
end
