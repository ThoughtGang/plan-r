#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Convenience routines to creates repos in-memory

UT_REPO_BASEDIR = 'tests/repo'
# FIXME: support OS X, Windows, FreeBSD
UT_TMPDIR = '/tmp'
SHM_BASEDIR = '/dev/shm'

def shm_repo(name)
  shm_avail? ? File.join(SHM_BASEDIR, name) : File.join(UT_REPO_BASEDIR, name)
end

def shm_tmp(name)
  shm_avail? ? File.join(SHM_BASEDIR, name) : File.join(UT_TMPDIR, name)
end

def shm_avail?
  (File.exist? SHM_BASEDIR) and (File.directory? SHM_BASEDIR) and
  (File.writable? SHM_BASEDIR)
end

