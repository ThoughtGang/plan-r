#!/usr/bin/env ruby
# :title: PlanR::RevisionControl
=begin rdoc
Plan R Revision Control System

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

Git-based revision control.
=end

# WARNING: this code is under active development and highly subject to change

require 'yaml'

require 'plan-r/application/service'

require 'plan-r/repo'

require 'grit'

module PlanR

  module Application

=begin rdoc
An application service for performing revision control.

Example:
=end
    class RevisionControl
      extend Service

      CONF_NAME = 'vcs'
      #for git:
      #CFG_USER = 'username'
      #CFG_USER_DEFAULT = ''

      @repos = {}

      # TODO: remote repo

=begin rdoc
Initialize RCS.
=end
      def self.init
        read_config
      end

=begin rdoc
Configure RCS.
=end
      def self.read_config
        @config = Application.config.read_config(CONF_NAME)
      end

=begin rdoc
This should be invoked after an application has completed startup.
=end
      def self.startup(app)
        # nothing to do
      end

=begin rdoc
This should be invoked after an application is about to commence shutdown.
=end
      def self.shutdown(app)
        # nothing to do
      end

=begin rdoc
Object loaded handler. This is called when a PlanR application loads 
a Repo, as long as the :version_contol property is set.
=end
      def self.object_loaded(app, obj)
        repo_init(obj) if (obj.kind_of? PlanR::Repo and
                           obj.repo_properties[:version_control])
      end

      # ----------------------------------------------------------------------
      def self.repo_has_git?(repo)
        File.exist? repo_git_dir(repo)
      end

      def self.repo_init_git(repo)
        begin
          Grit::Repo.init(repo.base_path)
          grit = Grit::Repo.new(repo_git_dir(repo))
        rescue Grit::NoSuchPathError => e
          # sometimes Grit does not handle git init correctly
          `git init #{repo.base_path}`
           grit = Grit::Repo.new(repo_git_dir(repo))
        end

        if ! grit
          $stderr.puts "Unable to open repo for #{repo_git_dir(repo)}"
          return
        end

        ign_file = File.join( repo.base_path, '.gitignore')
        File.open( ign_file, 'w' ) do |f|
          # ignored files and directories
          # TODO: should these have / prefixes? check git docs
          f.puts PlanR::Repo::RUNTIME_DIR
          f.puts PlanR::Repo::PROP_FILE
          # FIXME: get from somewhere
          f.puts 'indexes'
          #f.puts Lucene::Index::BASE
          f.puts 'tmp'
          f.puts '*.swp'  # let's just assume you all use vi
          # IMPORTANT: DO NOT IGNORE HIDDEN FILES (.*)
        end

        grit.add ign_file

        grit.commit_index('Plan-R git repo initialized')

        # TODO: .git/config settings
      end

      def self.repo_git_dir(repo)
        File.join(repo.base_path, '.git')
      end

      def self.repo_add(repo, path, ctype=nil)
        # NOTE: ctype is nil in order to add ALL children
        paths = repo_doc_paths(repo, path, nil)
        return if paths.empty?

        grit = Grit::Repo.new(repo_git_dir(repo))
        # FIXME: why is in_git_dir needed
        in_git_dir(repo) { grit.add(paths) }
        grit.commit(path + ' : Added to repo')
      end

      def self.repo_remove(repo, path, ctype=nil)
        # FIXME: specifying ctype could leave non-ctype children.
        #        need better mechanism! i.e. parent ctype, select ctype
        paths = repo_doc_paths(repo, path, ctype)
        return if paths.empty?
        grit = Grit::Repo.new(repo_git_dir(repo))
        grit.git.rm({ :r => true, :cached => true}, paths)
        grit.commit(path + ' : Removed from repo')
      end

      def self.repo_add_revision(repo, path, ctype, msg)
        # FIXME: shoud ctype be used?
        paths = repo_doc_paths(repo, path, nil)
        return if paths.empty?
        grit = Grit::Repo.new(repo_git_dir(repo))
        grit.git.commit({}, '-m', msg, *paths)
      end

      def self.repo_create_tag(repo, name)
        # FIXME: implement
        $stderr.puts 'repo_create_tag unimplemented!'
      end

      def self.repo_save(repo, msg)
        grit = Grit::Repo.new(repo_git_dir(repo))
        git_update_from_working_dir(repo, grit)
        grit.commit_index(msg)
      end

=begin rdoc
Run git-ls-tree on Repo. This returns the output as an array (of lines).
=end
      def self.repo_ls_tree(repo, paths=[], recurse=true)
        grit = Grit::Repo.new(repo_git_dir(repo))
        opts = {}
        opts[:r] = true if recurse
        grit.git.ls_tree(opts, 'master', paths).lines
      end

      # ----------------------------------------------------------------------
      private
=begin rdoc
Connect Repo object to Revision Control Manager.
=end
      def self.repo_init(repo)
        # TODO: return if config.disable_git
        enable_git(repo)

        # Notification dispatcher
        repo.subscribe(self) do |msg, *args| 
          case msg
          when PlanR::Repo::EVENT_ADD
            repo_add(repo, args[0], args[1])

          when PlanR::Repo::EVENT_CLONE
            # NOTE: from_path is args[0]
            repo_add(repo, args[2], args[1])

          when PlanR::Repo::EVENT_REMOVE
            repo_remove(repo, args[0], args[1])

          when PlanR::Repo::EVENT_UPDATE
            msg = args[2] || "UPDATE '#{args[0]}'"
            repo_add_revision(repo, args[0], args[1], msg)

          when PlanR::Repo::EVENT_REV
            msg = args[2] || "REVISION '#{args[0]}'"
            repo_add_revision(repo, args[0], args[1], msg)
          when PlanR::Repo::EVENT_TAG
            #repo.abs_path(args[0], args[1])
            # no-op : handled by META
            ;
          when PlanR::Repo::EVENT_PROPS
            #repo.abs_path(args[0], args[1])
            # no-op : handled by META
            ;
          when PlanR::Repo::EVENT_META
            path = args[0]
            ctype = args[1]
            mtype = args[2]
            #msg = args[1] || "METADATA '#{path}'"
            #repo_add_revision(repo, path, msg)
          when PlanR::Repo::EVENT_SAVE
            msg = args.first || 'Repo saved by user'
            repo_save(repo, msg)
          when PlanR::Repo::EVENT_CLOSE
            msg = args.first || 'Saved on Repo#close'
            repo_save(repo, msg)
          end
        end
      end

=begin rdoc
Open a git repo for the plan-r repo. The git repo is created if necessary.
=end
      def self.enable_git(repo)
        repo_init_git(repo) if (! repo_has_git? repo)
        @repos[repo.base_path] = Grit::Repo.new(repo_git_dir(repo))
      end

      # Invoke block after performing a chdir to the git repo.
      def self.in_git_dir(repo, &block)
        Dir.chdir(repo.base_path, &block)
      end

      # Perform a git-add on all directories in Content Repository that are
      # under version control.
      # Note: this performs an add but not a commit.
      def self.git_update_from_working_dir(repo, grit)
        dirs = working_dir_entries(repo)
        # TODO : will this capture removed files as well?
        return if dirs.empty?
        # FIXME: why is this block even necessary ?
        in_git_dir(repo) { grit.add(dirs) }
      end

      # Return a list of all directories in the Content Repository that are 
      # under version control. 
      def self.working_dir_entries(repo)
        [ 
          repo.content_tree.root,   # content tree    : './content'
          repo.metadata_tree.root,  # metadata tree   : './metadata'
          PlanR::Repo::PROP_FILE    # properties file : './repo.properties.json'
        ]
      end

      # Return an index with the current working tree entries added to it.
      # Note: this performs a git-add but does not perform a commit!
      def self.git_working_tree_index(repo)
        grit = Grit::Repo.new(repo_git_dir(repo))
        git_update_from_working_dir(repo, grit)
        idx = grit.index
        sha = grit.git.write_tree.chomp
        idx.read_tree(sha)
        idx
      end

      # debug routine to print to stdout
      def self.git_print_tree(t, indent='')
          return if ! t
          t.contents.each do |f|
            puts indent + f.name
            print_tree(f, indent + '    ') if f.kind_of? Grit::Tree
          end
      end

      # return all paths in content repository for node 'path' (and children)
      def self.repo_doc_paths(repo, path, ctype=nil)
        entries = []
        repo.lookup(path, ctype, true, false, false).each do |ctype, node|
          rel_path = node.doc_path.split(repo.base_path, 2).last
          entries << rel_path
          repo.doc_resources(node.path).each do |p|
            entries << File.join('content', p)
          end
        end
        repo.metadata_lookup(path, ctype, nil, true, false, false
                            ).each do |mtype, node|
          rel_path = node.doc_path.split(repo.base_path, 2).last
          entries << rel_path
        end
        entries
      end
    end

  end
end
