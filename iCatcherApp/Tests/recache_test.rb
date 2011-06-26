# test_recache.rb
# iCatcher
#
# Created by Nick Ludlam on 20/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

require 'singleton'
require 'test/unit'

require 'TaskWrapper'
require 'CacheReader'

#$homeDirectory = "/tmp"
#$downloaderConfigDirectory = "/tmp"

class RecacheTest < Test::Unit::TestCase

	def setup
  end
  
  def teardown
  end
	
	#def test_fetch_cache
  #		tw = TaskWrapper.instance
  #		tw.updateGetIplayerCaches()
	#end
  
  #  def test_recache
	#	cr = CacheReader.instance
	#	
	#	File.unlink(File.join($downloaderConfigDirectory, "tv.cache"))
	#	
	#	exception_raised = false
	#	
	#	begin
  #			cr.testCache
	#	rescue CacheNotFoundException
	#	  exception_raised = true
	#	end
	#	
	#	assert exception_raised, "A non-present cache should raise an exception"
	#end
	
end
