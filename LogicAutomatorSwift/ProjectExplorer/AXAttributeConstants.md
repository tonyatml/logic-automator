# Accessibility Attribute Constants

## Basic Element Information
- `kAXRoleAttribute` - Element role (e.g., button, text field)
- `kAXSubroleAttribute` - Element subrole for more specific classification
- `kAXRoleDescriptionAttribute` - Human-readable role description
- `kAXHelpAttribute` - Help text for the element
- `kAXTitleAttribute` - Element title or label
- `kAXDescriptionAttribute` - Element description
- `kAXDescription` - Alternative description attribute
- `kAXIdentifierAttribute` - Unique identifier for the element

## Value and State Attributes
- `kAXValueAttribute` - Current value of the element
- `kAXValueDescriptionAttribute` - Description of the current value
- `kAXMinValueAttribute` - Minimum allowed value
- `kAXMaxValueAttribute` - Maximum allowed value
- `kAXValueIncrementAttribute` - Step size for value changes
- `kAXAllowedValuesAttribute` - Array of allowed values
- `kAXPlaceholderValueAttribute` - Placeholder text
- `kAXEnabledAttribute` - Whether element is enabled
- `kAXElementBusyAttribute` - Whether element is currently busy
- `kAXFocusedAttribute` - Whether element has focus
- `kAXSelectedAttribute` - Whether element is selected
- `kAXExpandedAttribute` - Whether element is expanded
- `kAXMinimizedAttribute` - Whether window is minimized
- `kAXHiddenAttribute` - Whether element is hidden
- `kAXFrontmostAttribute` - Whether application is frontmost
- `kAXMainAttribute` - Whether this is the main element
- `kAXModalAttribute` - Whether element is modal
- `kAXEditedAttribute` - Whether element has been edited

## Hierarchy and Relationships
- `kAXParentAttribute` - Parent element
- `kAXChildrenAttribute` - Child elements
- `kAXSelectedChildrenAttribute` - Currently selected children
- `kAXVisibleChildrenAttribute` - Currently visible children
- `kAXWindowAttribute` - Window containing this element
- `kAXTopLevelUIElementAttribute` - Top-level UI element
- `kAXProxyAttribute` - Proxy element
- `kAXLinkedUIElementsAttribute` - Related UI elements
- `kAXServesAsTitleForUIElementsAttribute` - Elements this serves as title for
- `kAXLabelUIElementsAttribute` - Elements this labels
- `kAXShownMenuUIElementAttribute` - Currently shown menu element

## Position and Size
- `kAXPositionAttribute` - Element position (x, y coordinates)
- `kAXSizeAttribute` - Element size (width, height)
- `kAXOrientationAttribute` - Element orientation
- `kAXFrame` - Element frame (position + size)

## Text Attributes
- `kAXTextAttribute` - Text content
- `kAXVisibleTextAttribute` - Currently visible text
- `kAXSelectedTextAttribute` - Currently selected text
- `kAXSelectedTextRangeAttribute` - Range of selected text
- `kAXSelectedTextRangesAttribute` - Multiple selected text ranges
- `kAXVisibleCharacterRangeAttribute` - Range of visible characters
- `kAXNumberOfCharactersAttribute` - Total number of characters
- `kAXIsEditableAttribute` - Whether text is editable
- `kAXSharedTextUIElementsAttribute` - Elements sharing this text
- `kAXSharedCharacterRangeAttribute` - Shared character range
- `kAXSharedFocusElementsAttribute` - Elements sharing focus
- `kAXInsertionPointLineNumberAttribute` - Line number of insertion point

## Window and Application
- `kAXWindowsAttribute` - All windows
- `kAXMainWindowAttribute` - Main window
- `kAXFocusedWindowAttribute` - Currently focused window
- `kAXFocusedUIElementAttribute` - Currently focused UI element
- `kAXFocusedApplicationAttribute` - Currently focused application
- `kAXIsApplicationRunningAttribute` - Whether application is running

## Menu and Navigation
- `kAXMenuBarAttribute` - Application menu bar
- `kAXExtrasMenuBarAttribute` - Extras menu bar
- `kAXMenuItemCmdCharAttribute` - Menu item command character
- `kAXMenuItemCmdVirtualKeyAttribute` - Menu item virtual key
- `kAXMenuItemCmdGlyphAttribute` - Menu item command glyph
- `kAXMenuItemCmdModifiersAttribute` - Menu item command modifiers
- `kAXMenuItemMarkCharAttribute` - Menu item mark character
- `kAXMenuItemPrimaryUIElementAttribute` - Menu item primary UI element

## Buttons and Controls
- `kAXCloseButtonAttribute` - Close button
- `kAXZoomButtonAttribute` - Zoom button
- `kAXMinimizeButtonAttribute` - Minimize button
- `kAXToolbarButtonAttribute` - Toolbar button
- `kAXFullScreenButtonAttribute` - Full screen button
- `kAXDefaultButtonAttribute` - Default button
- `kAXCancelButtonAttribute` - Cancel button
- `kAXDecrementButtonAttribute` - Decrement button
- `kAXIncrementButtonAttribute` - Increment button
- `kAXSearchButtonAttribute` - Search button
- `kAXClearButtonAttribute` - Clear button
- `kAXOverflowButtonAttribute` - Overflow button

## Table and Grid Attributes
- `kAXRowsAttribute` - Table rows
- `kAXVisibleRowsAttribute` - Currently visible rows
- `kAXSelectedRowsAttribute` - Currently selected rows
- `kAXColumnsAttribute` - Table columns
- `kAXVisibleColumnsAttribute` - Currently visible columns
- `kAXSelectedColumnsAttribute` - Currently selected columns
- `kAXRowCountAttribute` - Number of rows
- `kAXColumnCountAttribute` - Number of columns
- `kAXSelectedCellsAttribute` - Currently selected cells
- `kAXVisibleCellsAttribute` - Currently visible cells
- `kAXRowHeaderUIElementsAttribute` - Row header elements
- `kAXColumnHeaderUIElementsAttribute` - Column header elements
- `kAXRowIndexRangeAttribute` - Range of row indices
- `kAXColumnIndexRangeAttribute` - Range of column indices
- `kAXOrderedByRowAttribute` - Whether ordered by row
- `kAXColumnTitleAttribute` - Column title
- `kAXColumnTitlesAttribute` - All column titles
- `kAXSortDirectionAttribute` - Sort direction
- `kAXIndexAttribute` - Element index

## Disclosure and Expansion
- `kAXDisclosingAttribute` - Whether element is disclosing
- `kAXDisclosedRowsAttribute` - Currently disclosed rows
- `kAXDisclosedByRowAttribute` - Row that disclosed this element
- `kAXDisclosureLevelAttribute` - Level of disclosure

## Scroll and Layout
- `kAXHorizontalScrollBarAttribute` - Horizontal scroll bar
- `kAXVerticalScrollBarAttribute` - Vertical scroll bar
- `kAXSplittersAttribute` - Splitter elements
- `kAXContentsAttribute` - Element contents
- `kAXNextContentsAttribute` - Next contents
- `kAXPreviousContentsAttribute` - Previous contents
- `kAXIncrementorAttribute` - Incrementor element
- `kAXGrowAreaAttribute` - Grow area
- `kAXMatteHoleAttribute` - Matte hole
- `kAXMatteContentUIElementAttribute` - Matte content element

## Time and Date Fields
- `kAXHourFieldAttribute` - Hour field
- `kAXMinuteFieldAttribute` - Minute field
- `kAXSecondFieldAttribute` - Second field
- `kAXAMPMFieldAttribute` - AM/PM field
- `kAXDayFieldAttribute` - Day field
- `kAXMonthFieldAttribute` - Month field
- `kAXYearFieldAttribute` - Year field

## File and Document
- `kAXFilenameAttribute` - File name
- `kAXURLAttribute` - File URL
- `kAXDocumentAttribute` - Document element

## Units and Measurement
- `kAXUnitsAttribute` - Units of measurement
- `kAXUnitDescriptionAttribute` - Description of units
- `kAXHorizontalUnitsAttribute` - Horizontal units
- `kAXVerticalUnitsAttribute` - Vertical units
- `kAXHorizontalUnitDescriptionAttribute` - Horizontal unit description
- `kAXVerticalUnitDescriptionAttribute` - Vertical unit description

## Markers and Handles
- `kAXMarkerUIElementsAttribute` - Marker elements
- `kAXMarkerTypeAttribute` - Type of marker
- `kAXMarkerTypeDescriptionAttribute` - Marker type description
- `kAXHandlesAttribute` - Handle elements

## Tabs and Headers
- `kAXTabsAttribute` - Tab elements
- `kAXHeaderAttribute` - Header element
- `kAXTitleUIElementAttribute` - Title UI element

## Value Wrapping and Validation
- `kAXValueWrapsAttribute` - Whether value wraps around
- `kAXWarningValueAttribute` - Warning threshold value
- `kAXCriticalValueAttribute` - Critical threshold value

## UI State
- `kAXAlternateUIVisibleAttribute` - Whether alternate UI is visible

## Parameterized Attributes (Functions)
- `kAXLineForIndexParameterizedAttribute` - Get line for character index
- `kAXRangeForLineParameterizedAttribute` - Get range for line number
- `kAXStringForRangeParameterizedAttribute` - Get string for range
- `kAXRangeForPositionParameterizedAttribute` - Get range for position
- `kAXRangeForIndexParameterizedAttribute` - Get range for index
- `kAXBoundsForRangeParameterizedAttribute` - Get bounds for range
- `kAXRTFForRangeParameterizedAttribute` - Get RTF for range
- `kAXAttributedStringForRangeParameterizedAttribute` - Get attributed string for range
- `kAXStyleRangeForIndexParameterizedAttribute` - Get style range for index
- `kAXCellForColumnAndRowParameterizedAttribute` - Get cell for column and row
- `kAXLayoutPointForScreenPointParameterizedAttribute` - Convert screen point to layout point
- `kAXLayoutSizeForScreenSizeParameterizedAttribute` - Convert screen size to layout size
- `kAXScreenPointForLayoutPointParameterizedAttribute` - Convert layout point to screen point
- `kAXScreenSizeForLayoutSizeParameterizedAttribute` - Convert layout size to screen size
