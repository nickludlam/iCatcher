# SinatraApp.rb
# iCatcher
#
# Created by Nick Ludlam on 27/02/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.


class SinatraApp < Sinatra::Base

  puts "views path => #{$sinatraViewsPath}"
  set :views, $sinatraViewsPath
  
  get('/') do
    @variable = "<elan>"
		#coder = HTMLEntities.new
		#coder.encode(string)
    erb 'index'
  end
  
  get('/feeds/:feed_name') do
    base = $downloadDirectory
    @mc = MediaScanner.createCollection(File.join($downloadDirectory, params[:feed_name]), "radio", 0)
    
    #Logger.debug("title: " + @mc.title)
    #Logger.debug("link: " + @mc.link)
    #Logger.debug("description: " + (@mc.description || ""))
    #Logger.debug("items")
    #@mc.media_items.each do |mi|
    #  Logger.debug("title: " + mi.title)
    #  Logger.debug("url: " + mi.url)
    #  Logger.debug("length: " + mi.size.to_s)
    #  Logger.debug("type: " + mi.mime_type)
    #  Logger.debug("pubDate: " + mi.pub_date)
    #end
      
    erb :feed
  end

  get('/feeds/:feed_name.json') do
    content_type :json
    @mc = MediaScanner.createCollection(File.join($downloadDirectory, params[:feed_name]), "radio", 0)
    
  end
end

