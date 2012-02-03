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
  attr_writer :searchInDescriptionCheckbox
  attr_writer :matchCountLabel
  attr_writer :previewPanelButton
  
  attr_writer :previewPanel
  attr_writer :previewPanelTextView
  
  attr_accessor :subscription
  
  MAX_MATCH_COUNT = 30
  
  def becomeActive
    @shouldUpdateiTunes = false  # Do we need to offer to update iTunes after closing the window
    @iTunesAlertShowing = false
    
    @subscriptions = PVRSearch.all.sort_by { |s| s.displayname }
    @subscriptionsTable.reloadData

    # Defaults
    @mediaPopup.removeAllItems
    @mediaPopup.addItemWithTitle("Radio")
    @mediaPopup.addItemWithTitle("TV")

    @subscriptionsTable.selectRowIndexes(NSIndexSet.indexSetWithIndex(0), byExtendingSelection:false)
    tableViewSelectionDidChange(nil) # Pretend the user clicked, to set initial state
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
  
  def windowShouldClose(notification)
    @subscriptions.each do |s|
      matches = CacheReader.instance.programmeIndexesForPVRSearch(s)
      if matches.count > MAX_MATCH_COUNT
        # TODO: DRY up the "unnamed subscription" code
        showTooManyMatchesError((s.displayname.strip.length == 0) ? "Unnamed subscription" : s.displayname, matches.count)
        Logger.debug("Too many matches for search {s.displayname}")
        return false
      end
    end
    
    saveAllSearches if @subscriptions

    if @shouldUpdateiTunes
      Logger.debug("Showing the updateiTunes alert")
      showUpdateiTunesAlert unless @iTunesAlertShowing
      return false
    end
    
    true
  end
  
  def windowWillClose(notification)
    @previewPanel.close()
  end
  
  def saveAllSearches
    @subscriptions.each do |s|
      s.save
    end
    @subscriptionsWindow.setDocumentEdited(false)
  end

  # Table methods
    
  def numberOfRowsInTableView(tableView)
    return 0 if @subscriptions == nil
    @subscriptions.count
  end
  
  def tableView(tableView, objectValueForTableColumn:column, row:row)
    subscription = @subscriptions[row]
    
    case column.identifier
    when 'displayname'
      return (subscription.displayname.strip.length == 0) ? "Unnamed subscription" : subscription.displayname
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
      @subscription = nil
      @nameTextField.stringValue = ""
      @mediaPopup.selectItemWithTitle("Radio")
      @categoryPopup.selectItemWithTitle("All")
      @stationPopup.selectItemWithTitle("All")
      @searchTextField.stringValue = ""
      @activeCheckbox.intValue = 0
      @searchInDescriptionCheckbox.intValue = 0
      @matchCountLabel.stringValue = "No matching programmes"

      self.disableAllControls
      return
    end

    self.enableAllControls

    @subscription = @subscriptions[row]
    
    media_type = subscription.type    
    @nameTextField.stringValue = subscription.displayname
    
    
    if subscription.type == "tv"
      @mediaPopup.selectItemWithTitle("TV")
    else
      @mediaPopup.selectItemWithTitle("Radio")
    end
    
    setupPopups(subscription, media_type)
    
    # Blank the search string if needed
    if subscription.searchesString != nil
      @searchTextField.stringValue = subscription.searchesString
    else
      @searchTextField.stringValue = ""
    end
    
    @activeCheckbox.intValue = subscription.active.to_i
    @searchInDescriptionCheckbox.intValue = subscription.descriptionSearch.to_i
    
    updateMatchCount()
    updatePreviewPanel()
  end
  
  def controlTextDidEndEditing(notification)
    NSLog("Field did end editing")
    updateCurrentSubscription(notification: notification)
  end
  
  def controlTextDidChange(notification)
    #NSLog("Text changed!")
    updateCurrentSubscription(notification: notification)
  end
    
  def popupValueChanged(sender)
    if @mediaPopup.selectedItem.title.downcase != @subscription.type
      setupPopups(@subscription, @mediaPopup.selectedItem.title.downcase)
    end
    
    updateCurrentSubscription(sender: sender)
  end

  def updateCurrentSubscription(options = {})
    return unless @subscription
    
    tableNeedsRefresh = false
    matchesNeedRefresh = false

    if @subscription.displayname != @nameTextField.stringValue
      tableNeedsRefresh = true
    end
    
    @subscription.displayname = @nameTextField.stringValue
    @subscription.type = @mediaPopup.selectedItem.title.downcase
    @subscription.channel = (@stationPopup.indexOfSelectedItem == 0) ? nil : @stationPopup.selectedItem.title
    @subscription.category = (@categoryPopup.indexOfSelectedItem == 0) ? nil : @categoryPopup.selectedItem.title
    
    if @searchTextField.stringValue.strip.length > 0
      @subscription.searchesString = @searchTextField.stringValue
    else
      @subscription.searchesString = nil
    end
    
    @subscription.active = @activeCheckbox.intValue
    @subscription.descriptionSearch = @searchInDescriptionCheckbox.intValue
    
    @subscriptionsTable.reloadData if tableNeedsRefresh
    
    updateMatchCount()
    updatePreviewPanel()
  end
  
  def updateMatchCount
    matches = CacheReader.instance.programmeIndexesForPVRSearch(@subscription)
    
    if matches == nil || matches == 0
      @matchCountLabel.stringValue = "No matching programmes"
    else
      @matchCountLabel.stringValue = "Matches %d programmes" % matches.length
    end
    
    if matches.length >= MAX_MATCH_COUNT
      @matchCountLabel.setTextColor(NSColor.redColor)
    else
      @matchCountLabel.setTextColor(NSColor.controlTextColor)
    end
  end
  
  ###############################################
  # Sheeeeeet
  
  def addNewSubscription(sender)
    newSubscription = PVRSearch.new
    newSubscription.displayname = "New subscription"
    @subscriptions.unshift(newSubscription)
    @subscriptionsTable.reloadData
    @subscriptionsTable.selectRowIndexes(NSIndexSet.indexSetWithIndex(0), byExtendingSelection:false)
    tableViewSelectionDidChange(nil)
    @shouldUpdateiTunes = true
    @subscriptionsWindow.setDocumentEdited(true)
    @nameTextField.becomeFirstResponder()
  end
  
  def didEndSheet(sheet, returnCode:returnCode, contextInfo:contextInfo)
    sheet.orderOut(self)
  end
  
  def removeSubscriptionAction(sender)
    row = @subscriptionsTable.selectedRow
    if row > -1
      alert = NSAlert.alertWithMessageText("Delete the subscription?",
                                           defaultButton:"Yes",
                                           alternateButton:"No",
                                           otherButton:nil,
                                           informativeTextWithFormat:"This will also delete all of the previously downloaded media") 
      
      alert.beginSheetModalForWindow(@subscriptionsWindow,
                                     modalDelegate:self,
                                     didEndSelector:"removeSubscriptionAlertDidEnd:returnCode:contextInfo:",
                                     contextInfo:nil)
    end
  end
  
  def removeSubscriptionAlertDidEnd(alert, returnCode:returnCode, contextInfo:contextInfo)
    if returnCode == 1
      row = @subscriptionsTable.selectedRow
      @subscriptions.delete(@subscription)
      @subscription.deleteDownloadedMedia
      @subscription.delete
      @subscriptionsTable.reloadData
      @subscriptionsTable.selectRowIndexes(NSIndexSet.indexSetWithIndex(0), byExtendingSelection:false)
      tableViewSelectionDidChange(nil)
      @shouldUpdateiTunes = true
      @subscriptionsWindow.setDocumentEdited(true)
    end
  end

  def showTooManyMatchesError(subscriptionDisplayName, match_count)
    alert = NSAlert.alertWithMessageText("Too many matches for '#{subscriptionDisplayName}'",
                                         defaultButton:"OK",
                                         alternateButton:nil,
                                         otherButton:nil,
                                         informativeTextWithFormat:"Your subscription named '#{subscriptionDisplayName}' currently matches #{match_count} programmes. There is a limit of #{MAX_MATCH_COUNT} per subscription. Please make the search more specific.")    
    
    alert.beginSheetModalForWindow(@subscriptionsWindow,
                                   modalDelegate:self,
                                   didEndSelector:"tooManyMatchesErrorDidEnd:returnCode:contextInfo:",
                                   contextInfo:nil)
  end
  
  def tooManyMatchesErrorDidEnd(alert, returnCode:returnCode, contextInfo:contextInfo)
  end
  
  def showUpdateiTunesAlert
    @iTunesAlertShowing = true
    alert = NSAlert.alertWithMessageText("Update iTunes podcasts?",
                                         defaultButton:"Yes",
                                         alternateButton:"No",
                                         otherButton:nil,
                                         informativeTextWithFormat:"Do you want to update the Podcast subscriptions in iTunes now?")
    
    alert.beginSheetModalForWindow(@subscriptionsWindow,
                                   modalDelegate:self,
                                   didEndSelector:"updateiTunesAlertDidEnd:returnCode:contextInfo:",
                                   contextInfo:nil)

  end
  
  def updateiTunesAlertDidEnd(alert, returnCode:returnCode, contextInfo:contextInfo)
    if returnCode == 1
      NSApp.delegate.setupiTunes()
    end

    @shouldUpdateiTunes = false
    @iTunesAlertShowing = false
    @subscriptionsWindow.performSelectorOnMainThread('performClose:',
                                                     withObject:nil,
                                                     waitUntilDone:false)
  end

  
  def bringAllToFront()
    @subscriptionsWindow.makeKeyAndOrderFront(nil) if @subscriptionsWindow.isVisible
    @previewPanel.orderFrontRegardless() if @previewPanel.isVisible
  end
  
  def openPreviewPanel(sender)
    updatePreviewPanel()
    @previewPanel.makeKeyAndOrderFront(nil)
  end
  
  def updatePreviewPanel()
    # Blank the window
    @previewPanelTextView.textStorage.mutableString.setString("")
    
    matchingProgrammes = CacheReader.instance.programmeDetailsForPVRSearch(@subscription)    
    #Logger.debug("Got #{matchingProgrammes.count} matches")
    
    # Prevent over matching.
    over_max_matches = false
    
    if matchingProgrammes.count > MAX_MATCH_COUNT
      addContentToPreviewPanel("TOO MANY MATCHES, PLEASE MAKE A MORE SPECIFIC SEARCH\n\n", :error)
      matchingProgrammes = matchingProgrammes.first(MAX_MATCH_COUNT)
      #Logger.debug("Count is now #{matchingProgrammes.count}")
    end
    
    matchingProgrammes.each do |p|
      addContentToPreviewPanel("#{p['name']} - #{p['episode']}\n", :bold)
      addContentToPreviewPanel("#{p['desc']}\n\n")
    end
  end

  def addContentToPreviewPanel(content, style=:normal)
    before = @previewPanelTextView.textStorage.mutableString.length
    @previewPanelTextView.textStorage.mutableString.appendString(content)
    after = @previewPanelTextView.textStorage.mutableString.length
    
    color = (style == :error) ? NSColor.redColor : NSColor.blackColor
    
    @previewPanelTextView.setTextColor(color, range:NSRange.new(before, after-before))
    
    if style == :bold
      @previewPanelTextView.textStorage.applyFontTraits(NSBoldFontMask, range:NSRange.new(before, content.length - 1))
    end
  end
  
  def disableAllControls
    allControls.each do |c|
      c.setEnabled(false);
    end
  end
  
  def enableAllControls
    allControls.each do |c|
      c.setEnabled(true);
    end
  end
  
  def allControls
    [ @nameTextField, @mediaPopup, @stationChannelLabel, @stationPopup, @categoryPopup, @searchTextField, @activeCheckbox, @searchInDescriptionCheckbox, @matchCountLabel, @previewPanelButton ]
  end
end
