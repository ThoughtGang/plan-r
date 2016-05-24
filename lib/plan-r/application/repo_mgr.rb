#!/usr/bin/env ruby
# :title: PlanR::Application::RepoManager
=begin rdoc
=PlanR Repository Manager

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'plan-r/repo'
require 'plan-r/application'
require 'plan-r/application/revision_control'

module PlanR

  module Application

=begin rdoc
An application utility for managing repos.  This allows Application
Service objects to register themselves with Repo and Repository
notification systems.

The RepoManager maintains a list of open repos. This list is only used for
closing the repos cleanly on Application shutdown.
=end
    module RepoManager

=begin rdoc
Sane defaults for project
=end
      DEFAULT_PROPERTIES = {
        :version_control => true
        # TODO: disable java? plugin blacklist?
      }

      @@open_repos = []
=begin rdoc
Returns an iterator over open Repos.
=end
      def self.open_repos
        @@open_repos.each
      end

=begin rdoc
Create a Plan-R Repo at 'path'. This returns a Repo object, but does NOT
call open(). To open a Repo object returned by create() and emit an opened
signal, call open_obj(repo).
=end
      def self.create(name, path, properties=nil, use_git=nil)
        properties ||= DEFAULT_PROPERTIES
        # NOTE: property is only set if caller overrode use_git with true/false
        properties[:version_control] = use_git if (use_git != nil)
        repo = Repo.create(name, path, properties)
        if use_git
          # NOTE: we don't really care if the RevisionControl Service is
          #       started or not, as this is a standalone method (and the
          #       caller has requested Git)
          RevisionControl.enable_git(repo)
        end
        repo
      end

=begin rdoc
Return a Repo object for 'path'. This invokes open_obj() to notify application
services that the repo was opened.
=end
      def self.open(path, app=nil)
        repo = Repo.factory(path)
        @@open_repos << repo
        open_obj(repo, app)
        subscribe_to_repo(repo)
        repo
      end

=begin rdoc
Emit an 'opened' signal to let application services know that a repo has been
opened.
=end
      def self.open_obj(repo, app=nil)
        Service.broadcast_object_loaded(app, repo)
      end

=begin rdoc
Create a Repo revision with the current contents. This creates a Tag in
the RevisionControl system.
=end
      def self.add_revision(repo, name)
        RevisionControlManager.repo_create_tag(repo, name)
      end

=begin rdoc
Invoke repo#save
=end
      def self.save(repo)
        repo.save
      end

=begin rdoc
Close a repo by invoking Repo#close.
Note that if 'rep' is a String, it will be passed to RepoManager.open, 
and the resulting Repo object will be closed. This is useful for forcing
a save when a Repo has been modified outside of the Plan-R API (e.g.
with standard shell utilities).
=end
      def self.close(repo, autosave=false)
        if repo.kind_of? String
          repo = open(repo)
        end
        return if ! repo
        repo.close(autosave)
        remove_repo(repo)
      end

=begin rdoc
On application shutdown, close all repos.
NOTE: This does not invoke repo.save; the application must provide that sort
of save-on-exit functionality if desired.
=end
      def self.shutdown(app)
        @@open_repos.each do |repo|
          close(repo)
        end
      end

      private
=begin rdoc
Subscribe to repo notifications
=end
      def self.subscribe_to_repo(repo)
        repo.subscribe(self) do |msg, *args|
          case msg
          when PlanR::Repo::EVENT_CLOSE
            # This is a no-op if already removed (e.g. in self.close)
            remove_repo(repo)
          end
        end
      end

=begin rdoc
Remove repo from list of open repos.
This can safely be called with a repo that has already been removed.
=end
      def self.remove_repo(repo)
        @@open_repos.reject! { |obj| obj == repo }
      end

    end

  end
end
