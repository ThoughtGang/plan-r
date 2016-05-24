#!/usr/bin/env ruby
# :title: PlanR::TokenStream
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

=begin rdoc
Output of :tokenize_doc plugin specification.
=end
  class TokenStream < Array

=begin rdoc
ParsedDocument object the tokenstream is associated with.
=end
    attr_reader :doc
    attr_reader :analyzer
    alias :analyzer :analyzer

    def initialize(plugin, doc, *args)
      @analyzer = plugin
      @doc = doc
      super *args
    end

    def self.from_array(plugin, doc, arr)
      ts = self.new(plugin, doc)
      arr.each { |t| ts << t }
      ts
    end

  end

end
