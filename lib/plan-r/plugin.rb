#!/usr/bin/env plugin
# :title: PlanR::Plugin
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

# Note: this is just a wrapper that reqiures the TG-Plugins module, so
#       plugin authors can require 'plan-r/plugin' instead of 'tg/plugin'.

require 'tg/plugin'

module PlanR
  # alias TG::Plugin to PlanR::Plugin
  Plugin = TG::Plugin
end
