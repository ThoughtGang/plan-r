#!/usr/bin/env ruby                                                             
## :title: Plan-R
=begin rdoc
=Plan-R Document Management Tool
<i> (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org> </i>
=end

require 'plan-r/version'

module PlanR

  autoload :Application, 'plan-r/application.rb'
  autoload :ContentRepo, 'plan-r/content_repo.rb'
  autoload :Document, 'plan-r/document.rb'
  autoload :Repo, 'plan-r/repo.rb'

  # datatypes
  autoload :AnalysisResults, 'plan-r/datatype/analysis_results.rb'
  autoload :DataTable, 'plan-r/datatype/data_table.rb'
  autoload :Dict, 'plan-r/datatype/dict.rb'
  autoload :Ident, 'plan-r/datatype/ident.rb'
  autoload :ParsedDocument, 'plan-r/datatype/parsed_document.rb'
  autoload :Query, 'plan-r/datatype/query.rb'
  autoload :Result, 'plan-r/datatype/query.rb'
  autoload :RelatedDocuments, 'plan-r/datatype/query.rb'
  autoload :TokenStream, 'plan-r/datatype/token_stream.rb'
end
