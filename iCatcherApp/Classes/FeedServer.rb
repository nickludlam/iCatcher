# FeedServer.rb
# iCatcher
#
# Created by Nick Ludlam on 29/12/2010.
# Copyright 2010 Tactotum Ltd. All rights reserved.


class FeedServer

  def call(env)
    # Sample of env is:
    # {"rack.errors"=>#<IO:<STDERR>>, "rack.multiprocess"=>false, "rack.multithread"=>false, "rack.run_once"=>false, "rack.version"=>[1, 0], "REQUEST_METHOD"=>"GET", "PATH_INFO"=>"/foo/bar", "QUERY_STRING"=>"id=baz", "REQUEST_URI"=>"/foo/bar?id=baz", "HTTP_VERSION"=>"HTTP/1.1", "HTTP_HOST"=>"localhost:8010", "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_4; en-us) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16", "HTTP_ACCEPT"=>"application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5", "HTTP_ACCEPT_LANGUAGE"=>"en-us", "HTTP_ACCEPT_ENCODING"=>"gzip, deflate", "HTTP_CONNECTION"=>"keep-alive", "GATEWAY_INTERFACE"=>"CGI/1.2", "SERVER_NAME"=>"localhost", "SERVER_PORT"=>"8010", "SERVER_PROTOCOL"=>"HTTP/1.1", "SERVER_SOFTWARE"=>"Control Tower v0.1", "SCRIPT_NAME"=>"", "rack.url_scheme"=>"http", "rack.input"=>#<StringIO:0x2007f4e00 @string="" @pos=0 @lineno=0 @writable=true @append=false @readable=true>, "REMOTE_ADDR"=>"127.0.0.1"}

    request_uri = env['REQUEST_URI']
    query_string = env['QUERY_STRING']
        
    body = "hello!"
    response_type = "text/plain"
    [ 200, { 'content-type' => response_type }, body ]
  end
  
end
