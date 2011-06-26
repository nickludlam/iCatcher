framework 'CoreFoundation'

class PVRSearch
  
  attr_accessor :filepath, :filename, :category, :channel, :type, :searches, :dirty, :unsaved

  def self.all
    prefs = NSUserDefaults.standardUserDefaults
    
    allSearches = []
    
    Dir.glob("#{$downloaderSearchDirectory}/*") do |file|
      search = self.new(File.basename(file))
      allSearches << search
    end
    
    allSearches
  end
  
  # INSTANCE METHODS ######################################

  def initialize(search_type = "radio")
    @filename = CFUUIDCreateString(nil, CFUUIDCreate(nil))
    @searches = {}
  
    # Allow blank init
    @type = search_type
    @unsaved = true
    @dirty = true
	end
  
  def load(filename)
    @filepath = File.join($downloaderSearchDirectory, @filename)
    
    re = Regexp.new(/^(\w+)\s+(.*)/)
    File.open(@filepath).each_line do |line|
      next if line.strip.length == 0
      matches = re.match(line)
      if matches[1] =~ /^search/
        next if matches[1] == "search0" && matches[2] == ".*" # Skip over the 'default' search0 term, as we equate an empty @searches with this
        @searches[matches[1]] = matches[2]
        else
        self.send(matches[1].to_s + '=', matches[2])
      end
    end
    
    @unsaved = false
    @dirty = false        
  end

  def save
    Logger.debug "Writing to disk"
  
    if (filepath == nil)
      Logger.error "ERROR: NO filename for this PVRSearch"
      return
    end
  
    return unless @dirty
  
    File.open(filepath, 'w') do |f|
      f.write("category #{@category}\n") if @category != nil
      f.write("channel #{@channel}\n") if @channel != nil
      f.write("type radio\n")
    
      if searches.keys.count > 0
        searches.each_pair { |k,v| f.write("#{k} #{v}\n") }
        else
        f.write("search0 .*\n")
      end
    end
  
    @unsaved = false
    @dirty = false
  end

  
  # Setters / Getters customisation
  
  def filename=(newFilename)
    oldFilepath = @filepath
    @filename = newFilename.gsub(/ +/, "_") # Filename cannot have space at this stage. URL encoding issues etc
    @filepath = "#{$downloaderSearchDirectory}/#{@filename}"
    
    if !@unsaved && oldFilepath != @filepath
      Logger.debug "Renaming #{oldFilepath} => #{@filepath}"
      File.rename(oldFilepath, @filepath)
    end
  end
  
  def searchesString
    return nil if @searches.keys.length == 0
    
    terms = []
    @searches.each_pair do |k, v|
      terms << v
    end
    
    terms.join(" ")
  end

  def searchesString=(newSearchesString, split = false)
    Logger.debug "Setting searches to #{newSearchesString}"

    @dirty = true
    
    @searches = {}
    
    return if newSearchesString.strip.length == 0

    if split
      newSearchesString.split(" ").each do |word|
        suffix = searches.length
        @searches["search#{suffix}"] = word
      end
    else
      @searches["search0"] = newSearchesString.strip
    end
    
    newSearchesString
  end
  
  def unlink
    return if @unsaved
    File.unlink(@filepath)
  end

  # This is used to convert a PVRSearch to json representation
  def to_hash
    { 'filepath' => @filepath,
      'filename' => @filename,
      'category' => @category,
      'channel' =>  @channel,
      'type' =>     @type,
      'searches' => searchesString(),
      'dirty' =>    @dirty,
      'unsaved' =>  @unsaved,
      'isActive' => true
    }
  end

  def update_attributes(attribute_hash)
    self.filename = attribute_hash['filename'] if attribute_hash['filename']
    self.category = attribute_hash['category']
    self.channel = attribute_hash['channel']
    self.searchesString = attribute_hash['searches']
  end
  
  # Debug
  
  def inspect
    output = "PVRSearch\n"
    output << " Filepath: #{filepath}\n"
    output << " Filename: #{filename}\n"
    output << " Category: #{category}\n"
    output << " Channel: #{channel}\n"
    output << " Type: #{type}\n"
    output << " Searches:\n"
    @searches.each_pair do |k, v|
      output << "  | #{k} -> #{v}\n"
    end
    output
  end
  
end
