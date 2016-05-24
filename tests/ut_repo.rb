#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR Content Repository

require 'test/unit'

require 'plan-r/repo'
require 'plan-r/datatype/data_table'

require_relative "shared/shm_repo"

# ----------------------------------------------------------------------
# on-disk path of the repo
CONTENT_BASE = shm_repo('test-repo')

class TC_RepoTest < Test::Unit::TestCase

  # ==============================================
  # 1.x : PROJECT

  def test_1_0_create_repo
    $repo = PlanR::Repo.create('test-repo', CONTENT_BASE)
    assert_equal('test-repo', $repo.name)

    # TODO: other repo properties
    # created should be < 1 min ago

    assert(File.directory? File.join(CONTENT_BASE, 'var'))
    assert(File.exist? File.join(CONTENT_BASE, 'repo.properties.json'))
    # NOTE: these are created only when content is added
    assert(! (File.exist? File.join(CONTENT_BASE, 'content')))
    assert(! (File.exist? File.join(CONTENT_BASE, 'metadata')))
  end

  # ==============================================
  # 2.x : DATA CONTENT TREES

  # Documents
  DOCS = [
    { :path => 'a/1', :data => '111' },
    { :path => 'a/2', :data => '222' },
    { :path => 'b/1', :data => '333' },
    { :path => 'b/2', :data => '444' },
    { :path => 'z/1/a', :data => '000' }
  ]
  def test_2_1_documents
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')

    # TODO: check handling of missing paths
    
    DOCS.each do |doc|
      $repo.add(doc[:path], doc[:data], :document)
      assert(tree.exist? doc[:path])
      # TODO: check additional stuff
      node = tree[doc[:path]]
      assert_equal(doc[:data], node.contents)
    end

    assert(File.directory? File.join(CONTENT_BASE, 'content'))
    assert(! (File.exist? File.join(CONTENT_BASE, 'metadata')))

    assert_equal(5, tree.subtree('/').count)

    assert_equal(0, tree.subtree('/', nil, 1).count)

    t = tree.subtree('/', nil, 1, true)
    assert_equal(1, t.count)
    assert_equal(["/"], t.map { |x| x.path } )
    assert_equal(0, tree.subtree('/', nil, 2).count)

    t = tree.subtree('/', nil, 2, true)
    assert_equal(4, t.count)
    assert_equal(["/", "/a", "/b", "/z"], t.map { |x| x.path }.sort )

    t = tree.subtree('/', nil, 3, false)
    assert_equal(4, t.count)
    assert_equal(["/a/1", "/a/2", "/b/1", "/b/2"], t.map { |x| x.path }.sort )

    t = tree.subtree('/', nil, 3, true)
    assert_equal(9, t.count)
    assert_equal(["/", "/a", "/a/1", "/a/2", "/b", "/b/1", "/b/2", 
                  "/z", "/z/1"],  t.map { |x| x.path }.sort )

    assert_equal(5, $repo.list('/').count)
    assert_equal(0, $repo.list('/', false).count)
    assert_equal(10, $repo.list('/', true, true).count)
    assert_equal(2, $repo.list('/a').count)
    assert_equal(2, $repo.list('/a', false).count)
    assert_equal(3, $repo.list('/a', true, true).count)
    assert_equal(2, $repo.list('/b').count)
    assert_equal(2, $repo.list('/b', false).count)
    assert_equal(3, $repo.list('/b', true, true).count)
    assert_equal(1, $repo.list('/z').count)
    assert_equal(0, $repo.list('/z', false).count)
    assert_equal(3, $repo.list('/z', true, true).count)

    assert_equal(tree.subtree('/', nil).map{ |x| x.path }, 
                 tree.subtree('/',:document).map { |x| x.path } )
    assert_equal(0, tree.subtree('/', :folder).count)
    assert_equal(0, tree.subtree('/', :note).count)
    assert_equal(0, tree.subtree('/', :table).count)
    assert_equal(0, tree.subtree('/', :dict).count)
    assert_equal(0, tree.subtree('/', :query).count)
    assert_equal(0, tree.subtree('/', :script).count)
    assert_equal(0, tree.subtree('/', :resource).count)
    assert_equal(0, tree.subtree('/', :properties).count)

    # FIXME: does not raise (because of default-overwrite)
    #assert_raises(PlanR::ContentRepo::Tree::NodeConflict) {
    #  $repo.add(DOCS.first[:path], 'key conflict', :table)
    #}
  end

  NOTES = [
    { :path => 'a/1/comments', :data => 'comments on 111' },
    { :path => 'a/1/description', :data => 'description of 111' },
    { :path => 'a/1/notes', :data => 'notes for 111' },
    { :path => 'b/1/stuff', :data => '333 stuff' },
    # problem cases:
    { :path => 'z/1/a/NOTE', :data => 'note with case-conflicting name' },
    { :path => 'z/1/a/note', :data => 'note with case-conflicting name' },
    { :path => 'z/1/a/Note', :data => 'note with case-conflicting name' },
    { :path => 'z/1/a/.note', :data => 'note with hidden name' }
  ]
  def test_2_2_notes
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')

    NOTES.each do |n|
      $repo.add(n[:path], n[:data], :note)
      assert(tree.exist? n[:path])
      # TODO: check additional stuff
      # NOTE: this defaults to :document so it won't work for :note
      #node = tree[n[:path]]
      node = tree.lookup(n[:path], :note)
      assert_equal(n[:data], node.contents)
    end
#
#    assert_equal(3, tree.list('/').count)
#    assert_equal(15, tree.list('/', true).count)
#    assert_equal(15, repo.list_children('/', true, tree.key).count)
  end

  TABLES = [
    { :path => 'a/1/count', :data => PlanR::DataTable.new(1, 1, 4) },
    { :path => 'a/1/data', :data => PlanR::DataTable.new(3, 10) },
    { :path => 'a/1/stats', :data => PlanR::DataTable.new(10, 2) },
    { :path => 'b/1/stats', :data => PlanR::DataTable.new(5) },
    # problem cases:
    { :path => 'z/1/data', :data => nil }
  ]
  def test_2_3_table_tree
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')

    TABLES.each do |n|
      $repo.add(n[:path], n[:data], :table)
      assert(tree.exist? n[:path])
      # TODO: check additional stuff
      node = tree.lookup(n[:path], :table)
      data = n[:data] ? n[:data] : tree.default_data(:table)
      assert_equal(data, node.contents)
    end

#    assert_equal(3, tree.list('/').count)
#    assert_equal(11, tree.list('/', true).count)
#    assert_equal(11, repo.list_children('/', true, tree.key).count)
#
#    assert_raises(PlanR::ContentRepo::Tree::InvalidNodeData) {
#      repo.add('/z/bad_data', 'invalid table data', tree.key)
#    }
  end

  def test_2_4_dict
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')
  end

  def test_2_5_script
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')
  end

  def test_2_6_query
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')
  end

  def test_2_7_resources
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.content_tree
    assert_not_nil(tree, 'Content tree not in repo')
#    r_path = 'example.com/private/images/logo.png'
#    r_data = 'fake resource data'

#    repo.add_resource(r_path, r_data)
#    r = repo.resource(r_path)
#    assert_equal(r, r_data)

#    repo.remove_resource(r_path)
#    r = repo.resource(r_path)
#    assert_nil(r)
  end

  def test_2_8_lineage
    $repo.add('parent', '', :document)
    $repo.add('/parent/child', '', :document)
    $repo.add('/parent/child', '', :note)
    $repo.add('/parent/child', '', :table)
    $repo.add('/parent/child', '', :dict)
    $repo.add('/parent/child', nil, :query)
    $repo.add('/parent/child', nil, :script)
    $repo.add('/parent/another_child', '', :document)
    assert_equal(7, $repo.children('/parent').count)
    assert_equal('/parent', $repo.parent('/parent/child').path)
    assert_equal(7, $repo.siblings('/parent/child').count)
    assert_equal(6, $repo.twins('/parent/child').count)
  end

  # ==============================================
  # 3.x : METADATA CONTENT TREES

  def test_3_1_metadata
    assert_not_nil($repo, 'Repo not created')
    tree = $repo.metadata_tree
    assert_not_nil(tree, 'Metadata tree not in repo')

#    doc_path = '4_1/doc'
#    repo.add(doc_path, 'doc with metadata for 4.1', dtree.key)
#    assert( repo.exist?(doc_path, dtree.key) )

#    # 1. test metadata path generation
#    path = repo.metadata_path(doc_path, dtree.key)
#    assert_equal('documents/4_1/doc/.DOCUMENT.dat', path)

#    # 2. add, lookup, contents
#    doc_prop = { :a => 1, :b => 2 }
#    repo.add_metadata(doc_path, dtree.key, doc_prop, ptree.key )
#    h = repo.metadata(doc_path, dtree.key, ptree.key)
#    assert_equal(doc_prop, h[ptree.key])

#    # 3. remove metadata
#    repo.remove_metadata(doc_path, dtree.key, ptree.key)
#    h = repo.metadata(doc_path, dtree.key, ptree.key)
#    assert( h.empty? )

#    # 4. add, move, lookup, contents, remove metadata
#    repo.add_metadata(doc_path, dtree.key, doc_prop, ptree.key )
#    new_doc_path = '4_1/moved-docs/rnamed_doc'
#    repo.move_metadata(doc_path, new_doc_path, dtree.key)
#    h = repo.metadata(doc_path, dtree.key)
#    assert( h.empty? )
#    h = repo.metadata(new_doc_path, dtree.key)
#    assert_equal(doc_prop, h[ptree.key])
#    repo.remove_metadata(new_doc_path, dtree.key)
#    h = repo.metadata(new_doc_path, dtree.key)
#    assert( h.empty? )
  end

  def test_3_2_properties
    assert_not_nil($repo, 'Repo not created')

#    doc_path = '4_2/doc_with_properties'
#    repo.add(doc_path, 'doc with properties for 4.2', dtree.key)
#    assert( repo.exist?(doc_path, dtree.key) )

#    p = repo.properties(doc_path, dtree.key)
#    p[:name] = 'name'
#    p[:ident] = 123456
#    repo.set_properties(doc_path, dtree.key, p)

#    h = repo.properties(doc_path, dtree.key)
#    assert_equal(h[:name], 'name')
#    assert_equal(h[:ident], 123456)
  end


  def test_3_4_tags
    assert_not_nil($repo, 'Repo not created')
    # 1. add 
    # repo.add_metadata(path, DATA_DOC, data, META_TAG)

    # 2. lookup, check
    # repo.metadata(path, DATA_DOC, META_TAG)
    # .contents

    # 3. lookup via tags, check
    # repo.tags(path, DATA_DOC)

    # 4. remove
    # repo.remove_metadata(from_path, DATA_DOC, META_TAG)`
  end

  # ==============================================
  # 4.x : REPOSITORY OPERATIONS

  def test_4_1_repo_lookup
    assert_not_nil($repo, 'Repo not created')
#    dtree = repo.data_tree[PlanR::Content::Document::Tree.key]
#    ntree = repo.data_tree[PlanR::Content::Note::Tree.key]
#
#    doc_paths = [ '5_1/parent', '5_1/parent/child' ]
#    doc_paths.each do |p| 
#      str = "doc at #{p}"
#      repo.add(p, str, dtree.key)
#      assert( repo.exist?(p, dtree.key) )
#      assert(repo.lookup(p)[dtree.key].kind_of? PlanR::Content::Document::Node)
#      assert_equal(str, repo.content(p, dtree.key))
#      assert_equal(File.join(repo.base_path, dtree.root, p, dtree.filename), repo.abs_path(p, dtree.key))
#      assert_equal(File.join(repo.base_path, dtree.root, p, dtree.filename), repo.abs_path(p))
#    end
#
#    note_paths = [ '5_1/parent/notes', '5_1/parent/child/notes' ]
#    note_paths.each do |p|
#      str = "doc note at #{p}"
#      repo.add(p, str, ntree.key)
#      assert( repo.exist?(p, ntree.key) )
#      assert(repo.lookup(p)[ntree.key].kind_of? PlanR::Content::Note::Node)
#      assert_equal(str, repo.content(p, ntree.key))
#      assert_equal(File.join(repo.base_path, ntree.root, p, ntree.filename), repo.abs_path(p, ntree.key))
#      assert_equal(File.join(repo.base_path, ntree.root, p, ntree.filename), repo.abs_path(p))
#    end

#    assert_equal({}, repo.lookup('/non-existing/item'))
#    assert_equal({}, repo.lookup(doc_paths[0], ntree.key))
#    assert_equal({}, repo.lookup(note_paths[0], dtree.key))

#    items = repo.list_children(doc_paths[0], false)
#    assert_equal(2, items.count)
#    items = repo.list_children(doc_paths[0], true)
#    assert_equal(3, items.count)
#    items = repo.list_children(doc_paths[0], true, dtree.key)
#    assert_equal(1, items.count)
#    items = repo.list_children(doc_paths[0], true, ntree.key)
#    assert_equal(3, items.count)
  end

  def test_4_2_repo_copy
    assert_not_nil($repo, 'Repo not created')
#    dtree = repo.data_tree[PlanR::Content::Document::Tree.key]
#    ntree = repo.data_tree[PlanR::Content::Note::Tree.key]
#    repo.add('5_2/to_copy', 'data to copy for 5.2', dtree.key)
#    assert( repo.exist?('5_2/to_copy', dtree.key) )
#    repo.add('5_2/to_copy/note', 'note to copy for 5.2', ntree.key)
#    assert( repo.exist?('5_2/to_copy/note', ntree.key) )
#    repo.set_properties('5_2/to_copy', dtree.key, { :a => 1, :b  => 2 })
#
#    repo.copy('5_2/to_copy', '5_2_new/copied')
#    assert( repo.exist?('5_2_new/copied', dtree.key) )
#    assert( repo.exist?('5_2_new/copied/note', ntree.key) )
#    assert( repo.exist?('5_2/to_copy', dtree.key) )
#    assert( repo.exist?('5_2/to_copy/note', ntree.key) )

#    p = repo.properties('5_2/to_copy', dtree.key)
#    assert_equal( 1, p[:a] )
#    assert_equal( 2, p[:b] )
#    p = repo.properties('5_2_new/copied', dtree.key)
#    assert_equal( 1, p[:a] )
#    assert_equal( 2, p[:b] )
  end

  def test_4_3_repo_move
    assert_not_nil($repo, 'Repo not created')
#    dtree = repo.data_tree[PlanR::Content::Document::Tree.key]
#    ntree = repo.data_tree[PlanR::Content::Note::Tree.key]

#    repo.add('5_3/to_move', 'data to move for 5.3', dtree.key)
#    assert( repo.exist?('5_3/to_move', dtree.key) )
#    repo.set_properties('5_3/to_move', dtree.key, { :a => 1, :b  => 2 })
#    repo.add('5_3/to_move/note', 'note to move for 5.3', ntree.key)
#    assert( repo.exist?('5_3/to_move/note', ntree.key) )

#    repo.move('5_3/to_move', '5_3_new/moved', dtree.key)
#    assert( repo.exist?('5_3_new/moved', dtree.key) )
#    assert( repo.exist?('5_3_new/moved/note', ntree.key) )

#    p = repo.properties('5_3_new/moved', dtree.key)
#    assert_equal( 1, p[:a] )
#    assert_equal( 2, p[:b] )

#    assert(! repo.exist?('5_3/to_move', dtree.key) )
#    h = repo.metadata('5_3/to_move', dtree.key)
#    assert( h.empty? )
  end

  def test_4_4_repo_delete
    assert_not_nil($repo, 'Repo not created')
#    dtree = repo.data_tree[PlanR::Content::Document::Tree.key]
#    ntree = repo.data_tree[PlanR::Content::Note::Tree.key]

#    repo.add('5_4/to_delete', 'to be deleted for 5.4', dtree.key)
#    assert( repo.exist?('5_4/to_delete', dtree.key) )
#    repo.add('5_4/to_delete', 'note to be deleted for 5.4', ntree.key)
#    repo.set_properties('5_4/to_delete', dtree.key, { :a => 1, :b  => 2 })
#    assert( repo.exist?('5_4/to_delete', ntree.key) )

#    # Remove documents in all trees
#    repo.remove('5_4/to_delete')
#    assert(! repo.exist?('5_4/to_delete', dtree.key))
#    assert(! repo.exist?('5_4/to_delete', ntree.key) )
#    h = repo.metadata('5_4/to_delete', dtree.key)
#    assert( h.empty? )

#    # Remove only document in Doc tree
#    repo.add('5_4/to_delete_doc_only', 'to be deleted for 5.4', dtree.key)
#    repo.add('5_4/to_delete_doc_only/note', 'note for 5.4', ntree.key)
#    repo.set_properties('5_4/to_delete_doc_only', dtree.key, { :a => 1 })
#    assert( repo.exist?('5_4/to_delete_doc_only', dtree.key) )
#    assert( repo.exist?('5_4/to_delete_doc_only/note', ntree.key) )

#    repo.remove('5_4/to_delete_doc_only', dtree.key)
#    assert(! repo.exist?('5_4/to_delete_doc_only', dtree.key) )

#    h = repo.metadata('5_4/to_delete_doc_only', dtree.key)
#    assert( h.empty? )
#    assert( repo.exist?('5_4/to_delete_doc_only/note', ntree.key) )
  end

  def test_4_5_repo_mkdir
    assert_not_nil($repo, 'Repo not created')
#    assert(! repo.exist?('/5_5/newdir') )
#    repo.mkdir('/5_5/newdir')
#    # note: must use path_exist? not exist? to test for dir existence
#    assert( repo.path_exist?('/5_5/newdir') )
  end

end

# ----------------------------------------------------------------------
# Initialization
FileUtils.remove_dir(CONTENT_BASE) if File.exist?(CONTENT_BASE)
