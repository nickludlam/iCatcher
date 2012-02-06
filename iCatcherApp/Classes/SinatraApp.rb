# SinatraApp.rb
# iCatcher
#
# Created by Nick Ludlam on 27/02/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

require 'uri'

class SinatraApp < Sinatra::Base

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
  
  Logger.debug("views path => #{$sinatraViewsPath}")
  set :views, $sinatraViewsPath
  
  get('/') do
    @serverURL = $webserverURL
    @all_searches = PVRSearch.all  
    erb :index
  end

  get('/adhoc_feed.:format') do
    Logger.debug("Running ad-hoc media scanner")
    @mc = MediaScanner.createCollectionFromAdHocDirectory()
    
    Logger.debug("Finished making collection for template")

    @mc.media_items.each do |mi|
      Logger.debug("Media Item: #{mi.filepath}")
    end
    
    output = erb "feed_#{params[:format]}".to_sym
    Logger.debug("Finished rendering template")
    output
  end

  get('/feeds/:feed_name.:format') do
    Logger.debug("GET -> #{params.inspect}")
    base = $downloadDirectory
    search = PVRSearch.load(params[:feed_name])
    if search
      @mc = MediaScanner.createCollectionFromPVRSearch(search)
      erb "feed_#{params[:format]}".to_sym
    else
      erb :bad_url
    end
  end

  get('/instant-download') do
    Logger.debug("INSTANT DOWNLOAD -> #{params.inspect}")
    
    unless params[:url]
      return erb :bad_url
    end
    
    uri = URI.parse(params[:url])
    
    unless (uri.host == "www.bbc.co.uk" && uri.path =~ /^\/iplayer\/episode/)
      return erb :bad_url
    end
    
    appController = NSApp.delegate.appController
    currentTask = appController.currentTask
    taskQueue = appController.taskQueue
    @cr = CacheReader.instance

    #@status = appController.downloadFromURL(params[:url])
    
    pid = ApplicationController.pidFromURL(params[:url])
    
    # Are we already downloading this?
    # TODO Move this functionality into either appController or some sort of TaskQueue manager
    if currentTask && currentTask.url == params[:url]
      @status = "Programme is downloading"
      return erb :downloading_adhoc
    elsif taskQueue.length > 0 && taskQueue.find { |x| x.url == params[:url] }
      @status = "Programme download is queued"
      return erb :downloading_adhoc
    end
    
    # Ok so if we're not downloading it, have we got it previously?

    if @cr.pidInDownloadHistory?(pid) && params[:force] == nil
      @status = "Already downloaded. <a href=\"/instant-download?force=true&url=#{params[:url]}\">Force re-download</a>?"
      return erb :downloading_adhoc
    end
    
    # Ok so set it downloading
    task = appController.downloadFromURL(params[:url], params.has_key?("force"))
    
    # Redirect so we don't endlessly force downloading if the user hits refresh
    if @cr.pidInDownloadHistory?(pid) && params[:force]
      return redirect "/instant-download?url=#{params[:url]}"
    else
      @status = "Scheduling download"
    end
    
    erb :downloading_adhoc
  end

  get('/resources/:resource_name') do
    send_file(NSBundle.mainBundle.resourcePath + "/" + params[:resource_name])
  end

end

