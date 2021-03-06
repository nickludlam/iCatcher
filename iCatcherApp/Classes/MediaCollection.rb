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
  attr_accessor :media_id, :filepath, :size, :url, :title, :description, :pub_date, :human_date, :author, :image_url
  
  MIME_TYPES = { '.mp3' => 'audio/mpeg', '.m4a' => 'audio/mp4', '.mp4' => 'video/mp4' }

  def initialize(fpath)
    @filepath = fpath
    #Logger.debug("Running taglib on #{@filepath}")
    tags = TagLib.alloc.initWithFileAtPath(@filepath)
    #Logger.debug("Finished collecting tags")
    # Consolidate album and title into the title, or cope with nil
  	if tags.title
      if tags.title.index(tags.album) != nil
        @title = tags.title
      else
        @title = tags.album + " : " + tags.title
      end
    else
      @title = ""
    end
		
    @description = tags.comment || ""
    @pub_date = File.ctime(@filepath).strftime("%a, %d %b %Y %T %z")
    @human_date = File.ctime(@filepath).strftime("%A %h %d, %I:%M %p") # Human formatted version
    @author = tags.artist || ""
		
    collection_name = File.basename(File.dirname(@filepath))
    file_basename = File.basename(@filepath)
    @url = "http://#{$webserverHostname}:#{$webserverPort}/files/#{collection_name}/#{file_basename}"
    #Logger.debug("Finished making media item for file")
  end
  
  def file_suffix
    File.extname(@filepath)
  end

  def mime_type
    #Logger.debug("Finding mimetype for file #{@filepath}")
    filename_suffix = File.extname(@filepath)
    MIME_TYPES[file_suffix]
  end
	
  def size
    #Logger.debug("Finding file size at path #{@filepath}")
    File.size(@filepath)
  end
end


