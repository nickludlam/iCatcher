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
  attr_writer :enabledCheckbox
  
  
  def initialize
    @subscriptions = []
  end

  def becomeActive
    if @subscriptions.length == 0
      @subscriptions = PVRSearch.all.sort_by { |s| s.name }
      @subscriptionsTable.reloadData
    end
  end
  
  def windowWillClose(notification)    
    saveAllSearches
  end
  
  def saveAllSearches
    @searches.each do |s|
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
    when 'name'
      return subscription.displayname
    else
      puts "Warning: Unknown column.identifier #{column.identifier}"
      return "Unknown"
    end
  end
    
  def tableViewSelectionDidChange(notification)
    row = @subscriptionsTable.selectedRow
    if row > -1
      subscription = @subscriptions[row]
    end
    
    @nameTextField.value = subscription.displayname
  end

end
