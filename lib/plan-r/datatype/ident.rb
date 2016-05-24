#!/usr/bin/env ruby
# :title: PlanR::Ident
=begin rdoc
Object describing the contents of a file or buffer.

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

=begin rdoc
Identification of code or data.

The structure of the Ident object is derived from the output of libmagic and
the file(1) utility.
=end
  class Ident

=begin rdoc
Mime-type of the target data.
=end
    attr_reader :mime

=begin rdoc
=end
    attr_reader :encoding

=begin rdoc
Summary of the target data. This is a single line, and is suitable for 
display in a tooltip.
=end
    attr_reader :summary

=begin rdoc
Full description of the target data. This can be several lines.
=end
    attr_reader :full

=begin rdoc
Human language (e.g. english, russian) of document, if applicable.
=end
    attr_reader :language

=begin rdoc
Mime-type for unknown/unrecognized data format.
=end
    MIME_UNKNOWN = 'unknown'
    ENC_UNKNOWN = 'unknown'
    LANG_UNKNOWN = 'unknown'

=begin rdoc
Summary for unknown/unrecognized data format.
=end
    SUMMARY_UNKNOWN = 'Unrecognized'

=begin rdoc
Full description for unknown/unrecognized data format.
=end
    FULL_UNKNOWN = 'Unrecognized target data; try another ident plugin.'

=begin rdoc
Note: An ident must contain a valid MIME-type; all other components are 
optional. Optional components should be set to nil, NOT to UNKNOWN. This
distinguishs between a parser that could not identify the data format (and
returns a Ident.unrecognized), and one that could identify the format but
could not provide complete information.
=end
    def initialize( mime, encoding=nil, language=nil, summary=nil, full=nil )
      @mime = mime.strip
      @encoding = encoding && (! encoding.strip.empty?) ? encoding.strip : nil
      @language = language && (! language.strip.empty?) ? language.strip : nil
      @summary = summary && (! summary.strip.empty?) ? summary.strip : nil
      @full = full && (! full.strip.empty?) ? full.strip : nil
    end

=begin rdoc
Convert Ident object to a Hash.
=end
    def to_h
      { :mime => mime, :encoding => encoding, :language => language, 
        :summary => summary, :full => full }
    end

=begin rdoc
Instantiate an Ident object from a Hash.
=end
    def self.from_hash(h)
      self.new(h[:mime], h[:encoding], h[:language], h[:summary], h[:full])
    end

=begin rdoc
Factory method to generate an Ident object when the ident failed.
=end
    def self.unrecognized
      Ident.new( MIME_UNKNOWN, LANG_UNKNOWN, ENC_UNKNOWN, SUMMARY_UNKNOWN, 
                 FULL_UNKNOWN )
    end

=begin rdoc
Return true if the Ident is valid.
=end
    def recognized? 
      return (self.mime != MIME_UNKNOWN)
    end

    # ----------------------------------------------------------------------
    def to_s
      return mime
    end

    def inspect
      "%s charset=%s lang=(%s): %s\n%s" % [ mime, encoding, language, summary, 
                                            full ]
    end
  end

end
