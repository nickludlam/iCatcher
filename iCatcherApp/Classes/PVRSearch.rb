framework 'CoreFoundation'

class PVRSearch
  
  attr_accessor :filename, :displayname, :category, :channel, :type, :searches, :active, :dirty, :unsaved

  def self.all
    prefs = NSUserDefaults.standardUserDefaults
    
    allSearches = []
    
    Dir.glob("#{$downloaderSearchDirectory}/*") do |file|
      NSLog "Parsing file #{file}"
      searchObj = self.new
      searchObj.load(File.basename(file))
      allSearches << searchObj
    end
    
    allSearches
  end

  def self.load(filename)
    searchObj = self.new
    searchObj.load(filename)
    searchObj
  end
  
  # INSTANCE METHODS ######################################

  def initialize(search_type = "radio")
    @filename = CFUUIDCreateString(nil, CFUUIDCreate(nil))
    @searches = {}
  
    # Allow blank init
    @displayname = "New subscription"
    @type = search_type
    @unsaved = true
    @dirty = true
    @active = "1"
	end
  
  def load(filename)
    @filename = filename
    
    re = Regexp.new(/^(\w+)\s+(.*)/)
    
    puts "No such file #{filepath}" unless File.exists?(filepath)
    
    File.open(filepath).each_line do |line|
      next if line.strip.length == 0
      matches = re.match(line)
      if matches[1] =~ /^search/
        next if matches[1] == "search0" && matches[2] == ".*" # Skip over the 'default' search0 term, as we equate an empty @searches with this
        @searches[matches[1]] = matches[2]
      else
        self.send(matches[1] + '=', matches[2])
      end
    end
    
    # In case we dont have one
    if @displayname == nil
      displayname = "Unnamed"
    end
    
    @unsaved = false
    @dirty = false        
  end

  def save
    Logger.debug "Writing to disk"
  
    if (@filename == nil)
      Logger.error "ERROR: No filename for this PVRSearch"
      return false
    end
  
    return true unless @dirty
  
    File.open(filepath, 'w') do |f|
      f.write("category #{@category}\n") if @category != nil
      f.write("channel #{@channel}\n") if @channel != nil
      f.write("type #{@type}\n")
    
      if searches.keys.count > 0
        searches.each_pair { |k,v| f.write("#{k} #{v}\n") }
        else
        f.write("search0 .*\n")
      end
      
      f.write("displayname #{@displayname}\n")      
      f.write("active #{@active}\n")
    end
  
    @unsaved = false
    @dirty = false
  end

  def filepath
    "#{$downloaderSearchDirectory}/#{@filename}"
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
  
  def delete
    return false if @unsaved
    return File.unlink(filepath)
  end

  def update_attributes(attribute_hash)
    self.filename = attribute_hash['filename'] if attribute_hash['filename']
    self.category = attribute_hash['category']
    self.channel = attribute_hash['channel']
    self.searchesString = attribute_hash['searches']
    self.active = attribute_hash['active']
    self.displayname = attribute_hash['displayname']
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
