#!/usr/bin/env ruby
# :title: PlanR::Plugins::DataSource::LocalFS
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Plugins
    module DataSource

      class LocalFS
        extend TG::Plugin
        name 'Local File Data Source'
        author 'mkfs@thoughtgang.org'
        version '1.0'
        description 'Retrieves data from local filesystem'
        help 'This just reads a file from the local filesystem'

        def local_path(path)
          return path if (File.exist? path)
          URI.parse(path).path
        end

        def load_fs(path, repo=nil)
          File.open(local_path(path), 'rb') { |f| f.read }
        end
        spec :data_source, :load_fs, 80 do |origin, repo|
          next 90 if (File.exist? origin)
          begin
            uri = URI.parse(origin)
            next 0 if (! uri)
            'file'.casecmp(uri.scheme) == 0 && (File.exist? uri.path) ? 90 : 0
          rescue URI::InvalidURIError
            0 # Not a URI
          end
        end
      end

    end
  end
end

