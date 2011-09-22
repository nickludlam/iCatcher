#
#  AppDelegate.rb
#  iCatcher
#
#  Created by Nick Ludlam on 27/03/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#

framework 'Sparkle' #unless $0 =~ /macirb/ or $0 =~ /macrake/


class AppDelegate
  
  attr_accessor :appController, :sparkleUpdater
  
  def applicationDidFinishLaunching(a_notification)
    # Insert code here to initialize your application
    Logger.debug("appDidFinishLaunching")

    setupSparkle()
    setupAndRegisterGrowl() if $preferences["sendGrowlNotifications"]
  end
  
  def registerSavedSearchesIfNeeded
    prefs = NSUserDefaults.standardUserDefaults
  
    existing_prefs = prefs.objectForKey('savedSearches')
  
    Logger.debug("Existing prefs = %@", existing_prefs)
  
    prefs_dictionary = {
      'savedSearches' => [],
    }
    
    prefs.registerDefaults(prefs_dictionary)
  end
  
  def setupSparkle
    @sparkleUpdater = SUUpdater.alloc.init
  end
  
  def setupAndRegisterGrowl
    GrowlApplicationBridge.setGrowlDelegate self
    growlStartup
  end

  def growlStartup
    growlMessage(:title => "iCatcher started",
                 :description => "iCatcher is now running from the Menubar",
                 :notificationName => "Started")
  end
  
  def growlDownloadedFileCount(count)
    fileCountPlural = (count > 1) ? "files" : "file"
    growlMessage(:title => "New downloads",
                 :description => "iCatcher has downloaded #{count} new #{fileCountPlural}",
                 :notificationName => "NewFiles")
  end
  
  def growlError()
    growlMessage(:title => "Download error",
                 :description => "The last download finished uncleanly. Downloading has been halted",
                 :notificationName => "Error",
                 :clickContext => "Error")
  end
  
  def growlMessage(params = {})
    GrowlApplicationBridge.notifyWithTitle(params[:title],
                                           description: params[:description],
                                           notificationName: params[:notificationName],
                                           iconData: nil,
                                           priority: 0,
                                           isSticky: false,
                                           clickContext: params[:clickContext]
                                           ) if $preferences["sendGrowlNotifications"]
  end
  
  # Applescript
  def setupiTunes(sender = nil)
    PVRSearch.all.each do |s|
      AppleScripter.subscribeToURL(s.url)
    end
    
    # Last is the ad hoc feed
    # FIXME: This needs to be shared information somewhere 
    AppleScripter.subscribeToURL("#{$webserverURL}adhoc_feed.xml")
  end

  def updateiTunes(sender = nil)
    AppleScripter.updateiTunes()
  end
  
  # If we have any sort of error, show the task inspector view
  def growlNotificationWasClicked(clickContext)
    if clickContext == "Error"
      appController.showTaskInspectorWindow()
    end
  end
    
end
