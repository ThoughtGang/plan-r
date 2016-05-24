#!/usr/bin/env ruby
# :title: PlanR::Application::DocumentManager
=begin rdoc
=PlanR Document DocumentManager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

== How importing a Document works
  1. Application calls DocumentManager.import
  2. -DocumentManager calls Document.import
  3. --Document creates a new in-memory Document instance
  4. ---Document calls Document#regenerate on instance
  5. ----Document obj calls DocumentManager.refresh_doc
  6. -----DocumentManager calls DocumentManager.refresh_doc_backend,
  7. DocumentManager calls DocumentManager.fetch_and_mirror
     The appropriate :data_source plugin is invoked.
     All :ident plugins are invoked.
     The appropriate :mirror_doc plugin is invoked.
  8. -DocumentManager calls Document#contents=
  9. --Document obj calls Repository.add
       This creates the object in the Content Repository
 10. --Document obj calls DocumentManager.analyze_and_index_doc
 11. DocumentManager calls DocumentManager.unpack_doc
     The appropriate :unpack_doc plugin is invoked.
 12. DocumentManager calls DocumentManager.parse_doc
     The appropriate :parse_doc plugin is invoked.
 13. DocumentManager calls DocumentManager.analyze_doc
     All :analyze_doc plugins are invoked.
 14. DocumentManager calls DocumentManager.tokenize_doc
     All :tokenize_doc plugins are invoked.
 15. DocumentManager calls DocumentManager.index_doc
     All :index_doc plugins are invoked.
 16. DocumentManager calls Document#properties=
=end

require 'thread'

require 'uri'
require 'plan-r/repo'
require 'plan-r/document'
require 'plan-r/datatype/parsed_document'

require 'plan-r/application'

module PlanR

  module Application

=begin rdoc
An application utility for managing documents. Performs meta-operations such
as import, analyze, search, and remove.
Uses PluginManager to do everything.

Note: DocumentManager methods act only on Document objects; they are not
passed low-level Repository arguments such as Tree idents.
=end
    module DocumentManager

      # Synchronization
      SYNC_MANUAL = 'manual'        # sync only on explicit user request
      SYNC_AUTO   = 'auto'          # sync when repo is synced
      SYNC_START  = 'startup'       # sync auto and at app startup
      SYNC_ACCESS = 'access'        # sync auto and when accessed
      SYNC_OPTIONS = [SYNC_MANUAL, SYNC_AUTO, SYNC_START, SYNC_ACCESS]

      SYNC_APPEND  = 'append'       # append synced content to document
      SYNC_REPLACE = 'replace'      # overwrite document with synced content
      SYNC_CONTENT_METHODS = [SYNC_APPEND, SYNC_REPLACE]

=begin rdoc
Options object specifying how to synchronize a document.
=end
      class SyncOptions
        attr_accessor :sync          # sync policy
        attr_accessor :sync_method   # append or overwrite
        attr_accessor :src_plugin    # Data Source plugin
        attr_accessor :mirror_plugin # Mirror plugin
        attr_accessor :orphan        # Forget origin (cache=true, sync=false)
        attr_accessor :cache         # Cache locally (otherwise SYNC_ACCESS)
        attr_accessor :index         # Index document on sync

        def initialize(sync=SYNC_AUTO, sync_method=SYNC_REPLACE, source=nil, 
                       mirror=nil, orphan=false, cache=true, index=true)
          @sync = sync
          @sync_method = sync_method
          @src_plugin = source
          @mirror_plugin = mirror
          @orphan = orphan
          @cache = cache
          @index = index
        end

=begin rdoc
Generate a Hash of Document properties hash contents
=end
        def to_prop_h
          { 
            Document::PROP_SYNCPOL => sync,
            Document::PROP_SYNCMETH => sync_method,
            Document::PROP_DATASRC => src_plugin,
            Document::PROP_MIRROR => mirror_plugin,
            Document::PROP_CACHE => cache,
            Document::PROP_INDEX => index
          }
        end
      end

      # ----------------------------------------------------------------------
      # Document Instantiation
=begin rdoc
Convenience method to return a doc object for a repo Document.
=end
      def self.document(repo, path) repo_document(repo, path, :document); end

=begin rdoc
Convenience method to return a doc object for a repo Note.
=end
      def self.note(repo, path) repo_document(repo, path, :note); end

=begin rdoc
Convenience method to return a doc object for a repo Dict.
=end
      def self.table(repo, path) repo_document(repo, path, :dict); end

=begin rdoc
Convenience method to return a doc object for a repo Table.
=end
      def self.table(repo, path) repo_document(repo, path, :table); end

=begin rdoc
Convenience method to return first doc object found in repo for 'path'.
Note that document types are searched in lexical order.
=end
      def self.doc_factory(repo, path, ctype=nil)
        doc = nil
        # NOTE: This gives document precedence in per-node-type lookup
        ctype ||= [:document, repo.content_types]
        [ctype].flatten.each do |key|
          doc = repo.exist?(path, key) ? repo_document(repo, path, key) : nil
          break if doc
        end
        doc
      end

=begin rdoc
Return true if document of the specified type (or any) exists in repo.
=end
      def self.doc_exist?(repo, path, ctype=nil)
        repo.exist?(path, ctype)
      end

=begin rdoc
Return a sorted list of document types in the repo.
=end
      def self.document_types(repo, meta=false)
        repo.content_types(meta).sort
      end

=begin rdoc
Return default properties for the specified class.
=end
      def self.default_properties(node_type=:document)
        cls = Document.class_for(node_type)
        cls ? cls.default_properties : Document.default_properties
      end

      def self.known_keywords(repo, plugin=nil)
        # returns a Hash plugin_name -> Array of keywords
        ::PlanR::Application::QueryManager.index_keywords(repo, {}, plugin)
      end

      def self.known_tags(repo)
        # NOTE: This is a hard-coded plugin name!
        known_keywords(repo, 'Tag Index').values.first
      end

      # ----------------------------------------------------------------------
      # Document Creation
=begin rdoc
Origin is a path or URI.

This invokes a Loader based on whether the file is local or remote, an
Ident plugin to identify the document type, a Parser to create a Datatype
for the document, and finally Repo.import(datatype, dest_path).

block is used to determine whether to add datatype when recursing. It is 
invoked with a path or URL.

dest_path is the folder to contain the file.

NOTE: this imports the document under the name File.basename(origin) unless
dest_path is specified. If dest_path ends with a '/', it is used as the 
destination the destination *directory*. 

'opts' is a SyncOptions object.
=end


      # document has properties:
      #   origin (remote location or nil if orphan)
      #   sync (auto(on update) manual start(auto) access(auto))
      #   sync-plugin
      #   no-cache (contents never stored on disk) (requires sync=access)
      def self.import(repo, origin, dest_path='', opts=nil, &block)
        local = (URI.parse(origin).scheme) == nil
        origin = File.expand_path(origin) if local

        if local && (File.exist? origin) && (File.directory? origin)
          return import_dir(repo, origin, dest_path, opts, &block)
        end

        # This is URI-safe, though it may give odd results
        fname = File.basename(origin)
        dest_path = File.join(dest_path, fname) if (dest_path.end_with? '/')

        PlanR::Document.import(repo, dest_path, origin, opts)
      end

=begin rdoc
Recursively import a directory.
=end
      def self.import_dir(repo, origin_path, dest_path='', opts=nil, &block)
        dest_path = File.join(dest_path, File.basename(origin_path)) if \
                    dest_path.end_with? '/'
        # default to name of directory
        dest_path = "#{File.basename(origin_path)}" if dest_path.empty?

        Dir.entries(origin_path).each do |fname|
          next if fname == '.' || fname == '..'
          path = File.join(origin_path, fname)
          next if (block_given?) && (! block.call(fname, path))
          next_dest_path = File.join(dest_path, fname)
          if File.directory?(path)
            import_dir(repo, path, next_dest_path, opts, &block)
          else
            import(repo, path, next_dest_path, opts, &block)
          end
        end
      end

=begin rdoc
Import a Document object (e.g. one created by a plugin, or from another Repo)
into Repo.
=end
      def self.import_doc(repo, dest_path, doc)
        PlanR::Document.create_doc(repo, dest_path, doc)
      end

=begin rdoc
Import raw data into a repository document. This creates a Document object
with the specified contents and properties. If no :title property is provided,
a default title is generated from the contents.

Note that the caller may want to set the following properties:
  :title
  :origin
  :mime_type
  :encoding
  :charset
See Document::create_raw().
=end
      def self.import_raw(repo, dest_path, contents, props=nil)
        # FIXME : REVIEW (obsolete?)
        PlanR::Document.create_raw(repo, dest_path, contents, props)
      end

=begin rdoc
Return a valid filename based on 'path' that does not already exist in the
repo.
This appends the timestamp to the filename, then increments the filename until
it is unique.

Note: this cleans the path so it only contains alphanumeric characters, hyphens,
underscores, and periods.
=end
      def self.safe_filename(repo, path, ctype=:document)
        safe_path = File.basename(path).gsub(/[^-._[:alnum:]]/, '_')
        return safe_path if (! repo.exist?(safe_path, ctype))
        safe_path += '-' + Time.now.to_i.to_s + '-1'
        until (! repo.exist?(safe_path, ctype)) do
          safe_path.succ!
        end
        safe_path
      end

=begin rdoc
Create a new document node of any content type in the repository. File 
contents can be empty.
Note: this method is simply a wrapper for import_raw if ctype is document and
contents is not empty.
=end
      def self.new_file(repo, ctype, dest_path, contents, props=nil)
        # FIXME : review
        # FIXME: abort if filename not available
        #dest_path = File.join(File.dirname(dest_path), 
        #                      new_filename(repo, dest_path, ctype))

        # Use import_raw if this is an actual document with actual contents
        return import_raw(repo, dest_path, contents, props) if \
               (ctype == :document) && contents && (! contents.empty?)

        doc = PlanR::Document.create(repo, dest_path, ctype, contents, props)
      end

=begin rdoc
Add a folder to the repo using specified path. The properties Hash will be
applied to this folder if it is supplied.
=end
      def self.new_folder(repo, dest_path, props=nil)
        repo.mkdir(dest_path)
        repo.add_metadata(dest_path, :folder, props, :properties) if props
      end

      # ----------------------------------------------------------------------
      # Document Management

=begin rdoc
Fetch a document and mirror it locally.

The 'fetch' stage uses an appropriate Data Source plugin to read document 
at doc.origin (a path, URL, URI object, or other data source supported by
a plugin), and generates a String containing the document contents.

The 'mirror' stage creates a mirrored copy of the specified document. This 
parses the fetched document contents and fetches any required resources 
(e.g. HTML images, stylesheets, or javascript), saving them in the Resources
metadata tree and localizing all document references to them.

Return value is the localized document contents.
=end
      # TODO: do not fetch if document has not changed! [META]
      #       due to localization, this cannot just be a buf compare!
      def self.fetch_and_mirror(doc)

        # get data souce plugin
        loader = nil
        p_name = doc.properties[Document::PROP_DATASRC]
        pmgr = PluginManager
        if (p_name and ! p_name.empty?)
          loader = pmgr.find(p_name)
        end
        if (! loader)
          # FIXME: log
          # $stderr.puts "Could not find plugin '#{p_name}'. Using default."
          pmgr.fittest_providing(:data_source, doc.origin, doc.repo) { |p|
            loader = p
          }
        end

        if (! loader)
          # FIXME: log
          $stderr.puts "No suitable :data_source found for #{doc.origin}" 
          return nil
        end

        # 1. fetch document from remote or local location
        # note: provide (optional) last-updated date?
        buf = loader.spec_invoke(:data_source, doc.origin, doc.repo)

        # FIXME: log
        $stderr.puts "Could not read #{doc.origin}" if ! buf
        return nil if (! buf )

        # 2. ident document and set properties
        doc.ident = ident_data(buf, doc.origin)

        # 3. mirror document into Hash
        h = {}
        # get mirror plugin
        mirror = nil
        p_name = doc.properties[Document::PROP_MIRROR]
        if (p_name and ! p_name.empty?)
          mirror = pmgr.find(p_name)
          # FIXME: log
          $stderr.puts "Could not find plugin '#{p_name}'. Using default."
        end
        if (! mirror)
          pmgr.fittest_providing(:mirror_doc, doc, buf, loader) { |p|
            mirror = p
          }
        end
        if (mirror)
          h_m = mirror.spec_invoke(:mirror_doc, doc, buf, loader)
          h = h_m if h_m
        end

        # 4. Store mirrored resources in repo
        # FIXME: should also have document resource-properties
        #        and maybe content properties too
        h[:resources].each { |k,v| doc.set_resource(k, v) } if h[:resources]


        # 5. Set plugins used to fetch and mirror doc
        doc.properties[Document::PROP_DATASRC] = loader.name 
        doc.properties[Document::PROP_MIRROR]  = mirror.name if mirror

        h[:contents] ? h[:contents] : buf
      end

=begin rdoc
Unpack Document into the Content Repository.

This finds the most suitable plugin (if any) for creating a nested document
out of 'doc'. For example, a plugin could parse a binary file, and create
child Documents representing file sections, child Notes containing metadata,
or child Tables containing Array or Matrix data from within the file.

Returns True if the document was unpacked, False if the unpack failed, and
nil if no :unpack_doc plugin was found.
=end
      def self.unpack_doc(doc, plugin_name=nil)
        p = plugin_name ? PluginManager.find(plugin_name) :
                          PluginManager.fittest_providing(:unpack_doc, doc)
        p ? p.spec_invoke(:unpack_doc, doc) : nil
      end

=begin rdoc
Update all paths to resources in document.

This finds the most suitable plugin (if any) for updating the document contents
so that resource links are no longer broken.
=end
      def self.rebase_doc(doc, plugin_name=nil)
        p = plugin_name ? PluginManager.find(plugin_name) :
                          PluginManager.fittest_providing(:rebase_doc, doc)
        p ? p.spec_invoke(:rebase_doc, doc) : nil
      end

=begin rdoc
Parse a PlanR::Document. This returns a ParsedDocument object.
=end
      def self.parse_doc(doc, plugin_name=nil)
        p = plugin_name ? PluginManager.find(plugin_name) :
                          PluginManager.fittest_providing(:parse_doc, doc)

        return nil if ! p
        # FIXME: log
        #$stderr.puts "[PARSE_DOC] Plugin: #{p.name}"
        rv = p.spec_invoke(:parse_doc, doc) 
        doc.properties[Document::PROP_PARSER] = p.name if (p && rv)
        rv
      end

=begin rdoc
Build an optimal ident object from all parser plugins.

Note that this is an improvement over the PluginManager.fittest_providing() 
approach, as it allows some plugins (e.g. Magic) to identify the MIME type
and other plugins (e.g. WhatLanguage) to identify the language.
=end
      def self.ident_data(data, filename)
        # Hash [ member => [rating, value] ] from idents
        ident_data = { :mime => [], :encoding => [], :language => [],
                       :summary => [], :full => [] }

        pmgr = PluginManager
        begin
          pmgr.providing(:ident, data, filename).each do |p, rating|
            # FIXME: log
            #$stderr.puts "[IDENT_DATA] Plugin: #{p.name}"
            ident = p.spec_invoke(:ident, data, filename)
            next if (! ident.recognized?)

            h = ident.to_h
            ident_data.keys.each do |key|
              old_rating = ident_data[key].first
              ident_data[key] = [rating, h[key]] if (h[key] && 
                                        (! old_rating || rating > old_rating))
            end
          end
        rescue Exception => e
          raise e
        end

        Ident.from_hash( ident_data.inject({}) {|h,(k,v)| h[k] = v.last; h} )
      end

=begin rdoc
Refresh a document in the repository. This is basically a non-destructive
import: Invokes fetch_and_mirror() to download current document contents. 
This updates the contents of the Document in the repo, and performs 
analyze_and_index when the contents are updated..

This is used to refresh the contents of a 'mirrored' document, e.g. a 
web page, filesystem document, etc.

Returns true if doc was refreshed (and written to repo), false if refresh 
failed.
=end
      def self.refresh_doc(doc)
        return if ! doc.origin

        # 1. Fetch new content
        buf = fetch_and_mirror(doc)
        return false if (! buf) || (buf.empty?)

        # 2. Set document contents. This will parse/analyze/tokenize/index.
        # FIXME: this should lock document
        doc.properties[Document::PROP_SYNCED] = Time.now
        if doc.properties[Document::PROP_SYNCMETH] == SYNC_APPEND
          doc.contents = [doc.contents, buf.join("\n")]
        else
          # Do not index if contents have not changed
          # FIXME: This should really be an MD5SUM
          return false if (doc.indexed?) and (buf == doc.fs_contents)
          # This will re-index
          doc.contents = buf
        end

        # TODO: doc status = ready
        true
      end

=begin rdoc
Run all :analyze_doc plugins on document. This will update ParsedDocument 
properties with the "best" [highest confidence rating] results of all plugins 
unless readonly is set to true.

Returns a Hash [ Plugin#name -> Analysis Results] containing the results of 
analysis.

The pdoc argument is expected to be a ParsedDocument object returned by a 
:parse_doc Plugin method. If pdoc is nil, the document will be parsed
automatically. Note that in this case, a ParseDocument will created and
discarded, along with all properties set after analysis.

If plugin_name is specified, that plugin will be run instead of all available
plugins.

The 'readonly' argument will prevent the 'pdoc' argument from being modified
with the analysis results.
=end
      def self.analyze_doc(doc, pdoc=nil, readonly=false, plugin_name=nil)
        unpack_doc(doc)
        pdoc ||= parse_doc(doc)
        results = {}
        h = {} #temporary hash for storing property + rating

        # Analyze document contents using all appropriate plugins
        plugins = plugin_name ? [[PluginManager.find(plugin_name), 100]] :
                                PluginManager.providing(:analyze_doc, pdoc)
        plugins.each do |p, rating|
          # FIXME: log
          #$stderr.puts "[ANALYZE_DOC] Plugin: #{p.name}"
          adoc = p.spec_invoke(:analyze_doc, pdoc)
          next if ! adoc

          # save analysis results as document properties
          adoc.keys.each do |key|
            old_rating = h[key] ? h[key].first : nil
            h[key] = [rating, adoc[key]] if ((! old_rating) || 
                                              rating > old_rating)
          end
          results[p.name] = adoc
        end

        # apply analysis results to parsed document
        # note that this will override parsed document properties
        h.each { |k,(r,v)| pdoc.properties[k] = v if ! pdoc.properties[k] 
               } if ! readonly

        results
      end

=begin rdoc
Run all :tokenize_doc plugins on document.

Returns a Hash [ Plugin#name -> TokenStream] containing the tokens produced by
each plugin.

The pdoc argument is expected to be a ParsedDocument object returned by a 
:parse_doc Plugin method. If pdoc is nil, the document will be parsed
automatically. 

The ar_hash argument is expected to be a Hash of AnalysisResults objects, 
as returned by analyze_doc. If ar_hash is nil, analyze_doc will be invoked.

If plugin_name is specified, that plugin will be run instead of all available
plugins.
=end
      def self.tokenize_doc(doc, pdoc=nil, ar_hash=nil, plugin_name=nil)
        pdoc ||= parse_doc(doc)
        ar_hash ||= analyze_doc(doc, pdoc)
        tok_docs = {}

        # Tokenize document contents using all available plugins
        plugins = plugin_name ? [[PluginManager.find(plugin_name), 100]] :
                           PluginManager.providing(:tokenize_doc, pdoc, ar_hash)
        plugins.each do |p, rating|
          # FIXME: log
          #$stderr.puts "[TOKENIZE_DOC] Plugin: #{p.name}"
          tdoc = p.spec_invoke(:tokenize_doc, pdoc, ar_hash)
          tok_docs[p.name] = tdoc if tdoc
        end
        tok_docs
      end

=begin rdoc
Run all :index_doc plugins on document.

The tok_hash argument is expected to be a Hash of TokenStream objects, 
as returned by tokenize_doc. If tok_hash is nil, tokenize_doc will be invoked.

If plugin_name is specified, that plugin will be run instead of all available
plugins.
=end
      def self.index_doc(doc, tok_hash, plugin_name=nil, force=false)
        return if (! doc.indexed?) and (! force)

        repo = doc.repo

        # Index document contents
        plugins = plugin_name ? [[PluginManager.find(plugin_name), 100]] :
                       PluginManager.providing(:index_doc, repo, doc, tok_hash)
        plugins.each do |p, rating|
          # FIXME: log
          #$stderr.puts "[INDEX_DOC] Plugin: #{p.name}"
          p.spec_invoke(:index_doc, repo, doc, tok_hash)
        end
      end

=begin rdoc
Parse, analyze and index a document.
=end
      def self.analyze_and_index_doc(doc)
        pdoc = parse_doc(doc)
        return if ! pdoc

        ar_hash = analyze_doc(doc, pdoc)
        tok_hash = tokenize_doc(doc, pdoc, ar_hash)

        # apply parsed document properties to document
        # NOTE: this must happen before indexing, as index might use properties
        props = doc.properties.to_h
        pdoc.properties.each { |k,v| props[k.to_sym] = v if ! props[k.to_sym] }
        doc.properties=props

        index_doc(doc, tok_hash)
        # TODO: doc status = ready
      end

      def self.transform_doc(doc, script_path, dest_path)
        # FIXME : REVIEW
        # TODO: how does this work w regular script action
        s = ScriptManager.script(doc.repo, script)
        output = d.exec(s, doc)
        # TODO: create output file if output != nil
      end

      # ----------------------------------------------------------------------
      # Repository Management

=begin rdoc
Iterate over docs in repo, invoking block on each. Returns a list of all 
documents if no block is given.
=end
      def self.docs(repo, &block)
        docs = [] if (! block_given?)
        # FIXME: return all 
        # TODO: sort by path?
        self.ls(repo, '/', true, false).each do |path|
          # FIXME: ctype should be available?
          doc = self.doc_factory(repo, path)
          next if (! doc)
          (block_given?) ? (yield doc) : (docs << doc)
        end
        (block_given?) ? docs : nil
      end

=begin rdoc
Update entire repository. This respects the :autorefresh property of Document
objects unless 'force' is set to true.
=end
      def self.update(repo, force=false)
        # FIXME : REVIEW
        docs(repo) do |doc| 
          next if (! doc.properties[Document::PROP_UPDATE]) && (! force)
          self.refresh_doc(doc)
        end
      end

=begin rdoc
Re-index entire repository. This respects the :no_index property of Document
objects unless 'force' is set to true.
=end
      def self.reindex(repo, force=false)
        docs(repo) do |doc|
          next if (! doc.indexed?) and (! force)
          analyze_and_index_doc(doc)
        end
      end

=begin rdoc
Export the specified repo contents using a plugin that supports the 
:export_contents specification.
'paths' is a single repo path or an array of repo paths to export.
'dest' is a string or an IO object (e.g. an open file or a StringIO object).
=end
      def self.export_archive(repo, paths, dest, plugin_name=nil, opts={})
        paths = [paths].flatten
        pmgr = PluginManager
        p = nil
        if (plugin_name and ! plugin_name.empty?)
          p = pmgr.find(plugin_name)
        else
          p = pmgr.fittest_providing(:export_contents, repo, paths, dest, opts)
        end
        p ? p.spec_invoke(:export_contents, repo, paths, dest, opts) : false
      end

=begin rdoc
Import the contents of an archive to the repo using a plugin that supports the 
:import_contents specification.
'archive' is a string or an IO object (e.g. an open file or a StringIO object).
'dest' is a single repo path which will be the parent of the imported items.
=end
      def self.import_archive(repo, archive, dest, plugin_name=nil, opts={})
        pmgr = PluginManager
        p = nil
        if (plugin__name and ! plugin_name.empty?)
          p = pmgr.find(plugin_name)
        else
          p = pmgr.fittest_providing(:import_contents, repo, archive, dest, 
                                     opts)
        end
        p ? p.spec_invoke(:import_contents, repo, archive, dest, opts) : false
      end

      # ----------------------------------------------------------------------
      # File Management

=begin rdoc
Returns a list of all document paths under 'path' in the repo. The list is
recursive if 'recursive' is true. If children_only is true, then the provided
path will be excluded form the results.
The block will be invoked for each path, if provided.
=end
      def self.ls(repo, path='/', recursive=false, children_only=false, 
                  keep_dirs=true, &block)
        nodes = lookup(repo, path, recursive, children_only, keep_dirs)
        entries = nodes.map { |arr| arr[1] }.sort.uniq
        entries.each { |p| yield p } if block_given?
        entries
      end

=begin rdoc
Returns an Array of pairs [content_type, path] for all document paths under
'path' in repo. This provides more detail than ls(), as the content type
is included, but the results are not sorted.
=end
      def self.lookup(repo, path='/', recursive=false, children_only=false,
                     keep_dirs = false)
        entries = repo.lookup(path, nil, recursive, true, keep_dirs)
        entries.reject! { |arr| arr[1] == path } if children_only
        # remove resources
        entries.reject! { |arr| arr[0] == :resource }
        # FIXME: sort by path
        entries
      end

=begin rdoc
Returns a recursive list of all document paths under 'path' in the repo. If
a block is provided, it is used to filter the results (via Enumberable#select).
=end
      def self.find(repo, path='/', &block)
        repo.find(path, &block)
      end

=begin rdoc
Returns a recursive list of all document paths under 'path' in the repo which
match the provided pattern. The pattern is a standard filename glob, where '?'
matches any single character and '*' matches any character (or none).
=end
      def self.glob(repo, pat, path='/')
        repo.glob(pat, path, &block)
      end


=begin rdoc
Move Document object to new path. Note that dest_path is a *full* path to 
the new document, not to the directory containing it.
=end
      def self.move(doc, dest_path, rescursive=false, replace=false)
        move_path(doc.repo, doc.path, dest_path, doc.node_type, recursive,
                  replace)
      end

=begin rdoc
Move a path in the Repository. Note that this operates on all node_types unless
ctype is specified.
=end
      def self.move_path(repo, from_path, to_path, ctype=nil, recursive=false,
                         replace=false)
        begin
          repo.move from_path, to_path, ctype, recursive, replace
        rescue Repo::NodeExists => e
          # FIXME : log
          $stderr.puts "Error in move #{from_path} -> #{to_path}"
          $stderr.puts e.message
        end
        # FIXME: is rebasing already handled by repo notification?
        # rebase_doc(doc)
        # NOTE: updating indexes is handled by repo notifications
      end

=begin rdoc
Copy Document object to new path. 
=end
      def self.copy(doc, dest_path, recursive=false, replace=false)
        copy_path( doc.repo, doc.path, dest_path, doc.node_type, recursive,
                   replace )
      end

=begin rdoc
Copy a path in the Repository. Note that this operates on all node_types unless
ctype is specified.
=end
      def self.copy_path(repo, from_path, to_path, ctype=nil, recursive=false,
                         replace=false)
        begin
          repo.copy from_path, to_path, ctype, recursive, replace
        rescue Repo::NodeExists => e
          # FIXME : log
          $stderr.puts "Error in copy #{from_path} -> #{to_path}"
          $stderr.puts e.message
        end
        # FIXME: is rebasing already handled by repo notification?
        # rebase_doc(dest_doc)
        # TODO: update indexes
        # index_doc(dest_doc)
        # TODO: must associate with resources!
        #       foreach doc.resources, repo.ref_resource dest_path, res_path
      end

=begin rdoc
Remove document from repository. Note that this does not remove child documents
by default.
=end
      def self.remove(doc, recursive=false)
        remove_path(doc.repo, doc.path, doc.node_type, recursive)
      end

=begin rdoc
Remove a path from Repository. Note that this operates on all node_types unless
ctype is specified.
=end
      def self.remove_path(repo, path, ctype=nil, recursive=false)
        begin
          repo.remove path, ctype, recursive
        rescue Repo::NodeExists => e
          # FIXME : log
          $stderr.puts "Error in remove #{path}"
          $stderr.puts e.message
        end
        # NOTE: removing from indexes is handled by repo hooks
      end

      private

      def self.repo_document(repo, path, ctype=:document)
        Document.factory(repo, path, ctype)
      end

    end
  end
end
