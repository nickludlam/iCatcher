# ApplicationController.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.


framework 'Cocoa'
framework 'Sparkle'

# Require all our dependencies here for convenience
require 'rubygems'
require 'control_tower'
#require 'rack'
require 'rack/handler/control_tower'
require 'sinatra'
require 'htmlentities'
require 'json'

# Ruby stdlib
require 'erb'
require 'time'
require 'singleton'


# Append our bundled gems to the search path
bundled_gem_path = NSBundle.mainBundle.resourcePath + "/gems/"
Dir.glob("#{bundled_gem_path}/*").each do |dir|
  #puts "Adding #{dir} to our include path"
  $:.unshift(dir)
end

# Our bundled gems


# Some globals for configuration
$homeDirectory = NSHomeDirectory()
$musicDirectory = "#{$homeDirectory}/Music/"
$downloadDirectory = "#{$homeDirectory}/Music/iCatcherDownloads/"
$downloaderConfigDirectory = "#{$homeDirectory}/.icatcher/"
$downloaderSearchDirectory = "#{$downloaderConfigDirectory}/pvr/"

$sinatraViewsPath = NSBundle.mainBundle.resourcePath

# Web config
$webserverPort = 8010
$webserverURL = "http://localhost:#{$webserverPort}/"

# Periodicity
$downloadTimerInterval = 6 * 60


MODE_IDLE = 

class ApplicationController

  VALID_MODES = [ :idle, :updating_cache, :downloading ]
  VALID_MODES_DESCRIPTION = { :idle => "Idle", :updating_cache => "Updating data", :downloading => "Downloading" }
  
  attr_writer :taskInspectorWindow
	attr_writer :taskInspectorTextView
  attr_writer :preferencesWindow
  
  def awakeFromNib
    #
		@defaults = NSUserDefaults.standardUserDefaults
    setupStatusBar()
    checkAndCreateRequiredDirectories()
		startServer()
    setMode(:idle)
  end
    
  def setupStatusBar
    @status_bar = NSStatusBar.systemStatusBar()
    @status_item = @status_bar.statusItemWithLength(NSVariableStatusItemLength)
    
    # The menu
    @menu = NSMenu.alloc.initWithTitle("Main Menu")
    @menu.setDelegate(self)
    @status_item.setMenu(@menu)
    
    f = CGRectMake(0, 0, 30, 21)
    @status_item.view = ActiveStatusItem.alloc.initWithFrame(f)
    @status_item.view.delegate = self
    @status_item.view.setupDragEvents()
    @status_item.view.enclosingStatusItem = @status_item
    @status_item.view.enclosingMenu = @menu

    setupMenu(@status_item.menu)
  end
  
  # Menu contents
  ###########################################################
  def setupMenu(menu)
    addMenuItemToMenu(menu, "iCatcher BETA", nil)
    @timeLeftMenuItem = addMenuItemToMenu(menu, "", nil)
    @activityPhaseMenu = addMenuItemToMenu(menu, "Status: Idle", nil)
    addMenuItemToMenu(menu, nil, nil)
    
    @startDownloaderMenuItem = addMenuItemToMenu(menu, "Run iCatcher now", "startStopDownloaderLoop:")
    @setupItunesMenuItem = addMenuItemToMenu(menu, "Setup iTunes Podcasts", "performITunesSubscriptions")
    addMenuItemToMenu(menu, nil, nil)
    addMenuItemToMenu(menu, "Open task inspector", "showTaskInspectorWindow")
    @forceCacheUpdateMenuItem = addMenuItemToMenu(menu, "Force cache update", "forceCacheUpdate")
    addMenuItemToMenu(menu, nil, nil)
    #addMenuItemToMenu(menu, "Preferences", "showPreferencesWindow")
    #addMenuItemToMenu(menu, "Check for updates...", "checkForUpdates")
    addMenuItemToMenu(menu, "Quit", "quit")
  end
  
  def addMenuItemToMenu(menu, menuTitle, methodName)
    if menuTitle == nil
      newMenuItem = menu.insertItem(NSMenuItem.separatorItem, atIndex:menu.itemArray.length)
    else 
      newMenuItem = menu.addItemWithTitle menuTitle, action:methodName, keyEquivalent:""
      newMenuItem.target = self
      newMenuItem.enabled = true
    end
    
    newMenuItem
  end
	
	# Task business
  
  def showTaskInspectorWindow(sender = nil)
    NSApplication.sharedApplication.activateIgnoringOtherApps true
    @taskInspectorWindow.fadeInAndMakeKeyAndOrderFront(true)
  end
  
  def setMode(mode)
    
      #raise unless VALID_MODES.index?(mode)
    @activityPhaseMenu.title = ("Status: %s" % VALID_MODES_DESCRIPTION[mode])
  end
	
	def startTaskMode(mode)
		@taskMode = mode

		Logger.debug("Starting task mode #{@taskMode}")
		@status_item.view.startAnimation()

		# By default, turn off all the menu items which could interfere
		disableTaskWrapperMenuItems()

    if mode == "idle"
      
    elsif mode == "updateCache"
		
    elsif mode == "updateCacheAndDownloadURL"
		
    end
    
		# Clear the task inspector contents
		@taskInspectorTextView.textStorage.mutableString.setString("")

		nc = NSNotificationCenter.defaultCenter
    nc.addObserver(self, selector:'endTaskMode:', name:'TaskWrapperTaskFinishedNotification', object:nil)
	end
	
	def endTaskMode(sender = nil)
		Logger.debug("endTaskMode #{@taskMode}")

		if @taskMode == "updateCache"
		elsif @taskMode == "updateCacheAndDownloadURL"
			findAndDownloadPid(@pidToDownload)
		end
		
		@taskMode = nil
		NSNotificationCenter.defaultCenter.removeObserver(self)
		@tw = nil
		enableTaskWrapperMenuItems()
		@status_item.view.endAnimation()
	end
	
	def disableTaskWrapperMenuItems
		@startDownloaderMenuItem.enabled = false
		@forceCacheUpdateMenuItem.enabled = false
	end
	
	def enableTaskWrapperMenuItems
		@startDownloaderMenuItem.enabled = false
		@forceCacheUpdateMenuItem.enabled = true
	end

	def appendOutputToTaskInspector(output)		
		start = @taskInspectorTextView.textStorage.mutableString.length
		@taskInspectorTextView.textStorage.mutableString.appendString(output)
		length = @taskInspectorTextView.textStorage.length()
		@taskInspectorTextView.setTextColor(NSColor.whiteColor(), range:NSRange.new(start, length-start))
    range = NSRange.new(length, 0)
    @taskInspectorTextView.scrollRangeToVisible(range)
	end

  # Menu delegate methods?  
	###########################################################
	
  def validateMenuItem(menuItem)
    Logger.debug("Validating #{menuItem.title}")
    true
  end

  def menuWillOpen(menu)
    Logger.debug("menuWillOpen")
    #fireDate = @downloaderTimer.fireDate
    #formatter = NSDateFormatter.alloc.init
    #formatter.dateFormat = "HH:mm"
    #@timeLeftMenuItem.title = "Dummy title"
    #@timeLeftMenuItem.title = "Next run: #{formatter.stringFromDate(fireDate)}"
    
    
    @status_item.view.showHighlightImage = true
    @status_item.view.setNeedsDisplay(true)
  end
  
  #######################
  def menuDidClose(menu)
    @status_item.view.showHighlightImage = false
    @status_item.view.setNeedsDisplay(true)
  end
  
  
  
  # ActiveStatusItem delegate methods
  ###########################################################
  
  def urlAndTitleDropped(url, title)
    @urlToDownload = url
		Logger.debug("URL is #{url}")
		
		if url =~ /^http:\/\/www\.bbc\.co\.uk\/iplayer\/episode\//
			components = url.split("/")
			pid = components[5]
			findAndDownloadPid(pid)
    elsif url =~ /^http:\/\/www\.bbc\.co\.uk\/programmes\//
      components = url.split("/")
      pid = components[4]
      findAndDownloadPid(pid)
		end
		
    showTaskInspectorWindow()
  end

  
  # Control Tower
  ###########################################################
  
  def startServer
    @webserverThread = NSThread.alloc.initWithTarget self, selector:'startServerThreaded', object:nil
    @webserverThread.start
  end
    
  def startServerThreaded
    begin
			Logger.debug("Starting control tower thread")
			pool = NSAutoreleasePool.alloc.init
			
      sleep(2)
			@s_options = { :port => $webserverPort, :host => '127.0.0.1', :concurrent => true }
			
			app = Rack::Builder.new do
				map "/" do run SinatraApp.new end
				map "/files" do run Rack::File.new($downloadDirectory) end
				map "/resources" do run Rack::File.new(NSBundle.mainBundle.resourcePath) end
			end.to_app

			Rack::Handler::ControlTower.run(app, @s_options) do |s|
				Logger.error("Couldn't build CT server") unless s
			end
			
		rescue => e
		  Logger.debug("Got an exception in the webserver thread? #{e.inspect}")
		ensure
			pool.release
		end
  end

  # Window delegate methods
  ############################################################
 
  def windowShouldClose(sender)
    if sender == @downloaderOutputWindow
      sender.fadeOutAndOrderOut(true)
      false
    else
      true
    end
  end
	
	def quit(sender = nil)
		@tw.terminate() if @tw
		@defaults.synchronize
		NSApplication.sharedApplication.terminate(self)
	end
  
  # Directories and whatnot
	############################################################
	def checkAndCreateRequiredDirectories
    Dir.mkdir($downloadDirectory) unless File.directory?($downloadDirectory)
    Dir.mkdir($downloaderConfigDirectory) unless File.directory?($downloaderConfigDirectory)
    Dir.mkdir($downloaderSearchDirectory) unless File.directory?($downloaderSearchDirectory)
  end
  
  def checkAndCreateDownloadDirectoryForSearch(pvrSearchName)
    pvrSearchDownloadDirectory = "#{$downloadDirectory}/#{pvrSearchName}"    
    Dir.mkdir(pvrSearchDownloadDirectory) unless File.directory?(pvrSearchDownloadDirectory)
  end
	
	def findAndDownloadPid(pid)
		Logger.debug("Finding and downloading #{pid}")
		@pidToDownload = pid

		@cr = CacheReader.instance
		begin
			@cr.testCache("radio")
			@cr.testCache("tv")
      # Try radio first
			index, type = @cr.programmeIndexForPID(pid)
      
      if index
        @tw = TaskWrapper.instance
        @tw.delegate = self
        startTaskMode("downloadPID")
        @tw.downloadFromIndex(index, type, $musicDirectory)
      else
        @tw = TaskWrapper.instance
        @tw.delegate = self
        startTaskMode("downloadURL")
        @tw.downloadFromURL(@urlToDownload, $musicDirectory)
        Logger.debug("Attepmting direct URL download")
      end
		rescue RuntimeError => e
			Logger.debug("Got an exception #{e}")
			startTaskMode("updateCacheAndDownloadURL")
			forceCacheUpdate()
		end
	end
	
	def forceCacheUpdate(sender = nil)
		if @tw
			@tw.terminate()
		else
			@tw = TaskWrapper.instance
			@tw.delegate = self
			startTaskMode("updateCache") unless @taskMode
			@tw.updateGetIplayerCaches("radio")
			@tw.updateGetIplayerCaches("tv")
		end
	end
  
end
