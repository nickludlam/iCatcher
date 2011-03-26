# Logger.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.

class Logger
  def self.debug(msg)
    puts("DEBUG: #{msg}")
  end
  
  def self.info(msg)
    puts("INFO: #{msg}")
  end

  def self.error(msg)
    puts("ERROR: #{msg}")
  end
  
  def self.fatal(msg)
    puts("FATAL: #{msg}")
  end
  
end