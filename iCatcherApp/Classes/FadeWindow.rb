# FadeWindow.rb
# iCatcher
#
# Created by Nick Ludlam on 14/02/2011.
# Copyright 2011 Tactotum Ltd. All rights reserved.

class FadeWindow < NSPanel

  def fadeInAndMakeKeyAndOrderFront(orderFront)
    self.setAlphaValue(0);
    if orderFront
      self.makeKeyAndOrderFront(nil)
    end
    
    self.animator.setAlphaValue(1.0)
  end
  
  def fadeOutAndOrderOut(orderOut)
    if orderOut
      delay = NSAnimationContext.currentContext.duration + 0.1
      self.performSelector('orderOut:', withObject:nil, afterDelay:delay)
    end
    
    self.animator.setAlphaValue(0)
  end
end
