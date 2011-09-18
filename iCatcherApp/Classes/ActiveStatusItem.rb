# ActiveStatusItem.rb
# iCatcher
#
# Created by Nick Ludlam on 13/02/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class ActiveStatusItem < NSView
  
  attr_accessor :delegate
  attr_accessor :showHighlightImage
  attr_accessor :showHoverImage
  
  attr_accessor :enclosingStatusItem
  attr_accessor :enclosingMenu
  
  def initWithFrame(frame)
    super(frame)
    Logger.debug("Initialised ActiveStatusItem")
    # Load our image references into an array
    @colouredAnimationImages = []    
    @whiteAnimationImages = []    
    (0..36).each do |i|
      @colouredAnimationImages << NSImage.imageNamed("icatcher_menubar_icon_%.02i.png" % i)
      @whiteAnimationImages << NSImage.imageNamed("icatcher_menubar_icon_white_%.02i.png" % i)
    end
    self
  end
  
  def acceptsFirstResponder(); true; end

  def mouseDown(sender = nil)
    @showHighlightImage = true
    enclosingStatusItem.popUpStatusItemMenu(@enclosingMenu) if @enclosingMenu
    self.setNeedsDisplay(true)
  end
  
  def setupDragEvents
    registerForDraggedTypes(["WebURLsWithTitlesPboardType"])
  end   

  def draggingEntered(draggingInfo)
    #Logger.debug("ActiveStatusItem Dragging entered from sender")
    #Logger.debug(draggingInfo.inspect)
    pboard = draggingInfo.draggingPasteboard()
    types = pboard.types()
    
    #Logger.debug("Dragging entered with types:")
    #Logger.debug(types.inspect)
    
    # Our default
    op_type = NSDragOperationNone
        
    urlDict = getUrlAndTitleFromPasteboard(pboard)
    
    # Check for a valid iplayer URL
    if urlDict.has_key?(:url) && ApplicationController.pidFromURL(urlDict[:url])
      op_type = NSDragOperationCopy
      @showHoverImage = true
      self.setNeedsDisplay(true)
    end
    
    op_type
  end
  
  def draggingExited(sender)
    Logger.debug("draggingExited")
    @showHoverImage = false
    self.setNeedsDisplay(true)
  end

  def performDragOperation(sender)
    pboard = sender.draggingPasteboard()
    result = false
    @showHoverImage = false
    self.setNeedsDisplay(true)

    urlDict = getUrlAndTitleFromPasteboard(pboard)
    @delegate.downloadFromURL(urlDict[:url]) if @delegate && urlDict.has_key?(:url)
    true
  end
  
  def getUrlAndTitleFromPasteboard(pasteboard)
    result = {}

    if pasteboard.types.include?("WebURLsWithTitlesPboardType")
      pbArray = pasteboard.propertyListForType("WebURLsWithTitlesPboardType")
      # URL is the first element, title the second
      if pbArray && pbArray.count >= 2
        url = pbArray[0][0]
        title = pbArray[1][0]
        result[:url] = url
        result[:title] = title
      end
    end
    
    result
  end

  def drawRect(dirtyRect)
    #Logger.debug("ActiveNSStatusItemView drawRect")
    
    # Debug! Uncomment for a red background
    #NSColor.clearColor.set
    #NSRectFill(dirtyRect)
           
		rect = NSMakeRect(7, 3, 16, 16)
 
    if @animationTimer
      if @showHighlightImage
        i = @whiteAnimationImages[@animationFrame]
      else
        i = @colouredAnimationImages[@animationFrame]
      end
    elsif @showHighlightImage
      #Logger.debug("Highlight mode!")
      i = NSImage.imageNamed('icatcher_menubar_icon_white.png')
    elsif @showHoverImage
      #Logger.debug("Busy mode!")
      i = NSImage.imageNamed('icatcher_menubar_icon_white.png')
    else
      #Logger.debug("Normal mode!")
      i = NSImage.imageNamed('icatcher_menubar_icon_black.png')
    end

    if @showHighlightImage
      enclosingStatusItem.drawStatusBarBackgroundInRect(self.bounds, withHighlight:true)
		elsif @showHoverImage
		  NSColor.colorWithDeviceRed(203/255.0, green:78/255.0, blue:165/255.0, alpha:1.0).set
			NSRectFill(self.bounds)
    end
    
    if i
      #Logger.debug("drawInRect called on #{i.inspect}")
      i.drawInRect(rect, fromRect:NSZeroRect, operation:NSCompositeSourceOver, fraction:1.0)
    end
  end

  def startAnimation()
    Logger.debug("starting animation")
    unless @animationTimer
      @animationFrame = 0
      @animationTimer = NSTimer.scheduledTimerWithTimeInterval(1.0/15.0, target:self, selector:'animationFire:', userInfo:nil, repeats:true)
      NSRunLoop.currentRunLoop.addTimer @animationTimer, forMode:NSModalPanelRunLoopMode
      NSRunLoop.currentRunLoop.addTimer @animationTimer, forMode:NSEventTrackingRunLoopMode
    end
  end
  
  def endAnimation()
    if @animationTimer
      @animationTimer.invalidate
      @animationTimer = nil
			setNeedsDisplay(true)
		end
  end
  
  def animationFire(timer)
    @animationFrame += 1
    @animationFrame = 0 if @animationFrame > 35
    setNeedsDisplay(true)
  end
  
end
