#
#  SubscriptionsEditorController.rb
#  iCatcher
#
#  Created by Nick Ludlam on 06/09/2011.
#  Copyright 2011 Berg London Ltd. All rights reserved.
#

class SubscriptionsEditorController < NSWindowController
  
  attr_writer :subscriptionsWindow
  attr_writer :subscriptionsTable
  attr_writer :addSubscriptionButton
  attr_writer :removeSubscriptionButton
    
  attr_writer :nameTextField
  attr_writer :mediaPopup
  attr_writer :stationChannelLabel
  attr_writer :stationPopup
  attr_writer :categoryPopup
  attr_writer :searchTextField
  attr_writer :activeCheckbox
  
  attr_accessor :subscription
  
  
  def initialize
    @subscriptions = []
    @subscription = nil
  end

  def becomeActive
    if @subscriptions == nil || @subscriptions.length == 0
      @subscriptions = PVRSearch.all.sort_by { |s| s.displayname }
      @subscriptionsTable.reloadData
    end
    
    @mediaPopup.removeAllItems
    @mediaPopup.addItemWithTitle("Radio")
    @mediaPopup.addItemWithTitle("TV")
    
  end
  
  def setupPopups(subscription, media_type = 'radio')
    @stationPopup.removeAllItems
    @stationPopup.addItemWithTitle("All")
    @stationPopup.addItemsWithTitles(CacheReader.instance.allChannels(media_type).keys.sort)
    
    if subscription && subscription.channel != nil && @stationPopup.itemWithTitle(subscription.channel)
      @stationPopup.selectItemWithTitle(subscription.channel)
    elsif subscription.channel == nil
      @stationPopup.selectItemWithTitle("All")
    end
    
    @categoryPopup.removeAllItems
    @categoryPopup.addItemWithTitle("All")
    @categoryPopup.addItemsWithTitles(CacheReader.instance.allCategories(media_type).keys.sort)
    
    if subscription && subscription.category != nil
      if @categoryPopup.itemWithTitle(subscription.category)
        @categoryPopup.selectItemWithTitle(subscription.category)
      else
        CacheReader.instance.allCategories(media_type).store(subscription.category, true)
        # FIXME: UGLY UGLY UGLY
        @categoryPopup.removeAllItems
        @categoryPopup.addItemWithTitle("All")
        @categoryPopup.addItemsWithTitles(CacheReader.instance.allCategories(media_type).keys.sort)
        @categoryPopup.selectItemWithTitle(subscription.category)
      end
    elsif subscription.category == nil
      @categoryPopup.selectItemWithTitle("All")
    end
  end
  
  def windowWillClose(notification)    
    saveAllSearches
  end
  
  def saveAllSearches
    @subscriptions.each do |s|
      s.save
    end
  end

  # Table methods
    
  def numberOfRowsInTableView(tableView)
    @subscriptions.count
  end
  
  def tableView(tableView, objectValueForTableColumn:column, row:row)
    subscription = @subscriptions[row]
    
    case column.identifier
    when 'displayname'
      return subscription.displayname
    when 'active'
      return subscription.active
    else
      NSLog "Warning: Unknown column.identifier '#{column.identifier}'"
      return "Unknown"
    end
  end
    
  def tableViewSelectionDidChange(notification)
    row = @subscriptionsTable.selectedRow
    # Exit now if there's nothing selected
    if row < 0
      return
    end

    @subscription = @subscriptions[row]
    
    media_type = subscription.type    
    @nameTextField.stringValue = subscription.displayname
    @mediaPopup.selectItemWithTitle(subscription.type.capitalize)
    setupPopups(subscription, media_type)
    
    if subscription.searchesString != nil
      @searchTextField.stringValue = subscription.searchesString
    else
      @searchTextField.stringValue = ""
    end
    
    @activeCheckbox.stringValue = subscription.active
  end
  
  def controlTextDidEndEditing(notification)
    updateCurrentSubscription()
  end
  
  def controlTextDidChange(notification)
    updateCurrentSubscription()
  end
  
  def popupValueChanged(sender)
    if @mediaPopup.selectedItem.title.downcase != @subscription.type
      setupPopups(@subscription, @mediaPopup.selectedItem.title.downcase)
    end
    updateCurrentSubscription()
  end

  def updateCurrentSubscription()
    tableNeedsRefresh = false
    if @subscription.displayname != @nameTextField.stringValue
      tableNeedsRefresh = true
    end
    
    @subscription.displayname = @nameTextField.stringValue
    @subscription.type = @mediaPopup.selectedItem.title.downcase
    @subscription.channel = (@stationPopup.indexOfSelectedItem == 0) ? nil : @stationPopup.selectedItem.title
    @subscription.category = (@categoryPopup.indexOfSelectedItem == 0) ? nil : @categoryPopup.selectedItem.title
    
    if @searchTextField.stringValue.strip.length > 0
      @subscription.searchesString = @searchTextField.stringValue
    end
    
    @subscription.active = @activeCheckbox.stringValue
    
    @subscriptionsTable.reloadData if tableNeedsRefresh
  end
  
  # Sheeeeeet
  
  def addNewSubscription(sender)
    newSubscription = PVRSearch.new
    newSubscription.displayname = "New subscription"
    @subscriptions.unshift(newSubscription)
    @subscriptionsTable.reloadData
    @subscriptionsTable.selectRowIndexes(NSIndexSet.indexSetWithIndex(0), byExtendingSelection:false)
    tableViewSelectionDidChange(nil)
  end
  
  def didEndSheet(sheet, returnCode:returnCode, contextInfo:contextInfo)
    sheet.orderOut(self)
  end
  
  def removeSearchAction(sender)
    row = @subscriptionsTable.selectedRow
    if row > -1
      alert = NSAlert.alertWithMessageText("Delete the subscription?",
                                           defaultButton:"Yes",
                                           alternateButton:"No",
                                           otherButton:nil,
                                           informativeTextWithFormat:"Deleted subscriptions will also need to be removed in iTunes")    
      
      alert.beginSheetModalForWindow(@subscriptionsWindow,
                                     modalDelegate:self,
                                     didEndSelector:"alertDidEnd:returnCode:contextInfo:",
                                     contextInfo:nil)
    end
  end  
  
  def alertDidEnd(alert, returnCode:returnCode, contextInfo:contextInfo)
    if returnCode == 1
      row = @subscriptionsTable.selectedRow
      @subscriptions.delete(@subscription)
      @subscription.delete
      @subscriptionsTable.reloadData
      @subscriptionsTable.selectRowIndexes(NSIndexSet.indexSetWithIndex(0), byExtendingSelection:false)
      tableViewSelectionDidChange(nil)
    end
  end

  
end
