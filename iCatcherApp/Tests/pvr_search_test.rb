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

class PVRSearchTest < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_store_and_retrieve
	  filename = "__test_search.#{$$}"
		filepath = "#{$downloaderSearchDirectory}/#{filename}"
		
		category = "test_category"
		channel = "test_channel"
		search_term = "search term"
		
	  p = PVRSearch.new
		p.category = category
		p.channel = channel
		p.filename = filename
		p.searchesString = search_term
		
		assert p.unsaved == true, "New search should be marked as unsaved"
		assert p.dirty == true, "New search should be marked as dirty"
		
		p.writeToDisk()
		
		assert p.unsaved == false, "Saved search should be marked saved"
		assert p.dirty == false, "Saved search should not be marked dirty"

		q = PVRSearch.new(filepath)
		
		assert q.filename == filename, "Filenames should match"
		assert q.category == category, "Category should match"
		assert q.channel == channel, "Channels should match"
		assert q.searchesString == search_term, "Search terms should match"		
		
		q.removeFromDisk
		
		assert !File.exists?(filepath), "PVRSearch file should be gone"
  end
  
	def test_match_pvr_search_by_term
		p = PVRSearch.new
		p.searchesString = "BBC London News"
		
		c = CacheReader.instance
		indexes = c.programmeIndexesForPVRSearch(p)
		
		assert indexes.count > 0, "Should match at least one program, but got #{indexes.count}"
	end
	
	def test_match_pvr_search_by_channel
		p = PVRSearch.new
		p.channel = "BBC Radio 1"
		
		c = CacheReader.instance
		indexes = c.programmeIndexesForPVRSearch(p)
		
		assert indexes.count > 0, "Should match at least one program, but got #{indexes.count}"
	end
	
	def test_match_pvr_search_by_category
		p = PVRSearch.new
		p.category = "comedy"
		
		c = CacheReader.instance
		indexes = c.programmeIndexesForPVRSearch(p)
		
		assert indexes.count > 0, "Should match at least one program, but got #{indexes.count}"
	end

	def test_match_pvr_search_by_type_and_channel
		p = PVRSearch.new
		p.channel = "BBC One"
		p.type = "tv"
		
		c = CacheReader.instance
		indexes = c.programmeIndexesForPVRSearch(p)
		
		assert indexes.count > 0, "Should match at least one program, but got #{indexes.count}"
	end

end