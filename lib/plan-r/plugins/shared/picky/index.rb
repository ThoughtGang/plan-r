#!/usr/bin/env ruby
# :title: PlanR::Plugins::Shared::PickyIndex
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

Index Picky Management settings
=end

require 'picky'

Picky.logger = Picky::Loggers::Silent.new
# Picky.logger = Picky::Loggers::Concise.new
# Picky.logger = Picky::Loggers::Verbose.new

# =============================================================================
module PlanR
  module Plugins

    module Picky
      class DocIndex < ::Picky::Index
        def initialize(name, repo, basename)
          dirname = File.join('indexes', 'picky', basename)
          #@basename = basename
          #@repo = repo
          @directory = repo.mk_repo_dir(dirname)
          # tag_logger = Logger.new "log/search.log"
          super name
        end

        # Picky has some pretty lame ideas about default index location
        def directory
          @directory
        end

=begin
List the IDs of all objects (Documents) known to the Index.
=end
        def indexed_ids
          doc_ids = { }
          docs = {}
          categories.each do |cat| 
            cat.exact.inverted.each do |arr| 
              arr.last.each { |id| docs[id] = true }
            end
          end
          docs.keys
        end

=begin rdoc
Return true if doc is indexed.
=end
        def indexed?(doc)
          indexed_ids.include? doc.id
        end

      end

=begin rdoc
This is needed to wrap Document because Picky DESTRUCTIVELY MODIFIES DATA|
PASSED TO IT.
See https://github.com/floere/picky/issues/39
=end
      class PickyDocument
        attr_reader :id, :tags, :keywords, :name, :author, :license, :language
        attr_reader :mime_type, :file_type, :path, :title, :description
        attr_reader :summary, :topics, :abstract
        attr_reader :contents
        def initialize(doc, toks=[])
          @id = doc.id.dup
          @tags = doc.tags.dup
          @keywords = (doc.properties[PlanR::Document::PROP_KEYWORDS] || []).dup
          @name = property_dup(doc, PlanR::Document::PROP_NAME)
          @author = property_dup(doc, PlanR::Document::PROP_AUTHOR)
          @license = property_dup(doc, PlanR::Document::PROP_LICENSE)
          @language = property_dup(doc, PlanR::Document::PROP_LANGUAGE)
          @file_type = property_dup(doc, PlanR::Document::PROP_FILETYPE)
          @description = property_dup(doc, PlanR::Document::PROP_DESCR)
          @summary = property_dup(doc, PlanR::Document::PROP_SUMMARY)
          @topics = (doc.properties[PlanR::Document::PROP_TOPICS] || []).dup
          @abstract = property_dup(doc, PlanR::Document::PROP_ABSTRACT)
          @mime_type = (doc.mime_type || '').dup
          @path = (doc.path || '').dup
          @title = (doc.title || '').dup
          @contents = (toks and (! toks.empty?)) ? parse_ts(toks) : 
                                                   parse_raw(doc.contents)
        end

=begin rdoc
Tokens can be an Array of tokens or a Hash of token raays. If a Hash,
then every token array is used (i.e. they care concatenated into one
big token array). This is likely not the intended behavor, so the
caller should determine what token array to use.
=end
        def parse_ts(h_toks)
          h_toks = { 'tokens' => h_toks } if (! h_toks.kind_of? Hash)
          toks = {}
          h_toks.each do |p, ts|
            ts.each { |tok| toks[tok] = true }
          end
          toks.keys
        end

        # This should never be needed, but just in case
        def parse_raw(buf)
          buf.split(/\s/)
        end

        private
        def property_dup(doc, name)
          (doc.properties[name] || '').to_s.dup
        end
      end

=begin rdoc
Return basic index name, e.g. 'tags' or 'docs'
=end
      def index_base_name
        self.class.const_get :INDEX_BASE_NAME
        #INDEX_BASE_NAME
      end

      def index_property_name
        self.class.const_get :INDEX_PROP_NAME
        #INDEX_PROP_NAME
      end

      def safe_index_name(repo)
        base = index_base_name
        base = base + '_' + repo.name.downcase.gsub(/[^[:alnum:]]/, '_')
        # this should be sufficient most of the time
        return base
        return base if (! ::Picky::Indexes.instance.include? base.to_sym)
        # ... but just in case
        base = base + '00'
        base.succ! while ::Picky::Indexes.instance.include? base.to_sym
        base
      end

      def open_index(repo)
        # NOTE: Picky uses a singleton (Picky::Indexes) in which indexes are
        #       registered by name. This means we cannot just use a simple
        #       index name, as that would make it impossible to open
        #       multiple repos in a single process.
        idx_name = repo.repo_properties[index_property_name]
        if (! idx_name)
          idx_name ||= safe_index_name(repo)
          repo.repo_properties[index_property_name] = idx_name
        end
        idx_name = idx_name.to_sym

        indexes[repo.base_path] = idx_name
        idx_name
      end

      def fetch_index(repo)
        idx_name = indexes[repo.base_path]
        if (! idx_name ) or (idx_name.empty?)
          # TODO: LOG
          $stderr.puts "PICKY IDX: Resorting to Repo#repo_properties"
        end
        idx_name = repo.repo_properties[index_property_name]
        if (! idx_name ) or (idx_name.empty?)
          # TODO: LOG
          $stderr.puts "LOST REPO NAME! Trying to reconstruct"
          # TODO : connect to first index matching 'name'?
          return
        end
        begin
          # can't just return nil, can they? gotta blow the world up.
          ::Picky::Indexes[idx_name.to_sym]
        rescue Exception => e
          $stderr.puts e.message
          $stderr.puts e.backtrace[0,4].join("\n")
          nil
        end
      end

      def read_index(idx)
        # picky's load() interface is quite fragile, so verify file exists
        dirname = idx.directory
        if (File.exist? dirname) and (File.directory? dirname) and
            (Dir.entries(dirname).count > 2)
          # even then, capture exceptions just in case
          begin
            idx.load
          rescue Exception => e
            # TODO: log
            $stderr.puts '[PICKY]' + e.message
          end
        end
      end

      def indexes
        @indexes ||= { }
      end

    end

  end
end
