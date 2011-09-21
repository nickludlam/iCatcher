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

TIMER_INTERVALS = [6, 12, 24]

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


class ApplicationController

  VALID_MODES = [ :idle, :cacheUpdate, :downloading, :stopping ]
  VALID_MODES_DESCRIPTION = { :idle => "iCatcher is idle",
                              :cacheUpdate => "Updating cache",
                              :downloading => "Searching (#%s)",
                              :stopping => "Stopping" }
  
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
    nc.addObserver(self,
                   selector:'taskFinished:',
                   name:'TaskWrapperTaskFinishedNotification',
                   object:nil)
    
    # Set up the preferences
    @preferencesWindowController = PreferencesController.alloc.initWithWindowNibName("Preferences")    
    @preferencesWindowController.setupPreferences()
    @preferencesWindowController.readPreferences()

    setupStateAccordingToPreferences()
    
    @cr = CacheReader.instance

    @taskMode = :idle
    updateCacheIfRequired()
  end

  def setupStateAccordingToPreferences
    if $preferences['autoSearch']
      Logger.debug("autoSearch enabled")
      setupTimer()
    else
      Logger.debug("autoSearch disabled")
      cancelTimerIfExists()
    end
    
    findTimerFireTime()
  end

  def setupTimer(interval = nil)
    cancelTimerIfExists()
    
    if interval == nil
      interval = TIMER_INTERVALS[$preferences["autoSearchDropdownIndex"]] * 60 * 60
    end
    
    Logger.debug("Timer interval is #{interval}")
    
    @downloadTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target:self, selector:'startStopPVRSearches:', userInfo:nil, repeats:true)
  end
    
  def cancelTimerIfExists()
    if @downloadTimer
      Logger.debug("Cancelling the timer")
      @downloadTimer.invalidate
      @downloadTimer = nil
    end
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
    # Debug sub-menu
    @debugmenu = NSMenu.alloc.initWithTitle("Debug")
    @forceCacheUpdateMenuItem = addMenuItemToMenu(@debugmenu, "Force cache update", "updateCache")
    addMenuItemToMenu(@debugmenu, "Show activity inspector", "showTaskInspectorWindow")
    addMenuItemToMenu(@debugmenu, "Setup iTunes podcasts", "setupiTunes:")
    
    # Main
    @activityPhaseMenu = addMenuItemToMenu(menu, "Status: Idle", nil)
    @timeLeftMenuItem = addMenuItemToMenu(menu, "", nil)
    addMenuItemToMenu(menu, nil, nil)
    @editSubscriptionsMenuItem = addMenuItemToMenu(menu, "Edit subscriptions", "showSubscriptionsWindow")
    @startDownloaderMenuItem = addMenuItemToMenu(menu, "Run now", "startStopPVRSearches:")
    addMenuItemToMenu(menu, nil, nil)
    
    @debugmenuItem = addMenuItemToMenu(menu, "Debug", nil)
    menu.setSubmenu(@debugmenu, forItem: @debugmenuItem)
    
    addMenuItemToMenu(menu, nil, nil)
    addMenuItemToMenu(menu, "Preferences", "showPreferencesWindow", ",")
    addMenuItemToMenu(menu, "Check for updates...", "checkForUpdates")
    addMenuItemToMenu(menu, "Quit iCatcher", "quit")
  end

  def findTimerFireTime
    if @downloadTimer
      fireDate = @downloadTimer.fireDate

      formatter = NSDateFormatter.alloc.init
      formatter.dateFormat = "hh:mm a"    
      @timeLeftMenuItem.title = "Next run at #{formatter.stringFromDate(fireDate)}"
    else
      @timeLeftMenuItem.title = "Automatic search disabled"
    end
  end
  
  def addMenuItemToMenu(menu, menuTitle, methodName, keyEquivalent = "")
    if menuTitle == nil
      newMenuItem = menu.insertItem(NSMenuItem.separatorItem, atIndex:menu.itemArray.length)
    else 
      newMenuItem = menu.addItemWithTitle menuTitle, action:methodName, keyEquivalent:keyEquivalent
      newMenuItem.target = self
      newMenuItem.enabled = true
    end
    
    newMenuItem
  end
	
  # Windows

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

  def showPreferencesWindow(sender = nil)
    NSApp.activateIgnoringOtherApps(true)
    Logger.debug("Prefs window is #{@preferencesWindowController.window}")
    @preferencesWindowController.window.makeKeyAndOrderFront(nil)
  end
	
  # Task business

	def setTaskMode(newmode)
    raise "InvalidTaskMode #{newmode}" unless VALID_MODES.index(newmode)
    
    if @taskMode == :cacheUpdate && newmode == :idle
      @cr.populateCachesIfRequired()
    end
        
		@taskMode = newmode

		Logger.debug("Starting task mode #{@taskMode}")

    if newmode == :idle
      @startDownloaderMenuItem.setTitle("Run now")
      @status_item.view.endAnimation()
      enableTaskWrapperMenuItems()
      setupTimer()
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
    Logger.debug("Notification is #{notification.inspect}")
    Logger.debug("UserInfo is #{notification.userInfo.inspect}")
    taskInfo = notification.userInfo
    exitCode = taskInfo["terminationStatus"]
    
    if @taskMode == :stopping
      NSApp.delegate.growlMessage(:title => "Download stopped",
                                  :description => "The download has been stopped",
                                  :notificationName => "Stopped")
    end
    
		@tw = nil
    
    if exitCode == 0
      appendOutputToTaskInspector("\nTASK FINISHED!\n")
      self.performSelectorOnMainThread('checkWorkQueue', withObject:nil, waitUntilDone:false)
    else
      Logger.error("Last run exited uncleanly. Halting the queue")
      appendOutputToTaskInspector("\nTASK FAILED!\n")
      NSApp.delegate.growlError()
      @taskQueue.clear
      setTaskMode(:idle)
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
    
    if @taskInspectorWindow.isVisible || @subscriptionsEditorWindow.isVisible ||
      @preferencesWindowController.window.isVisible
      NSApp.activateIgnoringOtherApps(nil)
      @taskInspectorWindow.orderFrontRegardless if @taskInspectorWindow.isVisible
      @subscriptionsEditorWindow.orderFrontRegardless if @subscriptionsEditorWindow.isVisible
      @preferencesWindowController.window.orderFrontRegardless if @preferencesWindowController.window.isVisible
    end
        
    activity_count = @taskQueue.length + 1
    @activityPhaseMenu.title = VALID_MODES_DESCRIPTION[@taskMode] % activity_count
    
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
    if @currentTask
      if @currentTask.url == url
        Logger.debug("That's the current download!")
        return "Download is already in progress"
      end
    end

    Logger.debug("Enqueueing URL")

    if @taskQueue.length > 0
      status = "Queued up for download"
    else
      status = "Starting the download now"
    end

    @taskQueue << Task.downloadFromURL(url)
    self.performSelectorOnMainThread("checkWorkQueue", withObject:nil, waitUntilDone:false)
    
    status
  end
      
  def stopAllTasks(sender = nil)
    setTaskMode(:stopping)
    @taskQueue.clear

    if @tw
			@tw.terminate()
    end
  end
	
  def checkQueueForIndex(searchIndex)
    @taskQueue.each do |entry|
      if entry.is_a?(Array) and entry.length == 3
        index = entry[0]
        return true if searchIndex == index
      end
    end
    false
  end

  
  def updateCache(sender = nil)
    ["radio", "tv"].each do |mediatype|
      Logger.debug("Adding cacheUpdateTask(#{mediatype}) to the taskQueue")
      @taskQueue << Task.cacheUpdate(mediatype) 
    end
    
    checkWorkQueue()
  end

    
  def updateCacheIfRequired(sender = nil)    
    ["radio", "tv"].each do |mediatype|
      if @cr.cacheStale?(mediatype)
        Logger.debug("Adding cacheUpdate(#{mediatype}) to the taskQueue")
        @taskQueue << Task.cacheUpdate(mediatype) 
      end
    end
    
    checkWorkQueue()
  end

  # Either starts or stops a download session
  def startStopPVRSearches(sender = nil)
    if @tw
      Logger.debug("Stopping the running task")
      stopAllTasks()
      return
    end
    
    # So we don't accidentally have the timer cancel us!
    cancelTimerIfExists()
    
    # Update the caches if they're stale
    updateCacheIfRequired()
    
    PVRSearch.all.each do |search|
      @taskQueue << Task.downloadFromPVRSearch(search)
    end
    
    checkWorkQueue()
  end

  # Background work
  def checkWorkQueue(sender = nil)
    if @tw # Busy already
      Logger.debug("Busy")
      return
    elsif @taskQueue.length == 0
      Logger.debug("Empty")
      setTaskMode(:idle)
      return
    end
    

    # Get the next item to work with
    @currentTask = @taskQueue.shift
    Logger.debug("Processing task #{@currentTask}")

    # We don't need an @tw if we are unpacking a pvrsearch
    unless @currentTask.mode == :pvrsearch
      @tw = TaskWrapper.instance
      @tw.delegate = self
    end

    # Clear the task inspector contents
    @taskInspectorTextView.textStorage.mutableString.setString("")

    # Bring up the taskInspectorWindow if we need to according to the prefs
    showTaskInspectorWindow() if $preferences['autoShowActivityWindow']
      
    if @currentTask.mode == :cacheUpdate
      setTaskMode(:cacheUpdate)
      @tw.updateGetIplayerCaches(@currentTask.type)
    elsif @currentTask.mode == :url
      Logger.debug("Downloading from url #{@currentTask.url}")
      issueWorkForURLTask(@currentTask)
    elsif @currentTask.mode == :pvrsearch
      # Unpack the PVRSearch into a series of indexes
      @cr.programmeIndexesForPVRSearch(@currentTask.pvrsearch).each do |index|
        Logger.debug("Adding index #{index} to @taskQueue for pvrSearch #{@currentTask.pvrsearch.displayname}")
        @taskQueue << Task.downloadFromIndex(index, @currentTask.pvrsearch.type, @currentTask.pvrsearch.mediaDirectory)
      end
      checkWorkQueue()
    elsif @currentTask.mode == :index
      Logger.debug("Downloading index #{@currentTask.index} of type #{@currentTask.type} to dir #{@currentTask.directory}")
      setTaskMode(:downloading)
      @tw.downloadFromIndex(@currentTask.index, @currentTask.type, @currentTask.directory)
    else
      Logger.error("Unknown task object #{@currentTask}")
    end
  end

  def issueWorkForURLTask(task)
    pid = ApplicationController.pidFromURL(task.url)
    
    if pid
      Logger.debug("Found a pid for url #{task.url}")
      index, type = @cr.programmeIndexAndTypeForPID(pid)
      if index
        Logger.debug("Found a current programme index for pid #{pid}")
        setTaskMode(:downloading)
        @tw.downloadFromIndex(index, type, $downloaderAdHocDirectory)
        else
        Logger.debug("Could not find a programme index for pid #{pid}. Passing to get_iplayer")
        setTaskMode(:downloading)
        @tw.downloadFromURL(task.url)
      end
    else
      Logger.debug("Could not find a pid for the given URL. Passing to get_iplayer")
      setTaskMode(:downloading)
      @tw.downloadFromURL(task.url)
    end
  end


  # Misc methods

  def setupiTunes(sender = nil)
    NSApp.delegate.setupiTunes()
  end

  # Sleep / Wake notifications

  def receiveSleepNote(notification)
    Logger.debug("Zzzzz")
  end

  def receiveWakeNote(notification)
    Logger.debug("Whaaa?!")
    #setupTimer
  end

  def setupSleepWakeNotifications()
    NSWorkspace.sharedWorkspace.notificationCenter.addObserver(self, selector:"receiveSleepNote:", name: NSWorkspaceWillSleepNotification, object: nil)
    NSWorkspace.sharedWorkspace.notificationCenter.addObserver(self, selector:"receiveWakeNote:", name: NSWorkspaceDidWakeNotification, object: nil)
  end
end
