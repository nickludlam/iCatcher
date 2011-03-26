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
    @animationImages = []    
    (1..36).each do |i|
      @animationImages << NSImage.imageNamed("icatcher_menubar_icon_%.02i.png" % i)
    end
    self
  end
  
  def acceptsFirstResponder(); true; end

  def mouseDown(event)
    @showHighlightImage = true
    enclosingStatusItem.popUpStatusItemMenu(enclosingMenu)
    self.setNeedsDisplay(true)
  end
  
  def setupDragEvents
    registerForDraggedTypes(["WebURLsWithTitlesPboardType"])
  end   

  def draggingEntered(sender)
    Logger.debug("ActiveStatusItem Dragging entered from sender")
    Logger.debug(sender.inspect)
    pboard = sender.draggingPasteboard()
    types = pboard.types()
    
    Logger.debug("dragging entered with types:")
    Logger.debug(types.inspect)
    
    # Our default
    op_type = NSDragOperationNone

    Logger.debug("types")
    Logger.debug(types.inspect)
    
    if types.include?("WebURLsWithTitlesPboardType")
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
    successful = false
    @showHoverImage = false
    self.setNeedsDisplay(true)

    if pboard.types.include?("WebURLsWithTitlesPboardType")
      pbArray = pboard.propertyListForType("WebURLsWithTitlesPboardType")

      # URL is the first element, title the second
      if (pbArray.count >= 2)
        url = pbArray[0][0]
        title = pbArray[1][0]

        Logger.debug("URL title is #{title}")
        Logger.debug("URL is #{url}")

        @delegate.urlAndTitleDropped(url, title) if @delegate
        successful = true
      end
    end
    
    
    successful
  end

  def drawRect(dirtyRect)
    #Logger.debug("ActiveNSStatusItemView drawRect")
    
    # Debug! Uncomment for a red background
    #NSColor.clearColor.set
    #NSRectFill(dirtyRect)
           
		rect = NSMakeRect(7, 3, 16, 16)
 
    if @animationTimer
      i = @animationImages[@animationFrame]
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
      @animationTimer = NSTimer.scheduledTimerWithTimeInterval(1.0/10.0, target:self, selector:'animationFire:', userInfo:nil, repeats:true)
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
