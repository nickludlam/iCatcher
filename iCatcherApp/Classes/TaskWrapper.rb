# TaskWrapper.rb
# iCatcher
#
# Created by Nick Ludlam on 15/03/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class TaskWrapper
  include Singleton
	
	attr_accessor :debug, :delegate
	
	def initialize
		@task = nil
		@taskPipe = nil
  	@taskPipeFileHandle = nil
	end
	
	def busy?
	  return @task != nil
	end
	
	def runPvrSearch(pvrSearchFilename)
    Logger.debug("Starting downloader against #{pvrSearchFilename}")
    
		@task = NSTask.alloc.init
		downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)

    args = []
    args << "--thumb" # We want thumbnails of images down as well
    args << "--thumbsize=4" # Big thumbs!
    args << "--hash" # Print progress
    args << "--long" # Match on name+episode+desc
    args << "--pvr-single=#{pvrSearchFilename}" #Execute our specific PVR search
    args << "--modes"
    args << "flashaachigh,flashaacstd"
		args << "--force"
    args << "--debug" if @debug
    
    bundled_executable_path = NSBundle.mainBundle.resourcePath
    environmentDictionary = { "PATH" => "#{bundled_executable_path}:/usr/bin:/bin:/usr/sbin:/sbin",
                              "HOME" => $homeDirectory,
                              "IPLAYER_OUTDIR" => $downloadDirectory + "/" + pvrSearchFilename }

    invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
  end
	
	def downloadFromIndex(index, type = "radio", directory = $downloadDirectory)
    Logger.debug("Too busy to update the cache") && return if busy?

    Logger.debug("Starting download of index #{index}")
    
		@task = NSTask.alloc.init
		downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)

    args = []
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
    #args << "--thumb" # We want thumbnails of images down as well
    args << "--thumbsize=640" # Big thumbs!
    args << "--hash" # Print progress
    #args << "--long"
    args << "--debug" if @debug
		args << "--force"
    args << "--get"
    args << index
		args << "2>&1"

    bundled_executable_path = NSBundle.mainBundle.resourcePath
    environmentDictionary = { "PATH" => "#{bundled_executable_path}:/usr/bin:/bin:/usr/sbin:/sbin",
                              "HOME" => $homeDirectory,
                              "IPLAYER_OUTDIR" => directory }

    invokeGetIplayerWithArgs(args, andEnvironment:environmentDictionary)
  end
	
  def updateGetIplayerCaches(type = "radio")
		Logger.debug("Too busy to update the cache") && return if busy?
		
    Logger.debug("Refreshing get_iplayer #{type} cache")
    @task = NSTask.alloc.init
		
    downloaderPath = NSBundle.mainBundle.pathForResource('get_iplayer', ofType:nil)
    @task.setLaunchPath(downloaderPath)
    
    args = NSMutableArray.alloc.init
    args.addObject("--type=#{type}")
    args.addObject("--nopurge")
    args.addObject("--refresh")
		
    bundled_executable_path = NSBundle.mainBundle.resourcePath
    environmentDictionary = NSDictionary.dictionaryWithObjectsAndKeys("#{bundled_executable_path}:/usr/bin:/bin:/usr/sbin:/sbin",
                                                                      "PATH",
                                                                      $homeDirectory,
                                                                      "HOME",
                                                                      nil)

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
    Logger.debug("Task finished")    
    nc = NSNotificationCenter.defaultCenter
    nc.removeObserver(self)
    @task = nil
    @taskPipe = nil
    @taskPipeFileHandle = nil
    
    NSNotificationCenter.defaultCenter.postNotificationName('TaskWrapperTaskFinishedNotification', object:nil)
  end
	
	# Forcefully kill it if needed
	def terminate
		if @task && @task.isRunning
      @task.terminate
			taskTerminated
		end
	end
	
end