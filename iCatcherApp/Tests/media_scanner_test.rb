# media_scanner_test.rb
# iCatcher
#
# Created by Nick Ludlam on 03/01/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.


require 'test/unit'

require 'MediaScanner'
require 'MediaCollection'
require 'TagLib.bundle'


class MediaScannerTest < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_fail
		files = []
		MediaScanner.listMedia(File.dirname(__FILE__) + '/../test_data/audio', 'audio', 0) do |s|
		  files << s
	  end
    
    assert files.length > 0, 'array should contain files'
  end
  
  def test_anything
    collection = MediaScanner.createAudioCollection(File.dirname(__FILE__) + '/../test_data/audio')
    assert true, 'Assertion was false.'
  end
  
end