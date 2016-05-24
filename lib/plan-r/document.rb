#!/usr/bin/env ruby
# :title: PlanR::Document
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org> 
Note: Document and its subclasses provide wrappers around content-tree objects.
      This means that documents will wrap datatypes.
=end

require 'json'

module PlanR


  # ----------------------------------------------------------------------
  # DOCUMENT
=begin rdoc
Base class for Documents.

This is a handle for an in-repo document (for passing to plugins, via DnD, etc).
Note: An origin indicates an external document. Not all Documents have an 
      origin. All Documents must have a path. All Documents should have a 
      mime-type (default will be text/plain). All documents have a path.
=end
  class Document
    
    # ----------------------------------------------------------------------
    # STANDARD DOCUMENT PROPERTIES
    # -- information about document --
    PROP_NAME      = :name         # name of document (used if title is empty)
    PROP_ORIGIN    = :origin       # original URI of document
    PROP_HOME      = :home         # URI hosting document, if applicable
    PROP_TITLE     = :title        # title of document
    PROP_AUTHOR    = :author       # author of document
    PROP_LICENSE   = :license      # license of document (e.g. CC)
    PROP_VERSION   = :version      # version of document
    PROP_DESCR     = :description  # description or summary of doc
    PROP_SUBJECT   = :subject      # subject of doc (e.g. from PDF properties)
    PROP_COMMENT   = :comment      # Arbitrary comment
    PROP_KEYWORDS  = :keywords     # keywords defined in metadada
    PROP_SUMMARY   = :summary      # created by summarize plugin
    PROP_TOPICS    = :topics       # created by summarize plugin
    PROP_ABSTRACT  = :abstract     # abstract from research paper, if present
    PROP_MIME      = :mime_type    # Ident#mime
    PROP_ENCODING  = :encoding     # Ident#encoding
    PROP_CHARSET   = :charset      # Ident#encoding
    PROP_LANGUAGE  = :language     # Ident#language
    PROP_FILETYPE  = :file_type    # Ident#summary
    PROP_IDENT     = :ident        # Ident#full
    # -- synchronization options --
    PROP_SYNCPOL   = :sync_policy  # when to sync, e.g. SYNC_AUTO
    PROP_SYNCMETH  = :sync_method  # Append or Replace (usually replace)
    PROP_CACHE     = :cache        # Store document contents in repo
    PROP_INDEX     = :index        # Automatically index document
    PROP_AUTOTITLE = :autotitle    # Autotitle document after sync
    # -- plugins used by document --
    PROP_PARSER    = :plug_parser  # Name of plugin used to parse document
    PROP_DATASRC   = :plug_source  # Name of plugin used to retrieve document
    PROP_MIRROR    = :plug_mirror  # Name of plugin used to mirror document
    PROP_SYNTAX    = :plug_syntax  # Syntax family for highlighting
    PROP_VIEWER    = :plug_viewer  # Name of internal viewer plugin | 'external'
    PROP_EXTVIEW   = :ext_viewer   # External viewer
    # -- misc application bookeeping --
    PROP_CREATEAPP = :create_app   # Application used to create document
    PROP_CREATED   = :created      # date document was created in repo
    PROP_SYNCED    = :synced       # date document was last synced from origin
    PROP_MODIFIED  = :modified     # date document was last modified in repo

=begin rdoc
Invalid content supplied to contents= method of Document subclass.
=end
    class ContentError < RuntimeError; end

=begin rdoc
Document Property Hash.
Examples:
  # multiple settings
  p = doc.properties
  h = p.to_h
  h[:a] = 1; h[:b] = 2; h[:c] = 3
  p.apply_hash(h)
=end
    class PropertyHash < Hash
      attr_accessor :doc

      def initialize(doc)
        @doc = doc
        @write_disabled = false   # needed for apply_hash
        super()
        read
      end

=begin rdoc
Set a hash member. This writes the property file to disk.
=end
      def []=(*args)
        super
        write
      end

=begin rdoc
Delete a hash member. This writes the property file to disk.
=end
      def delete(*args)
        super
        write
      end

=begin rdoc
Apply contents of Hash to Properties object.
=end
      def apply_hash(h)
        @write_disabled = true
        h.each { |k,v| self[k] = v }
        @write_disabled = false
        write
      end

=begin rdoc
Convert to a normal Hash: []= will not write to disk.
=end
      def to_h
        Hash[self]
      end

      private
      # Read properties from Repo
      def read
        h = doc.repo.properties(doc.path, doc.node_type)
        replace(h) if h
      end

      # Write properties to repo
      def write
        return if @write_disabled
        doc.repo.add_metadata(doc.path, doc.node_type, to_h, :properties)
      end
    end

    EMPTY_DOC_TITLE = 'Empty document'  # Default title for an empty document

    attr_reader :repo             # PlanR Repository object
    attr_reader :node_type        # Content Tree node type
    attr_reader :path             # path of document in content-tree
    attr_reader :properties       # PropertyHash object of document properties

    @classes = [ self ]
    def self.inherited(cls)
      @classes << cls
    end

    def initialize(repo, path, ctype=:document)
      @notify = true  # by default, have repo send notifications
      @repo = repo
      @path = path
      @node_type = ctype
      @properties = PropertyHash.new(self)
      @cached_contents = nil # in-memory cache of contents
    end

=begin rdoc
A unique identifier for the document within the Repo.
This just prefixes the repo path with the node_type.
=end
    def id
      [node_type.to_s, path].join ':'
    end

    def self.node_type
      :document
    end

    def self.default_properties
      {
        PROP_SYNCPOL   => PlanR::Application::DocumentManager::SYNC_AUTO,
        PROP_SYNCMETH  => PlanR::Application::DocumentManager::SYNC_REPLACE,
        PROP_CACHE     => true,
        PROP_INDEX     => true,
        PROP_VERSION   => 1.0,
        PROP_AUTOTITLE => false
      }
    end

=begin rdoc
Return a Document (or child class) instance for the document in the repo
at the specified path of the specified node-type.
=end
    def self.factory(repo, path, ctype=:document)
      return nil if (! repo.exist?(path, ctype))
      cls = class_for(ctype)
      cls ? cls.new(repo, path) : self.new(repo, path, ctype)
    end

=begin rdoc
Return Document class or child class for the specified node type.
=end
    def self.class_for(ctype)
      @classes.select { |c| c.node_type == ctype }.first
    end

=begin rdoc
Create a document in the repository.
=end
    def self.create(repo, path, ctype=nil, contents=nil, props=nil)
      ctype ||= self.node_type
      # NOTE : this calls create_raw in the subclass context, which means
      #        node_type(), new() will be from the subclass (not Document)
      cls = @classes.select { |c| c.node_type == ctype }.first
      cls ? cls.create_raw(repo, path, contents, 
                           (props || cls.default_properties)) : nil
      # FIXME: Generate InternalDocument if class not found?
      #doc = InternalDocument.create(repo, ctype, path, contents, props)
    end

=begin rdoc
Create a Document object (e.g. from a plugin) in the Repo.
=end
    def self.create_doc(repo, path, doc)
      # this is basically Repo.copy (i.e. clone doc), only doc isn't on fs
      cls = @classes.select { |c| c.node_type == doc.node_type }.first || self
      create_raw(repo, path, doc.contents, doc.properties)
    end

=begin rdoc
Create a document in the repository *without* invoking create_raw. This does
not set the contents.
=end
    def self.create_simple(repo, path, ctype, props=nil)
      # FIXME: REVIEW (obsolete?)
      cls = @classes.select { |c| c.node_type == ctype }.first
      doc = cls ? cls.new(repo, path) : nil
      props ||= {}
      doc.properties.apply_hash(props) if doc
    end

=begin rdoc
Create a new document. This is a backend method invoked by create().

It is recommended that the caller set the following properties (in order
of importance):
  :title
  :origin
  :mime_type
  :encoding
  :charset

None of these are mandatory.

Note that :origin should be NULL unless the document is expected to be
regenerated. For example, a document created via plaintext drag-and-drop
could have a NULL origin, while a document created by running a script
would have a descriptor (for the script) as its origin.
=end
    def self.create_raw(repo, path, buf=nil, props=nil)
      props ||= {}
      # Ensure document title is not blank
      props[PROP_TITLE] ||= props[PROP_AUTOTITLE] ? default_title(buf) : 
                                                    File.basename(path)
      # 1. Create a new document
      doc = self.new(repo, path)
      return nil if ! doc
      doc.properties.apply_hash(props)
      # 3. Set contents (& parse, analysis, tokenize and index)
      doc.contents = buf
      doc
    end

=begin rdoc
Return the first line of the contents or 'Empty document' if empty.
=end
    def self.default_title(contents)
      title = contents ? contents.lines.first : ''
      title.strip! if title
      (title && title.empty?) ? EMPTY_DOC_TITLE : title 
    end

=begin rdoc
Note: Every imported document has an origin
=end
    def self.import(repo, path, origin, opts)
      raise 'Importing requires an origin' if (! origin) || (origin.empty?)

      # 1. Create a new Document
      doc = self.new(repo, path)
      doc.origin = (File.exist? origin) ? File.expand_path(origin) : origin
      doc.set_sync_options(opts) 

      # 2. Download/read and fill document contents
      doc.disable_notifications
      doc.regenerate
      if ( opts and  opts.orphan)
        # NOTE: origin is needed for 'regenerate', so is removed here
        doc.origin = ''
      end
      doc.enable_notifications
      
      doc
    end

    def disable_notifications
      @notify = false
    end

    def enable_notifications
      @notify = true
    end

=begin rdoc
Regenerate document contents, then re-analyze.

Note: this is a no-op if doc has no origin
=end
    def regenerate
      Application::DocumentManager.refresh_doc(self)
    end

=begin rdoc
Explicit request to create a document revision.
This will send out an EVENT_REV notification for the Document.
=end
    def add_revision(msg=nil)
      # FIXME: REVIEW
      msg ||= "Revision #{Time.now.strftime('REV %Y.%m.%d-%H:%M')}"
      repo.add_revision(path, msg)
    end

    # ----------------------------------------------------------------------
    # PROPERTIES

=begin rdoc
Set sync properties from a DocumentManager::SyncOptions object
=end
    def set_sync_options(opts)
      @properties.apply_hash(opts.to_prop_h) if opts
    end

=begin rdoc
Return true if document should be indexed.
=end
    def indexed?
      # NOTE: default behavior is not to index
      @properties[PROP_INDEX]
    end

=begin rdoc
Return true if document should be cached locally.
=end
    def cached?
      # NOTE: default behavior is to cache
      (! @properties.include? PROP_CACHE) or (@properties[PROP_CACHE])
    end

=begin rdoc
Original location of document -- where it was imported into the Repo from.
This is usually an absolute path or a URI.
It will be nil for documents that were not imported or that were orphaned.
=end
    def origin
      str = @properties[PROP_ORIGIN]
      ((str || '').empty?) ? nil : str
    end

    def origin=(str)
      @properties[PROP_ORIGIN] = str
    end

=begin rdoc
Document title. This is what is displayed in user interfaces and such.
The default title is the filename.
=end
    def title
      @properties[PROP_TITLE]
    end

    def title=(str)
      @properties[PROP_TITLE] = str
    end

=begin rdoc
Document mime-type.
=end
    def mime_type
      @properties[PROP_MIME]
    end

=begin rdoc
Return absolute path to document. This can be passed to File.open.
=end
    def abs_path
      repo.abs_path path, node_type
    end

=begin rdoc
Return true if the Document has children. Note that this means Documents
which exist as subdirectories of this Document, not Documents at the same
level (e.g. different Document types sharing the same name).
=end
    def has_children?
      repo.has_children? path
    end

=begin rdoc
Return list of child content nodes for Document
=end
    def children
      repo.children path
    end

=begin rdoc
Return list of content nodes with same parent as Document
=end
    def siblings
      repo.siblings path
    end

=begin rdoc
Return list of all content nodes with same path as Document (referred to in 
the documentation as "attachments".
=end
    def twins
      repo.twins path
    end

=begin rdoc
The original contents of the document
=end
    def contents
      Application::DocumentManager.refresh_doc(self) if \
        @properties[PROP_SYNCPOL] == Application::DocumentManager::SYNC_ACCESS
      # FIXME: wait for job to finish
      @cached_contents ||= fs_contents
    end

=begin rdoc
Return the raw contents of the file on disk. This will not refresh the
document, and it will not deserialize from JSON.
=end
    def raw_contents
      repo.raw_content(path, node_type)
    end

=begin rdoc
Return contents on-disk
=end
    def fs_contents
      repo.content(path, node_type)
    end

    # TODO: add MD5sum or SHA

=begin rdoc
Set the contents of the Document. This causes a re-analysis and re-index.
=end
    def contents=(buf)
      @cached_contents = buf
      if ( cached? )
        # write to disk
        repo.add(path, buf, node_type)
        repo.notify(Repo::EVENT_UPDATE, path) if @notify
      end

      @properties[PROP_MODIFIED] = Time.now

      if (indexed?) and buf and (! buf.empty?)
        # parse, analyze, tokenize, index
        # FIXME: this should lock document
        Application::DocumentManager.analyze_and_index_doc(self) 
        repo.notify(Repo::EVENT_INDEX, path) if @notify
      end
    end

=begin rdoc
Raise ContentError. Invoke this in contents= if obj is not the right type.
=end
    def invalid_content!(obj)
      raise ContentError, 
            "Invalid content '#{obj.class.name}' for #{self.class.name}"
    end

=begin rdoc
Return a Hash [ String -> String ] of mime data for this document. This
maps mime-type strings to raw data.

NOT IMPLEMENTED
    def mime_data
      # TODO : Generate mime data
      {}
    end
=end

=begin rdoc
Return Ident object for document.
This uses document properties to fill the Ident.
=end
    def ident
      return @ident if @ident
      h = properties.to_h
      @ident ||= PlanR::Ident.from_hash( { :mime => h[PROP_MIME],
                                           :encoding => h[PROP_ENCODING],
                                           :language => h[PROP_LANGUAGE],
                                           :charset => h[PROP_CHARSET],
                                           :summary => h[PROP_FILETYPE],
                                           :full => h[PROP_IDENT]
                                          } )
    end

=begin rdoc
Set Document properties based on the contents of an Ident object.
This sets the following properties:
      :mime_type
      :encoding
      :charset
      :language
      :file_type (Ident#summary)
      :ident (Ident#full)
=end
    def ident=(obj)
      @ident = obj
      prop = properties.to_h
      prop[PROP_MIME] = obj.mime
      prop[PROP_ENCODING] = obj.encoding
      prop[PROP_CHARSET] = obj.encoding
      prop[PROP_LANGUAGE] = obj.language
      prop[PROP_FILETYPE] = obj.summary
      prop[PROP_IDENT] = obj.full
      self.properties = prop
    end

    # ----------------------------------------------------------------------
    # ATTRIBUTES

    # FIXME: Need something more maintainable than this
    LOCAL_URI_SCHEMES = ['file', 'script', 'query']

=begin rdoc
Returns true if document was imported from a remote location.
This performs a URI.parse on the Document origin to determine locality.
=end
    def is_remote?
      begin
        scheme = URI.parse(self.origin).scheme
        scheme and (! (LOCAL_URI_SCHEMES.include? scheme.downcase))
      rescue URI::InvalidURIError
        false
      end
    end 

=begin rdoc
Return true if document contents are binary.
=end
    def binary?
      enc = properties[PROP_ENCODING]
      (enc and (! enc.empty?)) ? (enc.downcase == 'binary') : (! self.ascii?)
    end

=begin rdoc
Return true if document contents are *not* binary.
=end
    def text?
      (! binary?)
    end

=begin rdoc
Return true if document contents are ASCII.
This uses the document PROP_ENCODING property. If that is not set, the
raw_contents must consist only of bytes in the range 0x09 - 0x7E.
=end
    def ascii?
      enc = properties[PROP_ENCODING]
      if (enc and (! enc.empty?)) 
        return enc.downcase.end_with? 'ascii'
      end
      # use regex to determine if this is proper ASCII.
      raw_contents =~ /^[\x09-\x7E]*$/
    end

    # ----------------------------------------------------------------------
    # METADATA TREES

=begin rdoc
List of Tag symbols for document.
=end
    def tags
      @tags ||= repo.tags(path, node_type)
    end

    def tags=(arr)
      @tags = arr
      repo.set_tags(path, node_type, arr)
    end

=begin rdoc
Add document tag.
=end
    def tag(str)
      repo.tag(path, node_type, str)
    end

=begin rdoc
Remove document tag.
=end
    def untag(str)
      repo.untag(path, node_type, str)
    end

=begin rdoc
Fill properties with contents of Hash.
=end
    def properties=(h)
      @properties.apply_hash(h)
    end

=begin rdoc
Set a document resource (e.g. an image or stylesheet)
Note that 'res_path' is the (future) path to the resource relative to the 
resources directory.
If 'props' is specified it will be used to set :properties metadata for the 
resource.
=end
    def set_resource(the_path, data, props=nil)
      repo.add_resource(self.path, the_path, data, props)
    end

=begin rdoc
Resources (icons, etc) used by document. This relies on the :resources
property set by add_resource.
=end
    def resources
      repo.doc_resources self.path
    end

    # ----------------------------------------------------------------------
    # MODIFY-AND-SAVE API         # not sure if this will be useful

=begin rdoc
Modify a document without saving it to disk. this initiates an in-memory 
modification. The document contents are passed to the block for modification.
Note: The modifcations will not be written to disk until save() is called. In
addition, the modified contents are not available via the contents() method.
See modified_contents().
=end
    def modify(&block)
      # FIXME: review
      @modified_contents ||= contents
      @modified_contents = yield @modified_contents if block_given?
    end

=begin rdoc
Append str to in-memory version of document contents.
=end
    def append(str)
      modify { |text| text + str }
    end

=begin rdoc
Write modified document contents to repo.
=end
    def save
      return if ! @modified_contents
      contents = @modified_contents
      discard
    end

    def discard
      @modified_contents = nil
    end

    def modified?
      @modified_contents != nil
    end

    def modified_contents
      @modified_contents || nil
    end

  end
end

# ----------------------------------------------------------------------
# DEPENDENCIES

require 'plan-r/application/document_mgr' # ensure doc_mgr is loaded
require 'plan-r/datatype/ident'           # ident datatype is needed @ runtime

Dir.foreach(File.join(File.dirname(__FILE__), 'document')) do |f|
  require "plan-r/document/#{f}" if (f.end_with? '.rb')
end

