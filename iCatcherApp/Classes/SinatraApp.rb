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

#get('/feeds/:feed_name/:file_name') do 
#    path = File.join($downloadDirectory, params[:feed_name], params[:file_name])
#    send_file(path)
#  end

  get('/instant-download') do
    Logger.debug("INSTANT DOWNLOAD -> #{params.inspect}")
    uri = URI.parse(params[:url])
    if (uri.host == "www.bbc.co.uk" && uri.path =~ /^\/iplayer\/episode/)
      appController = NSApp.delegate.appController
      @status = NSApp.delegate.appController.downloadFromURL(params[:url])
      #NSApp.delegate.appController.performSelectorOnMainThread('downloadFromURL:', withObject:params[:url], waitUntilDone:false)
      erb :downloading_adhoc
    else
      erb :bad_url
    end
  end

  get('/resources/:resource_name') do
    send_file(NSBundle.mainBundle.resourcePath + "/" + params[:resource_name])
  end

end

