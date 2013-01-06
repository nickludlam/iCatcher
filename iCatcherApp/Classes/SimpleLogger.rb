# SimpleLogger.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.

class Logger

  @@levels = ['debug', 'info', 'error', 'fatal']
  @@currentLevel = 0

  def self.setLevel(level)
    if level.is_a?(String)
      @@currentLevel = @@levels.index(level)
    elsif level.is_a?(Fixnum) and level < @@levels.size
      @@currentLevel = level
    end
  end
  
  def self.shouldLog(level)
    return @@currentLevel <= @@levels.index(level)
  end
  
  def self.debug(msg)
    puts("DEBUG: #{msg}") if shouldLog('debug')
  end
  
  def self.info(msg)
    puts("INFO: #{msg}") if shouldLog('info')
  end

  def self.error(msg)
    puts("ERROR: #{msg}") if shouldLog('error')
  end
  
  def self.fatal(msg)
    puts("FATAL: #{msg}") if shouldLog('fatal')
  end
  
end