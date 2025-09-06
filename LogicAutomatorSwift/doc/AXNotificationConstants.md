# Accessibility Notification Constants

## Application Notifications
- `kAXApplicationActivatedNotification` - Application became active
- `kAXApplicationDeactivatedNotification` - Application became inactive
- `kAXApplicationHiddenNotification` - Application was hidden
- `kAXApplicationShownNotification` - Application was shown

## Window Notifications
- `kAXWindowCreatedNotification` - New window was created
- `kAXWindowMovedNotification` - Window was moved
- `kAXWindowResizedNotification` - Window was resized
- `kAXWindowMiniaturizedNotification` - Window was minimized
- `kAXWindowDeminiaturizedNotification` - Window was restored from minimized
- `kAXMainWindowChangedNotification` - Main window changed
- `kAXFocusedWindowChangedNotification` - Focused window changed
- `kAXFocusedUIElementChangedNotification` - Focused UI element changed

## UI Element Notifications
- `kAXUIElementDestroyedNotification` - UI element was destroyed
- `kAXCreatedNotification` - New UI element was created
- `kAXElementBusyChangedNotification` - Element busy state changed
- `kAXValueChangedNotification` - Element value changed
- `kAXTitleChangedNotification` - Element title changed
- `kAXMovedNotification` - Element was moved
- `kAXResizedNotification` - Element was resized
- `kAXLayoutChangedNotification` - Layout changed

## Menu Notifications
- `kAXMenuOpenedNotification` - Menu was opened
- `kAXMenuClosedNotification` - Menu was closed
- `kAXMenuItemSelectedNotification` - Menu item was selected

## Table and Grid Notifications
- `kAXRowCountChangedNotification` - Number of rows changed
- `kAXRowExpandedNotification` - Table row was expanded
- `kAXRowCollapsedNotification` - Table row was collapsed
- `kAXSelectedCellsChangedNotification` - Selected cells changed
- `kAXSelectedRowsChangedNotification` - Selected rows changed
- `kAXSelectedColumnsChangedNotification` - Selected columns changed

## Selection and Focus Notifications
- `kAXSelectedChildrenChangedNotification` - Selected children changed
- `kAXSelectedChildrenMovedNotification` - Selected children moved
- `kAXSelectedTextChangedNotification` - Selected text changed

## Special UI Elements
- `kAXDrawerCreatedNotification` - Drawer was created
- `kAXSheetCreatedNotification` - Sheet was created
- `kAXHelpTagCreatedNotification` - Help tag was created

## Units and Measurements
- `kAXUnitsChangedNotification` - Units of measurement changed

## Accessibility Announcements
- `kAXAnnouncementRequestedNotification` - Screen reader announcement requested

## Notification Keys
- `kAXUIElementsKey` - Key for UI elements in notification
- `kAXPriorityKey` - Key for announcement priority
- `kAXAnnouncementKey` - Key for announcement text
- `kAXUIElementTitleKey` - Key for UI element title

## Priority Levels (for kAXPriorityKey)
- `AXPriority.low` - Low priority (value: 10)
- `AXPriority.medium` - Medium priority (value: 50)
- `AXPriority.high` - High priority (value: 90)
