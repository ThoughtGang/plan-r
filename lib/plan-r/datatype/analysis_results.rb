#!/usr/bin/env ruby
# :title: PlanR::AnalysisResults
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

=begin rdoc
Output of :analyze_doc plugin specification.
=end
  class AnalysisResults < Hash

=begin rdoc
ParsedDocument object the results are associated with.
=end
    attr_reader :doc
=begin rdoc
Plugin used to generate the Analysis Results
=end
    attr_reader :analyzer

    def initialize(plugin, doc, *args)
      @analyzer = plugin
      @doc = doc
      super *args
    end
  end

end
