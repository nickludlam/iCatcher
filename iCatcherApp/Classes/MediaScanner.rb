# MediaScanner.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.

class MediaScanner

  def self.listMedia(directory, type, age=60 * 60 * 24 * 7 * 4)
		Logger.debug("listMedia in #{directory}")
    # What are we scanning for? This is a glob match for audio/video files
    if type == "audio" || type == "radio"
      suffix = "{aac,mp3,m4a}"
    elsif type == "video" || type == "tv"
      suffix = "mp4"
    else
      Logger.fatal("Unknown listMedia type #{type}")
    end
  
    files = Dir.glob("#{directory}/*." + suffix)
    current_time = Time.now
    
    if files.length > 0
      files.sort_by { |f| File.mtime f }.each do |file|
        Logger.debug("Evaluating #{file}")
        # Don't yield those  partial files that get_iplayer creates in the download dir while active
        yield file unless file =~ /\.partial\./ || (age > 0 && File.mtime(file) < (current_time - age))
      end
    end
  end
  
  def self.deleteMedia(directory, type, days_older_than = 28)
    age = 60 * 60 * 24 * days_older_than
    threshold = Time.now - age
    
    listMedia(directory, type, 0) do |file|
      Logger.log("Comparing #{File.mtime(file)} with #{threshold}")
      # If its older than the set time, purge
      if File.mtime(file) < threshold
        File.unlink(file)
      end
    end
  end
    
  def self.createVideoCollection(directory)
    self.createCollection(directory, "video", 0)
  end
  
  def self.createAudioCollection(directory)
    self.createCollection(directory, "audio", 0)
  end
    
  def self.createCollection(directory, type, age)	
    collection_name = File.basename(directory)

    collection = MediaCollection.new()
    collection.title = collection_name.gsub(/_/, " ").strip
    collection.author = "iCatcher"
		collection.link = "http://localhost:#{$webserverPort}/?feed=#{collection_name}"
    collection.pub_date = Time.now.strftime("%a, %d %b %Y %T %z")

    files = []
    listMedia(directory, type, age) do |file|
			# Skip over obviously bad files
			if File.size(file) == 0
				Logger.info("Skipping zero-length file #{file}") 
				next
      else
        Logger.debug("Adding #{file}")
			end
			
			collection.media_items << MediaItem.new(file)
		end
  
    collection
  end
end
