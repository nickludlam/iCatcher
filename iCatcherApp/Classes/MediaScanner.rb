# MediaScanner.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.

class MediaScanner
  DEFAULT_AGE = 60 * 60 * 24 * 7 * 2 # 2 weeks
  
  def self.listMedia(directory, type, age=DEFAULT_AGE)
    #Logger.debug("listMedia in #{directory}")
    # What are we scanning for? This is a glob match for audio/video files
    if type == "audio" || type == "radio"
      suffix = "{aac,mp3,m4a}"
    elsif type == "video" || type == "tv"
      suffix = "mp4"
    elsif type == "all"
      suffix = "{aac,mp3,mp4,m4a,m4v,mov}"
    else
      Logger.fatal("Unknown listMedia type #{type}")
    end
  
    files = Dir.glob("#{directory}/*." + suffix)
    current_time = Time.now
    
    if files.length > 0
      files.sort_by { |f| File.mtime f }.reverse.each do |file|
        #Logger.debug("Evaluating #{file}")
        # Don't yield those  partial files that get_iplayer creates in the download dir while active
        yield file unless file =~ /\.partial\./ || (age > 0 && File.mtime(file) < (current_time - age))
      end
    end
  end
  

  def self.deleteMedia(directory, type, days_older_than = 28)
    age = 60 * 60 * 24 * days_older_than
    threshold = Time.now - age
    
    listMedia(directory, type, 0) do |file|
      file_ctime = File.ctime(file)
      Logger.debug("Comparing #{file_ctime} with #{threshold} for #{file}")
      # If its older than the set time, purge
      if file_ctime < threshold
        Logger.debug("Deleting expired content #{file}")
        File.unlink(file)
      end
    end
  end
    
  def self.createCollectionFromPVRSearch(search, age = DEFAULT_AGE)	
    collection = MediaCollection.new()
    collection.title = search.displayname + " (via iCatcher)"
    collection.author = "iCatcher"
		collection.link = "#{$webserverURL}feeds/#{search.filename}.xml"
    collection.pub_date = Time.now.strftime("%a, %d %b %Y %T %z")

    files = []
    listMedia(search.mediaDirectory, search.type, age) do |file|
			# Skip over obviously bad files
			if File.size(file) == 0
				Logger.warning("Skipping zero-length file #{file}") 
				next
      else
        Logger.debug("Adding #{file}")
			end
			
			collection.media_items << MediaItem.new(file)
		end
  
    collection
  end


  def self.createCollectionFromAdHocDirectory(age = DEFAULT_AGE)	
    collection = MediaCollection.new()
    collection.title = "iCatcher Ad Hoc Downloads"
    collection.author = "iCatcher"
    collection.link = "#{$webserverURL}adhoc_feed.xml"
    collection.pub_date = Time.now.strftime("%a, %d %b %Y %T %z")
    
    files = []
    listMedia($downloaderAdHocDirectory, "all", age) do |file|
      Logger.debug("Checking filesize for #{file}")
      # Skip over obviously bad files
      if File.size(file) == 0
        Logger.warning("Skipping zero-length file #{file}") 
        next
      else
        Logger.debug("Adding #{file}")
      end
    
      collection.media_items << MediaItem.new(file)
    end

    Logger.debug("Finished making collection")

    collection
  end

end
