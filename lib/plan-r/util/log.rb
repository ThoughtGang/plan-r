#!/usr/bin/env ruby
# :title: PlanR::Log
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

module PlanR

=begin rdoc
Log message 'str'. This calls the puts method of either $log or (if that is
nil) $stderr.
=end
  def self.log(str)
    ($log || $stderr).puts str
  end
end

