#
#  PreferencesController.rb
#  iCatcher
#
#  Created by Nick Ludlam on 18/09/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#


class PreferencesController < NSWindowController
  PREFERENCE_KEYPATHS = %w(autoSearch autoSearchDropdownIndex autoDelete autoDeleteDropdownIndex sendGrowlNotifications syncImmediately autoShowActivityWindow verboseOutput)
  
  def windowDidLoad
    Logger.debug("PreferencesController windowDidLoad")
    registerKVO
  end
  
  def setupPreferences
    @defaults = NSUserDefaults.standardUserDefaults
    
    # Set up defaults
    preferences_path = NSBundle.mainBundle.pathForResource("Defaults", ofType:"plist")
    preferences_dictionary = NSDictionary.dictionaryWithContentsOfFile(preferences_path)
    @defaults.registerDefaults(preferences_dictionary)
  end
  
  def readPreferences
    # Read em in
    $preferences = {}
    
    PREFERENCE_KEYPATHS.each do |key|
      if key =~ /DropdownIndex/
        $preferences[key] = @defaults.integerForKey(key)
      else
        $preferences[key] = @defaults.boolForKey(key)
      end
    end
    
    Logger.debug("Read prefs are #{$preferences.inspect}")
  end
  
  def registerKVO
    PREFERENCE_KEYPATHS.each do |path|
      @defaults.addObserver(self,
                            forKeyPath:path,
                            options:NSKeyValueObservingOptionNew,
                            context:nil)

    end
  end

  # Save on close
  def windowWillClose(notification)
    Logger.debug("PreferencesController windowWillClose")

    # Make the state changes in the main AppController
    NSApp.delegate.appController.setupStateAccordingToPreferences()
  end

  def observeValueForKeyPath(aKey, ofObject:anObject, change:ch, context:ctx)
    NSLog("The value of #{aKey} changed to #{anObject.valueForKey(aKey)} (#{ch})")
    
    if PREFERENCE_KEYPATHS.index(ch["new"])
      Logger.debug("Got a new value of #{ch['new']} for #{aKey}")
      $preferences[aKey] = ch["new"]
      NSUserDefaults.standardUserDefaults.synchronize()
    end
  end  

end