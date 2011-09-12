# ApplicationController.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.


# Require all our dependencies here for convenience
require 'rubygems'
require 'json'
require 'rack/handler/control_tower'

# Ruby stdlib
require 'erb'
require 'time'
require 'singleton'

# Ruby gems
require 'control_tower'
require 'sinatra'
require 'htmlentities'


# Append our bundled gems to the search path
bundled_gem_path = NSBundle.mainBundle.resourcePath + "/gems/"
Dir.glob("#{bundled_gem_path}/*").each do |dir|
  #puts "Adding #{dir} to our include path"
  $:.unshift(dir)
end


# Some globals for configuration
$homeDirectory = NSHomeDirectory()
$musicDirectory = "#{$homeDirectory}/Music/"
$downloadDirectory = "#{$homeDirectory}/Music/iCatcherDownloads/"
$downloaderConfigDirectory = "#{$homeDirectory}/.icatcher/"
$downloaderSearchDirectory = "#{$downloaderConfigDirectory}/pvr/"
$downloaderAdHocDirectory = "#{$downloadDirectory}/AdHoc/"

$sinatraViewsPath = NSBundle.mainBundle.resourcePath

# Web config
$webserverPort = 8019
$webserverURL = "http://localhost:#{$webserverPort}/"

# Periodicity
$downloadTimerInterval = 6 * 60 * 60


class ApplicationController

  VALID_MODES = [ :idle, :cacheUpdate, :downloading, :stopping ]
  VALID_MODES_DESCRIPTION = { :idle => "Idle", :cacheUpdate => "Updating cache", :downloading => "Downloading", :stopping => "Stopping" }
  
  attr_writer :taskInspectorWindow
	attr_writer :taskInspectorTextView
  attr_writer :subscriptionsEditorWindow
  attr_writer :subscriptionsEditorController
  
  # Return a PID from a URL if it matches what we require
  def self.pidFromURL(url)
    pid = nil
    if url =~ /^http:\/\/www\.bbc\.co\.uk\/iplayer\/episode\//
      components = url.split("/")
      pid = components[5]
    elsif url =~ /^http:\/\/www\.bbc\.co\.uk\/programmes\//
      components = url.split("/")
      pid = components[4]
    end

    pid
  end

  def awakeFromNib
    appDelegate = NSApp.delegate
    appDelegate.appController = self
    
		@defaults = NSUserDefaults.standardUserDefaults
    setupStatusBar()
    checkAndCreateRequiredDirectories()
		startServer()
    
    @taskQueue = []    
    nc = NSNotificationCenter.defaultCenter
    nc.addObserver(self, selector:'taskFinished:', name:'TaskWrapperTaskFinishedNotification', object:nil)
    
    setupTimer()
    
    cacheUpdate()
  end

  def setupTimer()
    if @downloadTimer
      @downloadTimer.invalidate
    end
    
    @downloaderTimer = NSTimer.scheduledTimerWithTimeInterval($downloadTimerInterval, target:self, selector:'runAllSearches:', userInfo:nil, repeats:true)
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

  # Sparkle
  def checkForUpdates(sender = nil)
    Logger.debug("Checking for updates...")
    appDelegate = NSApplication.sharedApplication.delegate
    appDelegate.sparkleUpdater.checkForUpdates(sender) if appDelegate.sparkleUpdater
  end

  
  # Menu contents
  ###########################################################
  def setupMenu(menu)
    @debugmenu = NSMenu.alloc.initWithTitle("Debug")
    @forceCacheUpdateMenuItem = addMenuItemToMenu(@debugmenu, "Force cache update", "forceCacheUpdate")
    addMenuItemToMenu(@debugmenu, "Show activity inspector", "showTaskInspectorWindow")
    addMenuItemToMenu(@debugmenu, "Setup iTunes podcasts", "setupiTunes:")
    
    @activityPhaseMenu = addMenuItemToMenu(menu, "Status: Idle", nil)
    @timeLeftMenuItem = addMenuItemToMenu(menu, "", nil)
    addMenuItemToMenu(menu, nil, nil)
    @editSubscriptionsMenuItem = addMenuItemToMenu(menu, "Edit subscriptions", "showSubscriptionsWindow")
    @startDownloaderMenuItem = addMenuItemToMenu(menu, "Run subscriptions now", "runAllSearches:")
    addMenuItemToMenu(menu, nil, nil)
    
    @debugmenuItem = addMenuItemToMenu(menu, "Debug", nil)
    menu.setSubmenu(@debugmenu, forItem: @debugmenuItem)
    
    addMenuItemToMenu(menu, nil, nil)
    #addMenuItemToMenu(menu, "Preferences", "showPreferencesWindow")
    addMenuItemToMenu(menu, "Check for updates...", "checkForUpdates")
    addMenuItemToMenu(menu, "Quit iCatcher", "quit")
  end

  def findTimerFireTime
    fireDate = @downloaderTimer.fireDate

    formatter = NSDateFormatter.alloc.init
    formatter.dateFormat = "hh:mm a"    
    @timeLeftMenuItem.title = "Next run at #{formatter.stringFromDate(fireDate)}"
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
    NSApp.activateIgnoringOtherApps(true)
    #@taskInspectorWindow.fadeInAndMakeKeyAndOrderFront(true)
    @taskInspectorWindow.makeKeyAndOrderFront(nil)
  end
  
  def showSubscriptionsWindow(sender = nil)
    NSApp.activateIgnoringOtherApps(true)
    @subscriptionsEditorWindow.delegate.becomeActive
    @subscriptionsEditorWindow.makeKeyAndOrderFront(nil)
  end
	
	def setTaskMode(newmode)
    raise unless VALID_MODES.index(newmode)
    @activityPhaseMenu.title = ("Status: %s" % VALID_MODES_DESCRIPTION[newmode])
    
    # If we're transitioning from :downloading -> :idle, reset the timer
    if @taskMode == :downloading && newmode == :idle
      setupTimer()
    end
    
		@taskMode = newmode

		Logger.debug("Starting task mode #{@taskMode}")

    if newmode == :idle
      @startDownloaderMenuItem.setTitle("Check subscriptions now")
      @status_item.view.endAnimation()
      enableTaskWrapperMenuItems()
    elsif newmode == :cacheUpdate
      disableTaskWrapperMenuItems()
      @status_item.view.startAnimation()
      @startDownloaderMenuItem.setTitle("Stop cache update")
    elsif newmode == :downloading
      disableTaskWrapperMenuItems()
      @status_item.view.startAnimation()
      @startDownloaderMenuItem.setTitle("Stop downloads")
    elsif newmode == :stopping
      disableTaskWrapperMenuItems()
    end
    
	end
	
	def taskFinished(notification)
		Logger.debug("taskFinished #{@taskMode}")
    Logger.debug("Notification is #{notification}")
    Logger.debug("UserInfo is #{notification.userInfo.inspect}")
    taskInfo = notification.userInfo
    exitCode = taskInfo["terminationStatus"]
    
    if @taskMode == :stopping
      NSApplication.sharedApplication.delegate.growlMessage(:title => "Download stopped",
                                                            :description => "The download has been stopped",
                                                            :notificationName => "Stopped")

    end
    

		@tw = nil
    
    if exitCode == 0
      self.performSelectorOnMainThread('checkWorkQueue', withObject:nil, waitUntilDone:false)
    else
      Logger.error("Last run exited uncleanly. Halting the queue")
      NSApplication.sharedApplication.delegate.growlError()
      @taskQueue.clear
    end
  end
	
	def disableTaskWrapperMenuItems
		@forceCacheUpdateMenuItem.enabled = false
    @editSubscriptionsMenuItem.enabled = false
	end
	
	def enableTaskWrapperMenuItems
		@forceCacheUpdateMenuItem.enabled = true
    @editSubscriptionsMenuItem.enabled = true
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
    #Logger.debug("Validating #{menuItem.title}")
    true
  end

  def menuWillOpen(menu)
    #Logger.debug("menuWillOpen")
    findTimerFireTime
    
    if @taskInspectorWindow.isVisible || @subscriptionsEditorWindow.isVisible
      NSApp.activateIgnoringOtherApps(nil)
      @taskInspectorWindow.orderFrontRegardless if @taskInspectorWindow.isVisible
      @subscriptionsEditorWindow.orderFrontRegardless if @subscriptionsEditorWindow.isVisible
    end
      
    
    @status_item.view.showHighlightImage = true
    @status_item.view.setNeedsDisplay(true)
  end
  
  #######################
  def menuDidClose(menu)
    @status_item.view.showHighlightImage = false
    @status_item.view.setNeedsDisplay(true)
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
			@s_options = { :port => $webserverPort, :host => '127.0.0.1', :concurrent => false }
			
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
    Dir.mkdir($downloaderAdHocDirectory) unless File.directory?($downloaderAdHocDirectory)
  end
  	
  def downloadFromURL(url)
    @cr = CacheReader.instance
    pid = ApplicationController.pidFromURL(url)
    
    if pid
      index, type = @cr.programmeIndexAndTypeForPID(pid)
      if index
        @taskQueue << [index, type, $downloaderAdHocDirectory]
      end
    else
      @taskQueue << [url]
    end
    
    checkWorkQueue()
  end
  
  def stopAllTasks(sender = nil)
    setTaskMode(:stopping)
    @taskQueue.clear

    if @tw
			@tw.terminate()
    end
  end
	

  def cacheUpdate()
    @cr = CacheReader.instance
    if @cr.cacheStale?("radio")
      @taskQueue << ["updateRadioCache"]
    end
    
    if
      @cr.cacheStale?("tv")
      @taskQueue << ["updateTVCache"]
    end
    
    checkWorkQueue()
  end

  def forceCacheUpdate(sender = nil)
		if @tw
      Logger.debug("Terminating the old task")
		else
      @taskQueue << ["updateRadioCache"]
      @taskQueue << ["updateTVCache"]
		end
    
    checkWorkQueue()
	end

  def runAllSearches(sender = nil)
    if @tw
      stopAllTasks()
      return
    end
    
    return unless @taskQueue.empty?
    cr = CacheReader.instance
    cr.populateCachesIfRequired()
    
    PVRSearch.all.each do |search|
      matches = cr.programmeIndexesForPVRSearch(search)
      # Put them on the queue
      matches.each do |m|
        @taskQueue << [m, search.type, search.mediaDirectory] if search.active
      end
    end
    
    checkWorkQueue()
  end

  # Background work
  def checkWorkQueue(sender = nil)
    return if @tw # Busy already
    
    if @taskQueue.length > 0        
      @tw = TaskWrapper.instance
      @tw.delegate = self

      task = @taskQueue.shift

      # Clear the task inspector contents
      #@taskInspectorTextView.textStorage.mutableString.setString("")

      if task.length == 1 && task[0] == 'updateRadioCache'
        setTaskMode(:cacheUpdate)
        @tw.updateGetIplayerCaches('radio')
      elsif task.length == 1 && task[0] == 'updateTVCache'
        setTaskMode(:cacheUpdate)
        @tw.updateGetIplayerCaches('tv')
      elsif task.length == 1
        @tw.downloadFromURL(task[0], $downloaderAdHocDirectory)
      elsif task.length == 3
        setTaskMode(:downloading)
        index, type, directory = task
        Logger.debug("Downloading index #{index} of type #{type} to dir #{directory}")
        @tw.downloadFromIndex(index, type, directory)
      else
        Logger.error("Unknown task object #{task}")
      end
    else
      #Logger.debug("No work to do")
      setTaskMode(:idle)
    end
  end

  def setupiTunes(sender = nil)
    NSApp.delegate.setupiTunes()
  end
  
end
