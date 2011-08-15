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
    @dirs = []
    Dir.glob($downloadDirectory + "/*") do |entry|
      @dirs << entry if File.directory?(entry) 
    end
  
    erb :all_feeds
  end

  get('/feeds.json') do
    dirs = []
    
    Dir.glob($downloadDirectory + "/*") do |entry|
      dirs << entry if File.directory?(entry) 
    end
    
    puts "Dirs are #{dirs}"
    content_type :json
    {'content' => dirs}.to_json
  end

  post('/feeds.json') do
    Logger.debug("POST -> #{params.inspect}")
    new_search = PVRSearch.new()
    content_type :json
    new_search.to_json
  end
  
  get('/feeds/:feed_name.xml') do
    Logger.debug("GET -> #{params.inspect}")
    base = $downloadDirectory
    @mc = MediaScanner.createCollection(File.join($downloadDirectory, params[:feed_name]), "radio", 0)
    erb :feed
  end

  get('/feeds/:feed_name.json') do
    search = PVRSearch.new(params[:filename])
    content_type :json
    search.to_json
  end

  put('/feeds/:feed_name.json') do
    Logger.debug("PUT -> #{params.inspect}")
    search = PVRSearch.new(params[:filename])
    search.update_attributes(params)
    search.to_json
  end

  get('/feeds/:feed_name/:file_name') do 
    path = File.join($downloadDirectory, params[:feed_name], params[:file_name])
    send_file(path)
  end

  get('/instant-download') do
    Logger.debug("INSTANT DOWNLOAD -> #{params.inspect}")
    uri = URI.parse(params[:url])
    if (uri.host == "www.bbc.co.uk" && uri.path =~ /^\/iplayer\/episode/)
      appController = NSApplication.sharedApplication.delegate.appController
      appController.urlAndTitleDropped(params[:url], "fake title")
    else
      erb :bad_url
    end
  end

  get('/resources/:resource_name') do
    send_file(NSBundle.mainBundle.resourcePath + "/" + params[:resource_name])
  end

end

