# TaskWrapper.rb
# iCatcher
#
# Created by Nick Ludlam on 15/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class TaskWrapper
  include Singleton
	
	attr_accessor :debug, :delegate, :verbose
	
	def initialize
		@task = nil
		@taskPipe = nil
  	@taskPipeFileHandle = nil
	end
	
	def busy?
    Logger.debug("Task is #{@task}")
	  return @task != nil
	end
  
  def baseArgs()
    args = []
    args << "--thumb" # We want thumbnails of images down as well
    args << "--thumbsize=4" # Big thumbs!
    args << "--hash" # Print progress
    args << "--nopurge" # we do the purging ourselves
    args << "--tag-fulltitle"
    args << "--profile-dir=#{$downloaderConfigDirectory}"
    args << "--packagemanager=disable"
    args << "--verbose" if $preferences['verboseOutput']
    args << "--debug" if $preferences['verboseOutput']
    args
  end
  
  def baseEnvironment(hash = {})
    bundled_executable_path = NSBundle.mainBundle.resourcePath
    environmentDictionary = { "PATH" => "#{bundled_executable_path}:/usr/bin:/bin:/usr/sbin:/sbin",
                              "HOME" => $homeDirectory,
                              "IPLAYER_OUTDIR" => $downloadDirectory }.merge(hash)
    environmentDictionary
  end
  
  def downloadFromURL(url, directory = $downloaderAdHocDirectory, force = false)
    Logger.debug("Starting downloader with URL #{url}, force #{force}")
    
		@task = NSTask.alloc.init
		downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)
    
    args = baseArgs()
    
    args << "--force" if force
    
    args << "--url"
    args << url
    args << " 2>&1"
    
    environmentDictionary = baseEnvironment({"IPLAYER_OUTDIR" => directory})
    invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
  end
  	
	def downloadFromIndex(index, type = "radio", directory = $downloadDirectory, force = false)
    Logger.debug("Too busy to update the cache") && return if busy?
    Logger.debug("Starting download of index #{index}, type #{type}, force #{force}")
    
		@task = NSTask.alloc.init
		downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)

    args = baseArgs()
        
    if type == "radio"
      args << "--type"
      args << "radio"
      args << "--modes"
      args << "flashaachigh,flashaacstd"
    elsif type == "tv"
      args << "--type"
      args << "tv"
      args << "--modes"
      args << "flashvhigh,flashhigh"
    end
    
    args << "--force" if force
    
    args << "--get"
    args << index
    args << " 2>&1"

    environmentDictionary = baseEnvironment({"IPLAYER_OUTDIR" => directory})
    invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
  end
	
  def updateGetIplayerCaches(type = "radio")
		Logger.debug("Too busy to update the cache") && return if busy?
		
    Logger.debug("Refreshing get_iplayer #{type} cache")
    @task = NSTask.alloc.init
		
    downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)
    
    args = baseArgs()    
    args << "--type=#{type}"
    args << "--refresh"
    args << " 2>&1"

    environmentDictionary = baseEnvironment()

    invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
  end
	
  def invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
    Logger.debug("Invoking iPlayer")
    Logger.debug("args: #{args}")
    Logger.debug("env:  #{environmentDictionary}")
    
    @task.setArguments(args)
    @task.setEnvironment(environmentDictionary)
    @task.setCurrentDirectoryPath($downloadDirectory)
    
    @taskPipe = NSPipe.alloc.init
    @task.setStandardOutput(@taskPipe)
    @task.setStandardError(@taskPipe)
  
    taskPipeFileHandle = @taskPipe.fileHandleForReading

    nc = NSNotificationCenter.defaultCenter
    nc.addObserver(self, selector:'taskPipeDataReady:', name:NSFileHandleReadCompletionNotification, object:taskPipeFileHandle)
    nc.addObserver(self, selector:'taskTerminated:', name:NSTaskDidTerminateNotification, object:@task)
    
		NSNotificationCenter.defaultCenter.postNotificationName('TaskWrapperTaskStartedNotification', object:nil)

    @task.launch
    Logger.debug("Launched task")
    
    taskPipeFileHandle.readInBackgroundAndNotify
  end

  def taskPipeDataReady(notification)
		data = notification.userInfo.valueForKey(NSFileHandleNotificationDataItem)
		
		if (data.length > 0)
		  #Logger.debug("Data to read!")
      output = NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding)
			
			delegate.appendOutputToTaskInspector(output) if delegate && delegate.respondsToSelector('appendOutputToTaskInspector:')
  		#Logger.debug(output)
		
      if @task
		    #Logger.debug("Fetching more...")
			  notification.object.readInBackgroundAndNotify()
      end
		else
		  Logger.debug("Data is zero!")
		  taskTerminated()
		end
  end

  def taskTerminated(notification = nil)
    Logger.debug("Task finished with notification #{notification}")    
    Logger.debug("Exit code is #{@task.terminationStatus}")
    taskFinishedMetadata = { 'terminationStatus' => @task.terminationStatus }
      
    NSNotificationCenter.defaultCenter.postNotificationName('TaskWrapperTaskFinishedNotification', object:self, userInfo:taskFinishedMetadata)

    nc = NSNotificationCenter.defaultCenter
    nc.removeObserver(self)

    @task = nil
    @taskPipe = nil
    @taskPipeFileHandle = nil
  end
	
	# Forcefully kill it if needed
  def terminate(signal = :TERM)
    Process.kill(signal, @task.processIdentifier) if @task.isRunning
  end
  
end