framework 'CoreFoundation'

class PVRSearch
  
  attr_accessor :filename, :displayname, :category, :channel, :type, :searches, :active, :dirty, :unsaved, :descriptionSearch

  HELPER_FILENAME_PATTERN = ".icatcher-subscription-%s"
  
  def self.all
    prefs = NSUserDefaults.standardUserDefaults
    
    allSearches = []
    
    Dir.glob("#{$downloaderSearchDirectory}/*") do |file|
      next if File.basename(file) == "AdHoc"
      #NSLog "Parsing file #{file}"
      searchObj = self.new
      searchObj.load(File.basename(file))
      allSearches << searchObj
    end
    
    allSearches
  end

  def self.load(filename)
    searchObj = self.new
    begin
      searchObj.load(filename)
    rescue
      searchObj = nil
    end 

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
    @descriptionSearch = "0"
	end
  
  def load(filename)
    @filename = filename
    
    re = Regexp.new(/^(\w+)\s+(.*)/)
    
    raise "No such file #{filepath}" unless File.exists?(filepath)
    
    File.open(filepath).each_line do |line|
      next if line.strip.length == 0
      matches = re.match(line)
      # OMG THIS SUCKS
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
    #Logger.debug "Writing to disk"
  
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
      f.write("descriptionSearch #{@descriptionSearch}")
    end
    
    Dir.mkdir(mediaDirectory) unless File.exists?(mediaDirectory)
    
    # Create or rename our visual naming aid as required
    unless File.exists?(nameHelperFilepath())
      Logger.debug("File #{nameHelperFilepath()} doesn't exist. Creating/Moving")
      if old_path = findNameHelperFilepath()
        File.rename(old_path, nameHelperFilepath())
      else
        File.open(nameHelperFilepath(), "w") { |fp| fp.write("") }
      end
    end
    
  
    @unsaved = false
    @dirty = false
  end

  def filepath
    "#{$downloaderSearchDirectory}/#{@filename}"
  end

  # For the dotfile helper
  def nameHelperName
    name = friendly_filename(@displayname)
    (HELPER_FILENAME_PATTERN % name)
  end

  def nameHelperFilepath
    mediaDirectory() + nameHelperName()
  end

  def findNameHelperFilepath
    glob = Dir.glob(mediaDirectory() + (HELPER_FILENAME_PATTERN % "*"))
    glob.empty? ? nil : glob[0]
  end
  
  # For the special case around the searches string in get_iplayer.
  # TODO: Deprecate this, as we're no longer using PVR functionality
  def searchesString
    return nil if @searches.keys.length == 0
    
    terms = []
    @searches.each_pair do |k, v|
      terms << v
    end
    
    terms.join(" ")
  end

  def searchesString=(newSearchesString, split = false)
    #Logger.debug "Setting searches to #{newSearchesString}"

    @dirty = true
    
    @searches = {}
    
    if newSearchesString == nil || newSearchesString.strip.length == 0
      @searches = {}
      return
    end
    
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

  def deleteDownloadedMedia
    Dir.glob(mediaDirectory + "/*").each do |entry|
      File.unlink(entry)
    end
  end
  
  def delete
    return true if @unsaved
    return File.unlink(filepath)
  end

  def url
    "#{$webserverURL}feeds/#{filename}.xml"
  end

  def mediaDirectory
    "#{$downloadDirectory}#{filename}/"
  end

  def friendly_filename(name)
    name.gsub(/[^\w\s_-]+/, '')
    .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
    .gsub(/\s/, '_')
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
    
    output << " Displayname: #{displayname}\n"
    output << " Active: #{active}\n"
    output << " Dirty: #{dirty}\n"
    output << " Unsaved: #{unsaved}\n"
    output << " Description search: #{descriptionSearch}\n"
    
    output
  end
  
end
