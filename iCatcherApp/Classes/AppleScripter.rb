#
#  AppleScripter.rb
#  iCatcher
#
#  Created by Nick Ludlam on 13/04/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#


class AppleScripter

  def self.subscribeToURL(url)
    Logger.debug("Subscribing to URL #{url} in iTunes")
    activate_command = "osascript -e \"
    tell application \\\"iTunes\\\"
    activate
    set visible of every window to true
    set the view of the front browser window to playlist \\\"Podcasts\\\"
    end tell\""
    activate_output = `#{activate_command}`
    
    subscribe_command = "osascript -e \"
    tell application \\\"iTunes\\\"
    subscribe \\\"#{url}\\\"
    end tell\""
    subscribe_output = `#{subscribe_command}`
  end
  
end