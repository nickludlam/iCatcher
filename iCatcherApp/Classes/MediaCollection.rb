# MediaCollection.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.


class MediaCollection
  attr_accessor :title ,:link, :description, :author, :pub_date, :media_items
  def initialize
    @media_items = []
  end
end

class MediaItem
  attr_accessor :media_id, :filepath, :size, :url, :title, :description, :pub_date, :author, :image_url
  
  MIME_TYPES = { '.mp3' => 'audio/mpeg', '.m4a' => 'audio/mp4', '.mp4' => 'video/mp4' }

  def initialize(fpath)
    @filepath = fpath
		tags = TagLib.alloc.initWithFileAtPath(@filepath)
		
  	if tags.title.index(tags.album) != nil
			@title = tags.title
		else
			@title = tags.album + " : " + tags.title
		end
    
    # Safeguard nil values
    @title = "" unless @title
		
		@description = tags.comment || ""
		@pub_date = File.ctime(@filepath).strftime("%a, %d %b %Y %T %z")
		@author = tags.artist || ""
		
		collection_name = File.basename(File.dirname(@filepath))
    file_basename = File.basename(@filepath)
		@url = "http://localhost:#{$webserverPort}/files/#{collection_name}/#{file_basename}"
  end
  
	def file_suffix
	  File.extname(@filepath)
	end

  def mime_type
    filename_suffix = File.extname(@filepath)
    MIME_TYPES[file_suffix]
  end
	
	def size
	  File.size(@filepath)
	end
end


