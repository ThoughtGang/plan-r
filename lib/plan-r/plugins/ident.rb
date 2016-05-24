#!/usr/bin/env ruby
# :title: PlanR::Plugins::Ident
=begin rdoc
Built-in Ident plugins
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end
 
require 'tg/plugin'
require 'plan-r/datatype/ident'
require 'tempfile'

require 'shellwords'

module PlanR
  module Plugins
    module Ident

=begin rdoc
Wrapper for file(1)
=end
      class FileIdent
        extend TG::Plugin

        name 'file-1'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Identification of file or buffer data via file(1).'
        help 'Passes path argument to the file(1) command.'

        # FIXME: disable if file(1) is not installed
        def ident_file(fname)
          begin
          safe_fname = Shellwords.escape(fname)
          full = %x{file -p -b #{safe_fname}}.chomp
          summary = full.split(",").first
          mime = %x{file -p -b --mime #{safe_fname}}.chomp
          mime_type, encoding = mime.split('; charset=')
          PlanR::Ident.new(mime_type, encoding, nil, summary, full)
          rescue Exception => e
            puts e.message
            puts e.backtrace[0,4].join("\n")
          end
        end

        def ident(data, fname)
          if (! File.exist? fname)
            rv = nil
            Tempfile.create('plan-r-file-ident-plugin') do |f|
              File.open(f.path, 'wb') { |f| f.write data }
              rv = ident_file(f.path)
            end
            rv
          else
            ident_file(fname)
          end
        end
        spec :ident, :ident, 70 do |buf, path|
          next 0 if `which file`.empty?       # file(1) not installed (! unix?)
          90                                  # ... otherwise, super-plus good!
        end
      end

=begin rdoc
A simple, foolproof ident plugin that generates a valid mime-type for all
files.
=end
      class AsciiIdent
        extend TG::Plugin

        name 'Ascii-Ident'
        author 'dev@thoughtgang.org'
        version '1.0-alpha'
        description 'Detects presence of non-ASCII bytes'
        help 'Determines if a file/buffer argument is plaintext or binary.'

        FMT_CHARS = [0x09, 0x0A, 0x0B, 0x0D]
        def is_ascii_byte?(num)
          (num >= 0x20 && num <= 0x7E) || (FMT_CHARS.include? num)
        end

        def ident(data, fname)
          is_text = false
          data.each_byte { |b| is_text |= (is_ascii_byte? b) }
          mime_type = is_text ? 'text/plain' : 'binary/octet-stream'

          PlanR::Ident.new(mime_type)
        end
        spec :ident, :ident, 20 do |buf, path|
          20
        end
      end

    end
  end
end
