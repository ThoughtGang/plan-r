#!/usr/bin/env ruby
# :title: PlanR::Plugins::ImportExport::Tarball
=begin rdoc
Export-to/Import-from tarball (.tgz) files
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end
 
require 'tg/plugin'
require 'rubygems/package'
require 'zlib'

require 'stringio'

module PlanR
  module Plugins
    module ImportExport

=begin rdoc
Export to or import from a .tgz file
=end
      class Tarball
        extend TG::Plugin

        name 'Tarball Import/Export'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Export to or import from a .tgz file'
        help 'Create a tarball containing the specified files. The tarball
 will be suitable for extraction to a filesystem for use by other software.
 Child documents will be in folders named $PARENT_DOC.children, and 
 non-document content types will have a .plr extension. Document metadata
 will be stored in a JSON-encoded file at the topmost directory of the tarball.
 WARNING: child documents are currently unsupported
 WARNING: properties are currently unsupported.'

        DEFAULT_TARBALL = 'plan-r.export.tgz'
        #PROPS_FILE = 'PlanR-properties.export.json'

        def export_tgz(repo, paths, dest, opts)
          exported = []
          # FIXME: pre-generate properties file, write as first entry
          write_tar(dest) do |tar|
            paths.each do |path|
              repo.lookup(path, nil, true, false, true).each do |key, node|
                tar_path = node_path(node)
                abs_path = node.doc_path
                mode = File.stat(abs_path).mode
                if key == :folder
                  tar.mkdir(tar_path, mode)
                else
                  exported << node.path

                  File.open(abs_path, 'rb') do |f|
                    tar.add_file(tar_path, mode) { |tar_f| tar_f.write(f.read) }
                  end
                  # FIXME: if file has recourses
                  # mkdir ../.CONTENT.rsrc
                  # add all resources
                end
              end

              # FIXME: properties file
            end
          end
          exported
        end
        spec :export_contents, :export_tgz, 70

        def import_tgz(repo, origin, dest, opts)
          dest = '/' if (! dest) or (dest.empty?)

          imported = []
          read_tar(origin) do |tar|
            # FIXME: pre-process entries to read properties file
            tar.each_entry do |ent| 
              doc_path = File.join(dest, ent.full_name)
              data = ent.read
              # FIXME: properties
              imported << repo_add_node(repo, doc_path, data, {})
              # FIXME: add resources andsuch
            end
          end
          imported
        end
        spec :import_contents, :import_tgz, 70

        def contents(tarball)
          entries = []
          read_tar(tarball) do |tar|
            tar.each_entry { |ent| entries << ent.full_name }
          end
          entries
        end
        api_doc :contents, ['String|IO tarball'], 'Array', 
                'Return a list of the paths contained in a tarball'

        def compress(str)
          io = StringIO.new('')
          compress_io(StringIO.new(str), io)
          io.string
        end
        api_doc :compress, ['String data'], 'String', 
                'Compress a String using GZip'

        def decompress(str)
          io = StringIO.new('')
          decompress_io(StringIO.new(str), io)
          io.string
        end
        api_doc :decompress, ['String gzdata'], 'String', 
                'Decompress a String using GZip'

        def compress_io(in_io, out_io)
          gz = Zlib::GzipWriter.new(out_io)
          gz.write in_io.string
          gz.close
          out_io.rewind
        end
        api_doc :compress_io, ['IO in', 'IO out'], '', 
                'Compress an IO to an IO using GZip'

        def decompress_io(in_io, out_io)
          in_io.rewind
          gz = Zlib::GzipReader.new(in_io)
          out_io.write(gz.read)
          out_io.rewind
        end
        api_doc :decompress_io, ['IO in', 'IO out'], '', 
                'Decompress an IO to an IO using GZip'
        

        def read_tar(origin, &block)
          io = nil
          close_io = false
          if (origin.respond_to? :read)
            io = origin
          else
            return if (! File.exist? origin)
            io = File.open(origin, 'rb')
            close_io = true
          end

          tar_io = StringIO.new('')
          decompress_io(io, tar_io)

          Gem::Package::TarReader.new(tar_io, &block)
          io.close if close_io
        end
        api_doc :read_tar, ['String|IO tarball', '&block'], '', 
                'Open a tarball for reading and yield it to block'

        def write_tar(dest, &block)
          out_io = nil
          close_io = false
          if (dest.respond_to? :write)
            out_io = dest
          else
            if (File.exist? dest) and (File.directory? dest)
              dest = File.join(dest, DEFAULT_TARBALL)
            end
            out_io = File.open(dest, 'wb')
            close_io = true
          end

          io = StringIO.new('')
          Gem::Package::TarWriter.new(io, &block)

          compress_io(io, out_io)
        end
        api_doc :write_tar, ['String|IO tarball', '&block'], '', 
                'Open a tarball for writing and yield it to block'

        # FIXME: generate programmatically
        CONTENT_TYPE_EXT = {
          :document => '',
          :note => '.plan-r-note.plr',
          :table => '.plan-r-table.plr',
          :dict => '.plan-r-dict.plr',
          :script => '.plan-r-script.plr',
          :query => '.plan-r-query.plr'
        }
        def node_path(node)
          # FIXME: support child documents
          ext = CONTENT_TYPE_EXT[node.node_type] || ''
          node.path.split('/', 2).last + ext
        end

        def repo_add_node(repo, path, data, properties)
          # FIXME: support child documents
          ext = File.basename(path)
          ctype = :document
          if ext == 'plr'
            ext = File.extname(File.basename(path, ext)) + ext
            path = File.basename(path, ext)
            # FIXME: support future document types by generating extension
            #        programmatically
            ctype = CONTENT_TYPE_EXT.key(ext) || :document
          end

          repo.add(path, data, ctype)
          # FIXME: set-properties
          return path
        end

      end

      # -----------------------------------------------------------------------
      class TarballArchive < Tarball
        TG::Plugin.extended(self)

        name 'Tarball Archive'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Export/import raw repo contents to/from a .tgz file'
        help 'This generates a tarball containing the raw Plan-R content
 and metadata tree for the specified paths. This tree can simply be copied
 into an existing Plan-R repository in order to import the data.
 '

        def export_tgz(repo, paths, dest, opts)
          raise 'NOT IMPLEMENTED'
          # FIXME: tarball of on-disk directory
          []
        end
        spec :export_contents, :export_tgz, 40

        def import_tgz(repo, origin, dest, opts)
          raise 'NOT IMPLEMENTED'
          # FIXME: directly read tarball
          []
        end
        spec :import_contents, :import_tgz, 40
      end

    end
  end
end
