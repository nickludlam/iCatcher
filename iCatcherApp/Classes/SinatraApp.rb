# SinatraApp.rb
# iCatcher
#
# Created by Nick Ludlam on 27/02/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

require 'uri'

class SinatraApp < Sinatra::Base

  puts "views path => #{$sinatraViewsPath}"
  set :views, $sinatraViewsPath
  
  get('/') do
    @all_searches = PVRSearch.all  
    erb :all_feeds
  end

  get('/adhoc_feed.xml') do
    @mc = MediaScanner.createCollectionFromAdHocDirectory()
    erb :feed
  end

  get('/feeds/:feed_name.xml') do
    Logger.debug("GET -> #{params.inspect}")
    base = $downloadDirectory
    search = PVRSearch.load(params[:feed_name])
    if search
      @mc = MediaScanner.createCollectionFromPVRSearch(search)
      erb :feed
    else
      erb :bad_url
    end
  end


  get('/feeds/:feed_name/:file_name') do 
    path = File.join($downloadDirectory, params[:feed_name], params[:file_name])
    send_file(path)
  end

  get('/instant-download') do
    Logger.debug("INSTANT DOWNLOAD -> #{params.inspect}")
    uri = URI.parse(params[:url])
    if (uri.host == "www.bbc.co.uk" && uri.path =~ /^\/iplayer\/episode/)
      appController = NSApp.delegate.appController
      NSApp.delegate.appController.performSelectorOnMainThread('downloadFromURL:', withObject:params[:url], waitUntilDone:false)
      erb :downloading_adhoc
    else
      erb :bad_url
    end
  end

  get('/resources/:resource_name') do
    send_file(NSBundle.mainBundle.resourcePath + "/" + params[:resource_name])
  end

end

