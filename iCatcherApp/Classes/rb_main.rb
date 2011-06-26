#
#  rb_main.rb
#  iCatcher
#
#  Created by Nick Ludlam on 26/03/2011.
#  Copyright (c) 2011 Berg London Ltd. All rights reserved.
#

# Loading the Cocoa framework. If you need to load more frameworks, you can
# do that here too.
framework 'Cocoa'

# Add in our custom TagLib bundle
require "TagLib.bundle"
raise unless TagLib # Bail unless it's loaded properly

# Loading all the Ruby project files.
main = File.basename(__FILE__, File.extname(__FILE__))
dir_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
Dir.glob(File.join(dir_path, '*.{rb,rbo}')).map { |x| File.basename(x, File.extname(x)) }.uniq.each do |path|
  if path != main
    require(path)
  end
end

# Starting the Cocoa main loop.
NSApplicationMain(0, nil)
