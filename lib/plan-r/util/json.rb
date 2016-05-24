#!/usr/bin/env ruby
# :title: PlanR::JsonObject
=begin rdoc
An object that can be serialized to JSON.

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'rubygems'
begin
  require 'json/ext'
rescue LoadError => e
  require 'json'
end

# =============================================================================

module PlanR

=begin rdoc
Classes that support JSON serialization should extend this module.
=end
  module JsonClass

=begin rdoc
Parse JSON data with error handling.

Note: this is just generic JSON parsing code. The classes encoded in the JSON
data must have a json_create method instantiated for it to work.
=end
    def self.from_json(str)
      begin
        # BUG: :symbolize_names causes object to be returned as a Hash
        #JSON.parse(str, {:symbolize_names => true, :max_nesting => 50})
        JSON.parse(str, {:max_nesting => 50})
      rescue JSON::ParserError => e
        $stderr.puts "JSON ERROR : #{e.message}"
        $stderr.puts "JSON INPUT : #{str.inspect}"
      end
    end

=begin rdoc
Instantiate object from JSON representation.
=end
    def from_json(str)
      JsonClass.from_json str
    end

=begin rdoc
JSON callback for instantiating object. This uses the class's from_hash method.
=end
    def json_create(o)
      from_hash(o['data'].inject({}) { |h,(k,v)| h[k.to_sym] = v; h })
    end
  end

=begin rdoc
Classes that support JSON serialization should include this module.
=end
  module JsonObject

=begin rdoc
Convert the object to JSON. This uses the class's to_h method.
=end
    def to_json(*arr)
      { 'json_class' => self.class.name, 
         'data' => self.to_h }.to_json(*arr)
    end
  end

end
