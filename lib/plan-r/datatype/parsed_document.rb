#!/usr/bin/env ruby
# :title: PlanR::Document::Parsed
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

  # ----------------------------------------------------------------------
  # OUTPUT OF PARSER
=begin rdoc
Output of a parse plugin spec

Note: can contain a mapping of text blocks to plaintext positions -- this
can be used to convert a plaintext offset (e.g. for a keyword) to a position
in the original text. Is this useful? Otherwise, summary can have the
highlighting... display kwd highlighting requires viewer support.

* links (outbound)
* toc
* images
* stylesheets
* internal addresses
=end
  class ParsedDocument 
    # Names of external reference types
    REF_STYLE='style'
    REF_SCRIPT='script'
    REF_IMAGE='image'
    REF_DOC='doc'

=begin rdoc
Original, unparsed document. This provides access to path and repository, if
necessary.
=end
    attr_reader :doc

=begin rdoc
Array of blocks of plaintext in original document
=end
    attr_reader :text_blocks
=begin rdoc
Name of parser
=end
    attr_accessor :parser
=begin rdoc
MIME-type for document contents
=end
    attr_accessor :content_type
=begin rdoc
External files referenced to by document.
This is a Hash [String -> Array[String]] mapping document types to paths.
Example types:
  'style'   : HTML stylesheet
  'script'    : HTMP SCRIPT tag
  'image' : HTML IMG tag
  'doc'   : HTML A tag
=end
    attr_reader :external_refs
=begin rdoc
Keywords defined in document
=end
    attr_reader :keywords
=begin rdoc
Misc properties defined by the parser.
=end
    attr_reader :properties

    def initialize(parser, doc)
      @parser = parser
      @doc = doc
      @content_type = 'text/plain'
      # NOTE: these don't need write accessors as the Arrays/Hashes are
      #       accessed directly
      @text_blocks = []
      @external_refs = {}
      @keywords = []
      @properties = {}
    end

=begin rdoc
=end
    def add_text_block(str)
      # TODO: more sophisticated storage of text blocks, e.g. with doc offset
      @text_blocks << str
    end

=begin rdoc
=end
    def add_ext_ref(path, type)
      @external_refs[type] ||= []
      @external_refs[type] << path if ! (@external_refs[type].include? path)
    end

=begin rdoc
Return a contiguous plaintext version of the document. Can be utf-8. Used for
analysis and getting keywords.
=end
    def plaintext(delim="\n")
       @text_blocks.join(delim)
    end

=begin rdoc
Return plaintext contents, encoded to UTF-8.
=end
    def plaintext_utf8(delim="\n")
      plaintext(delim).encode('UTF-8', invalid: :replace, undef: :replace, 
                              replace: '?')
    end

=begin rdoc
Return plaintext contents, encoded to US-ASCII.
=end
    def plaintext_ascii(delim="\n")
      plaintext(delim).encode('US-ASCII', invalid: :replace, undef: :replace, 
                              replace: '?')
    end

  end
end
