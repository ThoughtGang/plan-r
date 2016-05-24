#!/usr/bin/env ruby
# :title: PlanR::Application::QueryManager
=begin rdoc
=PlanR QueryManager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

Application component for managing Search Engine plugins and Query objects.
=end

# WARNING: this code is under active development and highly subject to change

#require 'thread'

require 'plan-r/document/query'

#require 'plan-r/application'
#require 'plan-r/util/json'

module PlanR
  module Application

=begin rdoc
An application utility for managing Querys in a repo.
Uses PluginManager to do everything.
=end
    module QueryManager

      # ----------------------------------------------------------------------
      # Query Instantiation

=begin rdoc
Return StoredQuery Document at 'path' in repo.
=end
      def self.stored_query(repo, path)
        Document.factory(repo, path, :query)
      end

=begin rdoc
Create StoredQuery Document for 'query' at 'path' in repo.
=end
      def self.store(repo, path, query, engines, props=nil) 
        props ||= Document.default_properties
        props[StoredQuery::PROP_ENGINE] = [engines].flatten
        Document.create(repo, path, :query, query, props)
      end

      # ----------------------------------------------------------------------
      # Execution

=begin rdoc
Perform Query by invoking :query_index plugins on Query object. This returns a 
Hash [ Name -> Query::Result ] mapping plugin names to query results.
NOTE: 
=end
      def self.perform(repo, q, plugins=nil)
        h = {}
        Application::PluginManager.named_or_providing(:query_index,
                                                      plugins).each do |p|
          h[p.name] = p.spec_invoke(:query_index, repo, q)
        end
        h
      end
=begin rdoc
Return RelatedDocs object for 'path' in 'repo'.
If 'index' is an array or nil, a Hash is returned.
=end
      def self.related_docs(doc, index)
        # FIXME: implement
        raise('not implemented')
        results = {}

        each_index(doc.repo, index) do |p|
          next if not p.spec_supported?(:related_docs)
          results[p.name] = p.spec_invoke(:related_docs, doc).reject { |k,v|
                            k == doc.path }
        end

        results.values.count > 1 ? results : results.values.first
      end

=begin rdoc
Remove document at 'path' from index.
If 'index' can be a name, array or nil.
=end
      def self.remove_doc(doc, index)
        # FIXME: implement
        raise('not implemented')
        # TODO: uses :move_index_doc spec
      end

      # TODO: does this belong here?
      #def self.reindex_doc(doc, index)
      #end

      # ----------------------------------------------------------------------
      # File Management

      def self.list(repo, path='/', &block)
        # FIXME: OBSOLETE?
        raise('not implemented')
        entries = repo.list(path, true, :query)
        entries.each { |p| yield p } if block_given?
        entries
      end

=begin rdoc
Move Query object to new path. Note that dest_path is a *full* path to 
the new Query, not to the directory containing it.
=end
      def self.move(qry, dest_path)
        # FIXME: OBSOLETE?
        raise('not implemented')
        qry.repo.move qry.path, dest_path, qry.tree
      end

=begin rdoc
Copy Query object to new path. Note that dest_path is a *full* path to 
the new query, not to the directory containing it.
=end
      def self.copy(qry, dest_path)
        # FIXME: OBSOLETE?
        raise('not implemented')
        qry.repo.copy qry.path, dest_path, false, qry.tree
      end

=begin rdoc
Remove query from repository.
=end
      def self.remove(scpt)
        # FIXME: OBSOLETE?
        raise('not implemented')
        qry.repo.remove qry.path
      end

      # ----------------------------------------------------------------------
      # INDEX MANAGEMENT
      def self.index_stats(repo, opts, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:index_stats,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:index_stats, repo, opts)
        end
        h
      end

      def self.index_report(repo, opts, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:index_report,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:index_report, repo, opts)
        end
        h
      end

      def self.index_log(repo, opts, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:index_log,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:index_log, repo, opts)
        end
        h
      end

      def self.index_keywords(repo, opts={}, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:index_keywords,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:index_keywords, repo, opts)
        end
        h
      end

      def self.index_docs(repo, opts={}, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:index_docs,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:index_docs, repo, opts)
        end
        h
      end

      def self.parse_query(repo, q, plugin_name=nil)
        h = {}
        Application::PluginManager.named_or_providing(:query_parse,
                                                      plugin_name).each do |p|
          h[p.name] = p.spec_invoke(:query_parse, repo, q)
        end
        h
      end

=begin rdoc
List names of all plugins providing :query_index or other spec.
This is a convenience method for use by applications.
=end
      def self.indexes(spec=:query_index)
        Application::PluginManager.providing(spec).map { |p| p.name }
      end

=begin rdoc
Return number of documents in index.
=end
      def self.doc_count(repo, index)
        # FIXME: implement
        raise('not implemented')
        results = {}
        #each_index_stats(doc.repo, index) do |p, stats|
        #  results[p.name] = stats.inject([]) { |arr,(key, docs)|
        #                          arr.concat docs.keys; arr }.sort.uniq
        #end

        results.values.count > 1 ? results : results.values.first
      end

=begin rdoc
Return keywords in 'index' for 'path' in repo.
If 'index' is an array or nil, a Hash is returned.
=end
      # TODO: return freq as well?
      def self.doc_keywords(doc, index)
        # FIXME: implement
        raise('not implemented')
        results = {}
        #each_index_stats(doc.repo, index) do |p, stats|
        #  results[p.name] = extract_doc_keywords(doc.path, stats)
        #end

        results.values.count > 1 ? results : results.values.first
      end


      private


      #def self.extract_doc_keywords(path, stats)
      #  stats.inject([]) { |arr,(key,docs)| arr << key if docs[path]; arr }
      #end

    end
  end
end
