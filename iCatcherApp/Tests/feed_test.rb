# pvr_search_test.rb
# iCatcher
#
# Created by Nick Ludlam on 20/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

require 'test/unit'
require 'singleton'

require 'PVRSearch'
require 'CacheReader'

$downloaderSearchDirectory = "/Users/nick/.get_iplayer/pvr/"
$downloaderConfigDirectory = "/Users/nick/.get_iplayer/"

class FeedTest < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def buildFeed
  end
  
end