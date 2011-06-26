# CacheReader.rb
# iCatcher
#
# Created by Nick Ludlam on 15/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class CacheReader
  include Singleton

  attr_accessor :last_cache_update
	
  def initialize
    @max_cache_age = 60 * 60 * 6
  	
    @radio_cache_by_pid = {}
    @tv_cache_by_pid = {}
		
    @parsed_radio_cache_mtime = nil
    @parsed_tv_cache_mtime = nil
		
    @cache_format = %w/index type name pid available episode seriesnum episodenum versions duration desc channel categories thumbnail timeadded guidance web/
  end

  def populateCachesIfRequired
    if @radio_cache_by_pid.empty?
			parseCache("radio")
    end
		
    if @tv_cache_by_pid.empty?
			parseCache("tv")
    end
  end

  def parseCache(type = "radio")
    Logger.debug("Parsing #{type} cache")
    cache_path = cachePathForType(type)
		
    pid_index_number = @cache_format.index("pid")		
    cache_hash = {}
		
    File.open(cache_path) do |f|
      lines = f.readlines()
      comments = lines.shift
      lines.each do |line|
        elements = line.split("|")
        pid = elements[pid_index_number]
        cache_hash[pid] = elements
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
		
    Logger.debug("Finished cache parse. Have #{@radio_cache_by_pid.keys.length} radio entries, and #{@tv_cache_by_pid.keys.length} tv entries")
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
 	
	def cachePathForType(type)
		File.join($downloaderConfigDirectory, "#{type}.cache")
	end

  # Search methods
	
  def programmeIndexForPID(pid)
	  populateCachesIfRequired
		if @radio_cache_by_pid[pid]
		  return [@radio_cache_by_pid[pid][0], "radio"]
		elsif @tv_cache_by_pid[pid]
		  return [@tv_cache_by_pid[pid][0], "tv"]
		else
		  nil
		end
	end
	
	def programmeIndexesForPVRSearch(pvrsearch, fields="name,episode,desc")
		populateCachesIfRequired
		
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
		
		keys.each do |k|
		  line_array = cache_lookup[k]
			match = []
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
  				  if line_array[@cache_format.index(field)].include?(s[1])
						  #Logger.debug("Term '#{s[1]}' found in field #{field} (#{line_array[@cache_format.index(field)]})")
							match_criteria_score += 1
							break
	  				end
					end
				end
				
				#Logger.debug("Finished search. Got #{match_criteria_score} / #{target_score}")
				match << k if match_criteria_score == target_score
			end # end pvrsearch.searches loop
		end # end keys/cached programmes loop
	end # end def
	
	def checkFields(fields)
		fields.each do |field|
		  raise unless @cache_format.include?(field)
		end
	end
	
end # end class

class CacheNotFoundException < RuntimeError; end
class CacheStaleException < RuntimeError; end
