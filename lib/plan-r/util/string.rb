#!/usr/bin/env ruby
# :title: PlanR String Extensions
=begin rdoc

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

# =============================================================================

class String

=begin rdoc
Convenience method to force conversion to a UTF-8 string.
=end
  def utf8!
    self.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    self
  end
end
