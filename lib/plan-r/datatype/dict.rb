#!/usr/bin/env ruby
# :title: PlanR::Dict
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'rubygems'
require 'json'

module PlanR

=begin rdoc
A key-value store.
This is implemented as a Ruby Hash.

Note: To instantiate a Dict from an existing Hash, use Dict.from_h not
Dict.new(h).
=end
  class Dict < Hash
    # this is just a placeholder, for serializing to/from Dict nodes.

    def self.from_json(str)
      begin
        h = JSON.parse str
        h = { 'data' => h } if (! h.keys.include? 'json_class')
        json_create h
      rescue Exception => e
        $stderr.puts "Unable to parse JSON str '#{str}':\n#{e.message}"
        nil
      end
    end

    def self.json_create(o)
      self[o['data']]
    end

    def self.from_h(h)
      self.class[h]
    end

    def to_h
      Hash[self]
    end

    def self.from_ini(str)
      h = str.lines.inject({}) { |h,line|
            k,v = line.split('=', 2)
            h[k] = v
            h
          }
      self[ h ]
    end

  end
end
