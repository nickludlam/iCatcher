#
#  AppDelegate.rb
#  iCatcher
#
#  Created by Nick Ludlam on 27/03/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#

class AppDelegate
  def applicationDidFinishLaunching(a_notification)
    # Insert code here to initialize your application
    Logger.debug("appDidFinishLaunching")
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

  
end
