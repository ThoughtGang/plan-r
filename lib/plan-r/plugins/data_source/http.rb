#!/usr/bin/env ruby
## :title: PlanR::Plugins::DataSource::Http
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>

require 'uri'
require 'net/http'

require 'tg/plugin'

module PlanR
  module Plugins
    module DataSource

      class Http
        extend TG::Plugin
        name 'HTTP Data Source'
        author 'mkfs@thoughtgang.org'
        version '1.0'
        description 'Retrieve data from HTTP and HTTPS URLs'
        help 'Uses net/http to download data via HTTP or HTTPS'

        def load_http(url, repo=nil)
          begin
            uri = URI.parse(url)
            
            resp = Net::HTTP.get_response(uri)
            if resp.code == '404'
              $stderr.puts ":data_source: HTTP 404 for '#{url}'"
              return ''
            elsif ['301', '302', '307'].include? resp.code
              # this can handle nested redirects
              load_http(resp['location'])
            else
              resp.body
            end
          rescue Exception => e
            # FIXME: log
            ''
          end
        end
        spec :data_source, :load_http, 80 do |origin, repo|
          begin
            uri = URI.parse(origin)
            (['http', 'https'].include? uri.scheme.downcase) ? 90 : 0
          rescue Exception => e
            0 # Not a URI
          end
        end
      end

    end
  end
end

