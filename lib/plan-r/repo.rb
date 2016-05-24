#!/usr/bin/env ruby
# :title: PlanR::Repo
=begin rdoc
A Plan-R Content Repository.
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

Note that applications should use Application::RepoManager to open and
close Repos instead of accessing the Repo class directly. This will
notify Services that a Repo has been loaded or unloaded, and allow them
to subscribe to Repository notifications.

Example:
  r = PlanR::Application::RepoManager.open(path)
  raise "Unable to open repo at '#{path}'" if ! r
  # ... manipulate Repo here ...
  PlanR::Application::RepoManager.close(r)

Note: If repo has been opened by RepoManager, then Repo#close
can be called directly. For example:
  r = PlanR::Application::RepoManager.open(path)
  # ... modifications to Repo ...
  r.save
  # ... more modifications to Repo ...
  r.close

 NOTE: Content trees will use fs_path and fs_path_rel to return a path to
       an object on disk based on its "repo path". Metadata trees use 
       this path to store metadata for a content object.
=end

require 'plan-r/content_repo'
require 'plan-r/version'

require 'fileutils'
require 'json'

module PlanR

=begin rdoc
A PlanR Repo.
This consists of metadata and a content tree.
=end
  class Repo

      # Event notifications                :  ARG   Description 
      EVENT_ADD    = :notify_add           # (path, t) doc added to Repo
      EVENT_CLONE  = :notify_clone         # (path, t, path) doc copied in Repo
      EVENT_REMOVE = :notify_remove        # (path, t) doc removed from Repo
      EVENT_UPDATE = :notify_update        # (path, t) doc contents changed
      EVENT_REV    = :notify_revision      # (path, t, msg) doc revision change
      EVENT_INDEX  = :notify_indexed       # (path, t) doc (re-)indexed
      EVENT_PROPS  = :notify_prop_change   # (path, t) doc properties changed
      EVENT_TAG    = :notify_tag_change    # (path, t) doc tags changed
      EVENT_META   = :notify_meta_change   # (path, t, mt) doc metadata changed
      EVENT_SAVE   = :notify_save          # (repo) Repo save request
      EVENT_CLOSE  = :notify_close         # (repo) Repo is being closed

=begin rdoc
Name of repo.
=end
      attr_reader :name                    
=begin rdoc
Description of repo. Can be blank.
=end
      attr_reader :description             
=begin rdoc
Timestamp when repo was created.
=end
      attr_reader :created                 
=begin rdoc
absolute path to Repo /
=end
      attr_reader :base_path               
=begin rdoc
ContentTree object
=end
      attr_reader :content_tree            
=begin rdoc
MetadataTree object
=end
      attr_reader :metadata_tree           
    
=begin rdoc
Properties Hash for repo.
This allows plugins and such to set additional repo properties.
=end
    attr_reader :repo_properties

=begin rdoc
Configuration for repo.
Note: this does not save settings!
=end
    attr_reader :config

=begin rdoc
Directory for runtime and other tmp files
=end
    RUNTIME_DIR='var'
=begin rdoc
Directory for repo-specific settings
=end
    CONFIG_DIR='settings'

=begin rdoc
File containing Repo properties.
=end
    PROP_FILE = 'repo.properties.json'

    CONFIG_FILE='repo.yaml'
    DEFAULT_CONFIG_FILE = File.join(File.dirname(__FILE__), 'conf', CONFIG_FILE)

    CONFIG_DOMAIN = 'plan-r-repo'

    # these should probably be pulled from ContentNode classes
    DEFAULT_CTYPE=:document
    DEFAULT_MTYPE=:properties

    # ----------------------------------------------------------------------
    # EXCEPTIONS
    class NodeExists < RuntimeError; end

    # ----------------------------------------------------------------------

=begin rdoc
Return an instance of the Repo at path.
=end
    def self.factory(path)
      self.new(path)
    end

=begin rdoc
Returns true if 'path' is a Plan-R repo.
=end
    def self.is_repo?(path)
      File.exist?(File.join(path, PROP_FILE))
    end

=begin rdoc
Return an instance of a Repo. This reads in the repo metadata and 
initializes the Content Repository.
=end
    def initialize(base_path)
      @base_path = base_path
      @full_path = File.expand_path(base_path)
      read_properties

      # these should run before subscribers are signed up
      load_content_tree
      load_metadata_tree

      @subscribers = {}
    end

=begin rdoc
Create a new repo. This names the repo and initializes a repo
directory.
=end
    def self.create(name, path, properties={}, config_file=DEFAULT_CONFIG_FILE)
      FileUtils.mkdir_p(path) if (! File.exist? path)

      if (! File.directory? path)
        raise "Not a valid repo directory: #{path}"
      end

      properties[:name] = name
      properties[:created] = Time.now
      properties[:create_path] = path
      properties[:create_version] = PlanR::VERSION
      properties[:startup_sync] = []

      # create properties file ($PROJ/properties)
      File.open(File.join(path, PROP_FILE), 'w') do |f|
        f.write( properties.to_json )
      end

      # create runtime data directory ($PROJ/var) and config directory
      Dir.mkdir(File.join(path, RUNTIME_DIR))
      cfg_path = File.join(path, CONFIG_DIR)
      Dir.mkdir(cfg_path)

      # NOTE: application is responsible for allowing user to override
      #       the default config file
      if (File.exist? config_file)
        FileUtils.cp(config_file, File.join(cfg_path, CONFIG_FILE))
      end

      factory(path)
    end

    # ----------------------------------------------------------------------
    # REPO MANAGEMENT

=begin rdoc
Save Repo.
Notify subscribers that a Repo save-to-disk has been requested.
This will send an EVENT_SAVE notification to all subscribers, with the
Repo object as the Notification argument.
=end
    def save
      write_properties
      notify(EVENT_SAVE, self)
    end

=begin rdoc
Close Repo. 
Notify subscribers that Repo is being closed. This gives subscribers
a chance to write state to disk and so forth.
This will send an EVENT_CLOSE notification to all subscribers, with the
Repo object as the Notification argument.
=end
    def close(autosave=false)
      save if autosave
      notify(EVENT_CLOSE, self)
    end

=begin rdoc
Read config using config manager.
NOTE: Other services (e.g. PluginManager) whose configuration can change on a
per-repo basis must hook object_loaded() and read repo.config there.
=end
    def read_config(mgr)
      @config = mgr.read_config_file( File.join(cfg_dir, CONFIG_FILE),
                                      CONFIG_DOMAIN )
    end

=begin rdoc
Set name for repo.
=end
    def name=(str)
      @name = str
      write_properties
    end

=begin rdoc
Set description for repo.
=end
    def description=(str)
      @description = str
      write_properties
    end

=begin rdoc
Return the absolute path to the runtime/tmp directory for Repo
=end
    def runtime_dir
      File.join(@full_path, RUNTIME_DIR)
    end

=begin rdoc
Return the absolute path to the settings directory for Repo
=end
    def cfg_dir
      File.join(@full_path, CONFIG_DIR)
    end

=begin rdoc
Make a directory off the repo base, outside of the content and metadata trees.
Returns directory appened to repo base.
=end
    def mk_repo_dir(path)
      dir_path = File.join(@full_path, path)
      return dir_path if (File.exist?dir_path) and (File.directory? dir_path)
      FileUtils.mkdir_p(dir_path)
      dir_path
    end

=begin rdoc
Log a message to runtime dir.
=end
    def log(msg)
      File.open(File.join(runtime_dir, 'content-repo.log'), 'w+') { |f| 
        f.puts msg }
    end

    # ----------------------------------------------------------------------
    # NOTIFICATIONS
    
=begin rdoc
Subscribe to notification. Block receives |event, obj| where 'event' is the
event type (e.g. EVENT_ADD) and 'obj' is the event argument (usually the
path of the Document being modified).
=end
    def subscribe(cls, &block)
      @subscribers[cls.name] = block
    end

=begin rdoc
Unsubscribe from notifications.
=end
    def unsubscribe(cls)
      @subscribers.delete(name)
    end

=begin rdoc
Notify subscribers that an event has happened. The args are defined by the
event type.
=end
    def notify( event, *args )
      @subscribers.values.each { |b| b.call(event, *args) }
    end


    # ----------------------------------------------------------------------
    # CONTENT

=begin rdoc
Return a list of document types suitable for passing to content methods.
NOTE: This returns the KEY constant of the ContentRepo::Node classes.
=end
    def content_types(meta=false)
      content_type_classes(meta).map { |cls| cls.key }
    end

=begin rdoc
Return a list of classes which represent content types. This can be used to
get more information about content types than just the KEY constant.
=end
    def content_type_classes(meta=false)
      (meta ? @metadata_tree.node_types : @content_tree.node_types).dup
    end

=begin rdoc
Recursively import directory into repo.
=end
    def import(path, dest_path='')
      # FIXME : implement
      raise("not implemented")
      # if URI ...
    end

=begin rdoc
Add a node to a content data tree.
This sends an EVENT_ADD notification to all subscribers with 'path' as the
notification argument.
  path: path in repo. if exists, ...?
  data: raw data to add
  type: node content type
=end
    def add(path, data, ctype=DEFAULT_CTYPE)
      # FIXME: determine if ADD or UPDATE EVENT
      # evt = File.exist? @content_tree.node_path(path)
      # FIXME: should this always be create-or-update? what about replace=false?
      n = @content_tree.add(path, data, ctype)
      notify(EVENT_ADD, path, ctype)
      n
    end

=begin rdoc
Add a directory to the repository. This performs a mkdir in the content tree.
=end
    def mkdir(path, metadata=false)
      # FIXME: does metadata mkdir even make sense?
      metadata ? @metadata_tree.mkdir(path) : @content_tree.mkdir(path)
    end

=begin rdoc
Duplicate a node in a content tree to a new location. This also copies all 
metadata associated with the node.
Note: This only effects the Repository. All application-level data associated
with the node, such as search indexes, must be updated separately.
If ctype is specified, only nodes of that ctype will be moved. When used with
recursive=true, this will copy the subtree of nodes meeting that type.
If to_path ends in '/', contents of from_path will be copied *into* to_path 
(i.e. into a directory); otherwise, contents will be copied *to* to_path 
(i.e. to a new filename).
Will raise NodeExists if replace is false and an existing node would be
overwritten.
=end
    def copy(from_path, to_path, ctype=nil, recursive=false, replace=false)
      if to_path.end_with? '/'
        # copy into to_path, not to to_path
        to_path = File.join(to_path, File.basename(from_path))
      end

      count = 0
      prune = recursive ? nil : 1
      @content_tree.with_subtree(from_path, ctype, prune) do |node|
        ntype = node.node_type
        basename = node.path.split(from_path, 2)[1]
        dest = basename.empty? ? to_path : File.join(to_path, basename)
        if (! replace) and (@content_tree.exist? dest, ntype)
          raise NodeExists, "'#{dest}' exists [#{ntype}]"
        end
        new_node = @content_tree.clone(node, dest)
        copy_doc_resources(from_path, to_path) if ntype == :document
        copy_metadata(node.path, dest, ntype)
        notify(EVENT_CLONE, node.path, ctype, dest)
        count += 1
      end

      count
    end

=begin rdoc
Recursively copy.
This invokes copy with recursive set to true, and ctype set to nil.
This is what most uses want from a copy operation.
=end
    def cp(from_path, to_path, replace=false)
      copy(from_path, to_path, nil, true, replace)
    end

    def cp!(from_path, to_path)
      copy(from_path, to_path, nil, true, true)
    end

=begin rdoc
Move a node in a content tree. This also moves all metadata associated with the
node.
Note: This only effects the Repository. All application-level data associated
with the node, such as search indexes, must be updated separately.
Will raise NodeExists if replace is false and an existing node would be
overwritten.
=end
    def move(from_path, to_path, ctype=nil, recursive=false, replace=false)
       copy(from_path, to_path, ctype, recursive, replace)
       remove(from_path, ctype, recursive)
    end

=begin rdoc
Recursively move.
This invokes move with recursive set to true, and ctype set to nil.
This is what most uses want from a move operation.
=end
    def mv(from_path, to_path, replace=false)
      move(from_path, to_path, nil, true, replace)
    end

    def mv!(from_path, to_path)
      move(from_path, to_path, nil, true, true)
    end

=begin rdoc
Delete a node from a content data tree.

This sends an EVENT_REMOVE notification to all subscribers with 'path' as the
notification argument.

Note: ctype argument is required. If nil, all content types for path will be
removed.
Returns count of nodes removed.
=end
    def remove(path, ctype, recursive=false, preserve_metadata=false)
      prune = recursive ? nil : 1
      count = 0
      nodes = @content_tree.subtree(path, ctype, prune)
      # NOTE: delete children first, hence the reverse()
      nodes.reverse.each do |node|
        ntype = node.node_type
        # first remove all files, then remove directories
        next if (node.kind_of? ContentRepo::DirNode)
        @content_tree.remove_node(node)
        remove_doc_resources(from_path, to_path) if ntype == :document
        remove_metadata(node.path, ntype, nil) unless preserve_metadata
        notify(EVENT_REMOVE, path, ctype)
        count += 1
      end

      # Remove all empty directories under path
      content_tree.remove_empty_dirs(path)
      metadata_tree.remove_empty_dirs(path)

      count
    end

=begin rdoc
Recursively delete.
This invokes remove with recursive set to true, and ctype set to nil.
This is what most uses want from a delete operation.
=end
    def rm(path)
      remove(path, nil, true, false)
    end


=begin rdoc
Return true if an item exists for path in content tree. 
If 'ctype' is specified, then this returns true only if that document type
exists; otherwise, this returns true if any document type exists. This will
return false if path  not a document node (i.e., is a DirNode).
=end
    def exist?(path, ctype=nil)
      @content_tree.exist? path, ctype
    end

=begin rdoc
Return true if path exists in content tree.
Note: a value of 'true' does not indicate that a valid document item exists. 
This is a low-level call for repo management.
=end
    def path_exist?(path)
      @content_tree.path_exist? path
    end

=begin rdoc
Returns true if path exists and is a directory.
=end
    def is_directory?(path)
      path_exist(path) and (! exist? path)
    end

=begin rdoc
Return true if path exists and has children in the content tree.
Note: a value of 'true' could indicate a document or a directory node.
=end
    def has_children?(path)
      return false if (! path_exist? path)
      # prune at level 2 (direct children) and ignore the  hit for self
      @content_tree.subtree(path, nil, 2, true).count > 1
    end

=begin rdoc
List the path of an item and its children in content tree.
=end
    def list(path, recursive=true, dirs=false)
      # TODO : this might need to be changed as it returns dir and contents
      #        if there are contents
      nodes = []
      prune = recursive ? nil : 2
      @content_tree.with_subtree(path, nil, prune, dirs) do |node|
        nodes << node.path
      end
      nodes.sort.uniq
    end

=begin rdoc
List immediate children of path. This just calls list with recursive set to 
false and dirs set to true.
=end
    def ls(path)
      # FIXME: remove 'path' from listing?
      list(path, false, true)
    end

=begin rdoc
Returns an array of pairs [key, node] of all content tree nodes for path. If
recursive is true, then subdirectories will be recursed. If path_only is true
then the path is returned instead of the node object.

Note: lookup returns a Hash of objects at the specified path. 
list returns the paths under a specified path. 

'dirs' : keep directory (even empty directory) nodes in listing.

See Also: metadata_lookup
=end
    def lookup(path, ctype=nil, recursive=false, path_only=true, dirs=false)
      # TODO : this might need to be changed as it returns dir and contents
      #        if there are contents
      entries = []
      prune = recursive ? nil : 2
      @content_tree.with_subtree(path, ctype, prune, dirs) do |node|
        entries << [node.node_type, (path_only ? node.path : node)]
      end
      entries
    end

=begin rdoc
Return node for parent of specified path. Returns nil if path is '/'.
=end
    def parent(path)
      return nil if (path.strip.empty?) or (path == '/')
      p_path = File.dirname(path)
      nodes = lookup(p_path, nil, false, false, true)
      pair = nodes.select{ |p| p[0] == :document }.first
      pair ||= nodes.first
      pair.last
    end

=begin rdoc
Return list of child nodes for specified path.
=end
    def children(path)
      entries = []
      @content_tree.with_subtree(path, nil, 2, true) do |node|
        next if node.path == path
        entries << node
      end
      entries
    end

=begin rdoc
Return list of nodes with same parent as specified path.
=end
    def siblings(path)
      p_node = parent(path)
      p_node ? children(p_node.path) : []
    end

=begin rdoc
Return list of nodes of any type at specified path
=end
    def twins(path)
      lookup(path, nil, false, false, false)
    end


=begin rdoc
Return the absolute path to the contents of a node on disk.
=end
    def abs_path(path, ctype=:document)
      node = @content_tree.lookup(path, ctype)
      node ? node.doc_path : nil
    end

=begin rdoc
Return an array of all data file paths in the content tree under path.
Note that this is recursive, so calling it on / will return all data
files in the content tree.
=end
    def content_paths(path)
      arr = []
      @content_tree.with_subtree(path, nil, nil) do |node|
        arr << node.doc_path
      end
      arr
    end

=begin rdoc
Return an array of all data file paths in the metadata tree under path.
Note that this is recursive, so calling it on / will return all data
files in the metadata tree.
=end
    def metadata_paths(path)
      arr = []
      @metadata_tree.with_subtree(path, nil, nil, nil) do |node|
        arr << node.doc_path
      end
      arr
    end

=begin rdoc
Return list of items under 'path' in the repo. The list of items is recursive.
If a block is provided, it is used to filter (via Enumerable#select) paths to 
return.
=end
    def find(path='/', &block)
      results = list(path, true)
      return (block_given?) ? results.select(&block) : results
    end

=begin rdoc
Return a list of all items under 'path' in the repo whose filenames patch the
provided pattern. The pattern can be a standard path glob, with ? as a single
wildcard character and * as a multiple wildcard character.
=end
    def glob(pat, path='/')
      # FIXME : implement
      raise('not implemented')
      # FIXME: verify and update
      # FIXME: test
      #regex = /^#{pat.gsub('*','.*').gsub('?','.?')}$/  
      #find(path) { |fname| fname =~ regex }
    end

=begin rdoc
Returns the content of a node the content tree.
=end
    def content(path, ctype=DEFAULT_CTYPE)
      node = @content_tree.lookup(path, ctype)
      node ? node.contents : ''
    end

=begin rdoc
Returns the raw content of the node on-disk (e.g. no JSON deserialization).
=end
    def raw_content(path, ctype=DEFAULT_CTYPE)
      node = @content_tree.lookup(path, ctype)
      node ? node.raw_contents : ''
    end

=begin rdoc
Explicitly create a revision for path. 
This will send an EVENT_REV notification to all subscribers (e.g. 
RevisionControlManager) with 'path' and 'msg' (a user-provided string to
associate with the revision).
=end
    def add_revision(path, ctype, msg)
      # FIXME: implement
      raise('not implemented')
      notify(EVENT_REV, path, ctype, msg)
    end

    # -- RESOURCES --
    
=begin rdoc
Add a resource to the Resource tree. 
Properties can be used to track origin of resources and such.
=end
    def add_resource(doc_path, res_path, data, props=nil)
      n = @content_tree.add_resource(doc_path, res_path, data)
       
      if props and (! props.empty?)
        add_metadata(resource_meta_path(doc_path, res_path), :resource, 
                     props, :properties)
      end
      n
    end

=begin rdoc
Return the contents of resource at 'res_path' in document 'doc_path'. 
=end
    def resource(doc_path, res_path)
      n = @content_tree.resource(doc_path, res_path)
      n ? n.contents : nil
    end

    def resource_meta_path(doc_path, res_path)
      File.join(doc_path, 'resource', res_path)
    end

    def resource_properties(doc_res_path)
      node = metadata(resource_meta_path(doc_path, res_path), :resource
                     )[:properties]
      node ? node.contents : @metadata_tree.default_data(:properties)
    end

=begin rdoc
Return Array of resources associated with 'path' in repository. Each entry
in the Array is a resource path.
Example:

  res = repo.doc_resources('/www_root/index.html')
  res.each do |res_path|
    data = resource('/www_root/index.html', res_path)
    # display data
  end
=end
    def doc_resources(path, &block)
      res = @content_tree.resources(path)
      block.call(res) if block_given?
      res
    end


=begin rdoc
Copy resources for a document. This is generally invoked only by Repo#copy.
=end

    def copy_doc_resources(from_path, to_path)
      count = 0
      doc_resources(from_path).each do |res_path|
        data = resource(from_path, res_path)
        add_resource(to_path, res_path, data, props)
        copy_metadata(resource_meta_path(from_path, res_path), 
                      resource_meta_path(to_path, res_path), :resource )
        count += 1
      end
      count
    end

=begin rdoc
Remove all resources for document from the Resource tree.
=end
    def remove_doc_resources(path)
      count = 0
      doc_resources(path).each do |res_path|
        remove_resource(path, res_path)
        count += 1
      end
      count
    end

=begin rdoc
Remove a resource from the Resource tree.
=end
    def remove_resource(doc_path, res_path)
      @content_tree.remove_resource(doc_path, res_path)
      remove_metadata(resource_meta_path(doc_path, res_path), :resource)
    end


    # ----------------------------------------------------------------------
    # METADATA

=begin rdoc
Add a node to a metadata tree.
Note that 'path' and 'content_tree' refer to the ContentTree node that
tnis is metadata for.
=end
    def add_metadata(path, ctype, data, mtype)
      n = @metadata_tree.add(path, ctype, data, mtype)
      notify(EVENT_META, path, ctype, mtype)
      n
    end

=begin rdoc
Move metadata for a node in a content tree. This moves all metadata associated 
with the node.
Note: This only effects the Repository. All application-level data associated
with the node, such as search indexes, must be update separately.
=end
    def move_metadata(from_path, to_path, ctype=nil, mtype=nil)
      copy_metadata(from_path, to_path, ctype, mtype)
      remove_metadata(from_path, ctype, mtype)
    end

=begin rdoc
Copy metadata for a node in a content tree. This makes a duplicate of all
metadata associated with the original node in the new location.
=end
    def copy_metadata(from_path, to_path, ctype=nil, mtype=nil)
      @metadata_tree.with_subtree(from_path, ctype, mtype, 1) do |node|
        @metadata_tree.clone(node, to_path)
      end
      notify(EVENT_META, from_path, ctype, mtype)
    end

=begin rdoc
Delete a node from a metadata tree.
If mtype is not specified, all metadata will be removed
=end
    def remove_metadata(path, ctype, mtype=nil)
      @metadata_tree.with_subtree(path, ctype, mtype, 1) do |node|
        # remove files first, then remove subdirs
        next if (node.kind_of? ContentRepo::DirNode)
        @metadata_tree.remove_node(node)
      end

      metadata_tree.remove_empty_dirs(path)
    end

=begin rdoc
Returns a Hash [key -> Node] of all metadata tree nodes for path. This invokes
ContentRepo::Tree#with_subtree.
=end
    def metadata(path, ctype=DEFAULT_CTYPE, mtype=nil)
      ctype ||= DEFAULT_CTYPE   # force subtree to include a single ctype 

      h = {}
      @metadata_tree.with_subtree(path, ctype, mtype, 1) do |node|
        t = node.node_type
        h[t] = node
        # FIXME: should this just return contents?
        #h[t] = node.contents || @metadata_tree.default_data(t)
      end

      h
    end

=begin rdoc
Returns an array of pairs [key, node] of all metadata tree nodes for path. If
recursive is true, then subdirectories will be recursed. If path_only is true
then the path is returned instead of the node object.

'dirs' : keep directory (even empty directory) nodes in listing.
See Also: lookup
=end
    def metadata_lookup(path, ctype=nil, mtype=nil, recursive=false, 
                        path_only=true, dirs=false)
      entries = []
      prune = recursive ? nil : 2
      @metadata_tree.with_subtree(path, ctype, mtype, prune) do |node|
        entries << [node.node_type, (path_only ? node.path : node)]
      end
      entries
    end

=begin rdoc
Return true if the node has metadata.
Note: this just calls metadata().
=end
    def has_metadata?(path, ctype=DEFAULT_CTYPE)
      (! metdata(path, content_tree).empty?)
    end

    # -- PROPERTIES --
=begin rdoc
Return Properties metadata for path in Content Tree. If there is no properties
metadata, an empty Hash is returned.
=end
    def properties(path, ctype=DEFAULT_CTYPE)
      node = metadata(path, ctype, :properties)[:properties]
      node ? node.contents : @metadata_tree.default_data(:properties)
    end

=begin rdoc
Set properties value for item. props should be a Hash.
This sends an EVENT_PROPS notification to all subscribers with 'path' as the
notification argument.
=end
    def set_properties(path, ctype, props)
      # FIXME: if sync == startup, add to @repo_properties[:startup_sync]
      add_metadata(path, ctype, props, :properties)
      notify(EVENT_PROPS, path, ctype)
    end

    # -- TAGS --
=begin rdoc
Return Tag metadata for path in Content Tree.
empty path means get all tags.
=end
    def tags(path, ctype=DEFAULT_CTYPE)
      node = metadata(path, ctype, :tags)[:tags]
      node ? node.contents : @metadata_tree.default_data(:tags)
    end

=begin rdoc
Overwrite tags for document with provided array of tags.
=end
    def set_tags(path, ctype, arr)
      # FIXME : force lowercase?
      add_metadata(path, ctype, arr.map { |t| t.to_s }, :tags)
      notify(EVENT_TAG, path, ctype)
    end

    def tag(path, ctype, str)
      # FIXME : force lowercase?
      # str = str.downcase
      arr = tags(path, ctype)
      if (! arr.include? str)
        arr << str
        set_tags(path, ctype, arr)
      end
    end

    def untag(path, ctype, str)
      arr = tags(path, ctype)
      # FIXME: force lowercase?
      arr.reject! { |s| s == str }
      add_metadata(path, ctype, arr, :tags)
      notify(EVENT_TAG, path, ctype)
    end

    # ----------------------------------------------------------------------
    private

    # read Repo properties file
    def read_properties
      buf = ''
      File.open( properties_file, 'r' ) { |f| buf = f.read }
      h = JSON.parse(buf, {:symbolize_names => true})
      @name = h.delete(:name).to_s
      @created= h.delete(:created).to_s
      @description = h.delete(:description).to_s
      @repo_properties = h
    end

    # write Repo properties file
    def write_properties
      buf = @repo_properties.merge( { :name => name,
                           :description => description,
                           :created => created
                          } ).to_json
      File.open( properties_file, 'w' ) { |f| f.write buf }
    end

    # return full path to Repo properties file
    def properties_file
      File.join(@base_path, PROP_FILE)
    end

    def load_content_tree
      @content_tree = ContentRepo::ContentTree.new(@full_path)
      @content_tree.notifier=self
    end

    def load_metadata_tree
      @metadata_tree = ContentRepo::MetadataTree.new(@full_path)
      @metadata_tree.notifier=self
    end

  end

end
