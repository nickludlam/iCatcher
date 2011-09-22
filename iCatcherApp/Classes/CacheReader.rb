# CacheReader.rb
# iCatcher
#
# Created by Nick Ludlam on 15/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class CacheReader
  include Singleton

  attr_accessor :last_cache_update
  attr_accessor :tv_channels
  attr_accessor :tv_categories
  attr_accessor :radio_channels
  attr_accessor :radio_categories

  def initialize
    @max_cache_age = 60 * 60 * 4 # Same as get_iplayer
  	
    @radio_cache_by_pid = {}
    @tv_cache_by_pid = {}
		
    @parsed_radio_cache_mtime = nil
    @parsed_tv_cache_mtime = nil
    
    @radio_categories = {}
    @radio_channels = {}

    @tv_categories = {}
    @tv_channels = {}

    @cache_format = %w/index type name pid available episode seriesnum episodenum versions duration desc channel categories thumbnail timeadded guidance web/
  end
  
  def cachePathForType(type)
		File.join($downloaderConfigDirectory, "#{type}.cache")
	end

  def cacheEmpty?(type = "radio")
    if type == "radio"
      return @radio_cache_by_pid.empty?
    else
      return @tv_cache_by_pid.empty?
    end
  end
  
  def cacheStale?(type = "radio")
    cache_path = cachePathForType(type)
    return true unless File.exist?(cache_path)
    
    cache_age = File.mtime(cache_path)
    return (Time.now - cache_age) > @max_cache_age
  end

  def populateCachesIfRequired
    if cacheEmpty?("radio") || @parsed_radio_cache_mtime < File.mtime(cachePathForType("radio"))
      parseCache("radio")
    end
		
    if cacheEmpty?("tv") || @parsed_tv_cache_mtime < File.mtime(cachePathForType("tv"))
      parseCache("tv")
    end
  end

  def parseCache(type = "radio")
    Logger.debug("Parsing #{type} cache")
    cache_path = cachePathForType(type)
		
    pid_index_number = @cache_format.index("pid")		
    channel_index_number = @cache_format.index("channel")		
    categories_index_number = @cache_format.index("categories")		
    
    if type == 'radio'
      channels_hash = @radio_channels
      categories_hash = @radio_categories
    else
      channels_hash = @tv_channels
      categories_hash = @tv_categories
    end

    cache_hash = {}
		
    File.open(cache_path) do |f|
      lines = f.readlines()
      comments = lines.shift
      lines.each do |line|
        elements = line.split("|")
        pid = elements[pid_index_number]
        cache_hash[pid] = elements
        
        # Also get a hash of all categories
        categories = elements[categories_index_number]
        if categories
          categories.split(",").each do |category|
            categories_hash[category] = true
          end
        end
        
        # Same for channels
        channel = elements[channel_index_number]
        # Don't add these, as I think their superfluous
        channels_hash[channel] = true unless channel == "Signed" || channel == "Audio Described"
      end
    end
		
    # Update the right hash
    if type == "radio"
      @radio_cache_by_pid = cache_hash
      @parsed_radio_cache_mtime = File.mtime(cache_path)
    else
      @tv_cache_by_pid = cache_hash
      @parsed_tv_cache_mtime = File.mtime(cache_path)
    end
		
    #Logger.debug("Finished cache parse. Have #{@radio_cache_by_pid.keys.length} radio entries, and #{@tv_cache_by_pid.keys.length} tv entries")
  end

  # For external invocation from ApplicationController
  def testCache(type = "radio")
		cache_path = cachePathForType(type)
    unless File.exist?(cache_path)
      raise CacheNotFoundException, "Unable to locate #{cache_path}"
    end
    
    cache_mtime = File.mtime(cache_path)
    
    unless Time.now - cache_mtime < @max_cache_age
      raise CacheStaleException, ("Cache #{cache_path} is too old (%d - %d < %d)" % [Time.now.to_i, cache_mtime, @max_cache_age]) 
    end
	end
 	
  # Search methods
	
  def programmeIndexAndTypeForPID(pid)
	  populateCachesIfRequired
		if @radio_cache_by_pid[pid]
		  return [@radio_cache_by_pid[pid][0], "radio"]
		elsif @tv_cache_by_pid[pid]
		  return [@tv_cache_by_pid[pid][0], "tv"]
		else
		  nil
		end
	end
	
	def programmeDetailsForPVRSearch(pvrsearch, fields="name,episode")
		populateCachesIfRequired()
		
    Logger.debug(pvrsearch.inspect)
    
    # Add in searching on the 'desc' column if the pvrsearch is so configured
    fields << ",desc" if pvrsearch.descriptionSearch.to_i == 1
    
    Logger.debug("programmeDetailsForPVRSearch searching in fields: #{fields}")
    
		# Turn it into an array
		fields = fields.split(",").map { |x| x.strip }
		checkFields(fields)
		
		if pvrsearch.type == "radio"
			keys = @radio_cache_by_pid.keys
			cache_lookup = @radio_cache_by_pid
		else
			keys = @tv_cache_by_pid.keys
			cache_lookup = @tv_cache_by_pid
		end

    matches = []

		keys.each do |k|
		  line_array = cache_lookup[k]
      index = line_array[@cache_format.index("index")]
			target_score = 0
			match_criteria_score = 0
			
			# Match on categories
			if pvrsearch.category
			  target_score += 1
				if line_array[@cache_format.index("categories")].include?(pvrsearch.category)
					#Logger.debug("Matching on category #{pvrsearch.category}")
					match_criteria_score += 1
				end
			end
			
			# Match on channel if it's defined
			if pvrsearch.channel
				target_score += 1
			  if line_array[@cache_format.index("channel")].include?(pvrsearch.channel)
          #Logger.debug("Matching on channel #{pvrsearch.channel}")
					match_criteria_score += 1
				end
			end
			
			if pvrsearch.searches
			  target_score += pvrsearch.searches.count
				
				pvrsearch.searches.each do |s|
					#Logger.debug("Processing search term #{s[1]}")
				  fields.each do |field|
						#Logger.debug("Processing search field #{field}")
  				  if line_array[@cache_format.index(field)].downcase.include?(s[1].downcase)
						  #Logger.debug("Term '#{s[1]}' found in field #{field} (#{line_array[@cache_format.index(field)]})")
							match_criteria_score += 1
							break
	  				end
					end
				end
				
				if match_criteria_score == target_score
          #Logger.debug("Finished search. Got #{match_criteria_score} / #{target_score} for search on #{pvrsearch.channel} / #{pvrsearch.category} / #{pvrsearch.searchesString}")
          programme_hash = {}
          
          @cache_format.each_with_index do |key, i|
            programme_hash[key] = line_array[i]
          end
          
          matches << programme_hash
        end
			end # end pvrsearch.searches loop
		end # end keys/cached programmes loop
    
    matches
	end # end def
  
  def programmeIndexesForPVRSearch(search)
    matches = programmeDetailsForPVRSearch(search)
    matches.collect { |x| x["index"] }
  end
	
	def checkFields(fields)
		fields.each do |field|
		  raise "Unknown search field #{field}" unless @cache_format.include?(field)
		end
	end
  
  def allChannels(type = 'radio')
    populateCachesIfRequired
    
    if type == 'radio'
      return @radio_channels
      else
      return @tv_channels
    end
  end
  
  def allCategories(type = 'radio')
    populateCachesIfRequired
    
    if type == 'radio'
      return @radio_categories
    else
      return @tv_categories
    end
  end
  
	
end # end class

class CacheNotFoundException < RuntimeError; end
class CacheStaleException < RuntimeError; end
