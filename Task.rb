#
#  Task.rb
#  iCatcher
#
#  Created by Nick Ludlam on 19/09/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#


class Task
  
  attr_accessor :mode
  attr_accessor :type
  attr_accessor :url
  attr_accessor :index
  attr_accessor :directory
  attr_accessor :pvrsearch
  
  def self.cacheUpdate(type)
    task = Task.new
    task.mode = :cacheUpdate
    task.type = type
    task
  end

  def self.downloadFromPVRSearch(search)
    task = Task.new
    task.mode = :pvrsearch
    task.pvrsearch = search
    task.directory = search.mediaDirectory
    task
  end

  def self.downloadFromIndex(index, type, directory)
    task = Task.new
    task.mode = :index
    task.type = type
    task.index = index
    task.directory = directory
    task
  end

  def self.downloadFromURL(url)
    task = Task.new
    task.mode = :url
    task.url = url
    task
  end

  def to_s
    "Task: mode #{@mode}, type #{@type}, url #{@url}, index #{@index}, directory #{@directory}, pvrsearch #{@pvrsearch}"
  end
  
end