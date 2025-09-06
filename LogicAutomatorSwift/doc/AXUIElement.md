# Accessibility UI Element API Reference

## Trust and Permissions

### Trust Checking Functions
- `AXIsProcessTrusted()` - Check if current process is trusted (macOS 10.4+)
- `AXIsProcessTrustedWithOptions(_:)` - Check trust with options (macOS 10.9+)
- `kAXTrustedCheckOptionPrompt` - Option to prompt user if untrusted

## Core Types

### AXUIElement
- `AXUIElement` - Main accessibility object class
- `AXUIElementGetTypeID()` - Get type identifier for AXUIElement

### AXTextMarker
- `AXTextMarker` - Text position marker
- `AXTextMarkerGetTypeID()` - Get type identifier
- `AXTextMarkerCreate(_:_:_:)` - Create new text marker
- `AXTextMarkerGetLength(_:)` - Get marker data length
- `AXTextMarkerGetBytePtr(_:)` - Get marker byte data

### AXTextMarkerRange
- `AXTextMarkerRange` - Text range between two markers
- `AXTextMarkerRangeGetTypeID()` - Get type identifier
- `AXTextMarkerRangeCreate(_:_:_:)` - Create range from start/end markers
- `AXTextMarkerRangeCreateWithBytes(_:_:_:_:_:_:)` - Create range from byte data
- `AXTextMarkerRangeCopyStartMarker(_:)` - Get start marker
- `AXTextMarkerRangeCopyEndMarker(_:)` - Get end marker

### AXObserver
- `AXObserver` - Notification observer
- `AXObserverGetTypeID()` - Get type identifier
- `AXObserverCallback` - Basic callback function type
- `AXObserverCallbackWithInfo` - Callback with info dictionary

## Element Creation and Management

### Application Elements
- `AXUIElementCreateApplication(_:)` - Create element for application by PID
- `AXUIElementCreateSystemWide()` - Create system-wide element
- `AXUIElementGetPid(_:_:)` - Get process ID of element
- `AXUIElementCopyElementAtPosition(_:_:_:_:)` - Get element at screen position

### Timeout Management
- `AXUIElementSetMessagingTimeout(_:_:)` - Set messaging timeout (macOS 10.4+)

## Attribute Operations

### Basic Attribute Functions
- `AXUIElementCopyAttributeNames(_:_:)` - Get all supported attribute names
- `AXUIElementCopyAttributeValue(_:_:_:)` - Get single attribute value
- `AXUIElementSetAttributeValue(_:_:_:)` - Set attribute value
- `AXUIElementIsAttributeSettable(_:_:_:)` - Check if attribute is settable

### Array Attribute Functions
- `AXUIElementGetAttributeValueCount(_:_:_:)` - Get array attribute count
- `AXUIElementCopyAttributeValues(_:_:_:_:_:)` - Get array attribute values
- `AXUIElementCopyMultipleAttributeValues(_:_:_:_:)` - Get multiple attributes (macOS 10.4+)

### Parameterized Attributes
- `AXUIElementCopyParameterizedAttributeNames(_:_:)` - Get parameterized attribute names (macOS 10.3+)
- `AXUIElementCopyParameterizedAttributeValue(_:_:_:_:)` - Get parameterized attribute value (macOS 10.3+)

## Action Operations

### Action Functions
- `AXUIElementCopyActionNames(_:_:)` - Get all available actions
- `AXUIElementCopyActionDescription(_:_:_:)` - Get action description
- `AXUIElementPerformAction(_:_:)` - Perform action on element

## Observer Operations

### Observer Creation
- `AXObserverCreate(_:_:_:)` - Create basic observer
- `AXObserverCreateWithInfoCallback(_:_:_:)` - Create observer with info callback

### Notification Management
- `AXObserverAddNotification(_:_:_:_:)` - Add notification to observer
- `AXObserverRemoveNotification(_:_:_:)` - Remove notification from observer
- `AXObserverGetRunLoopSource(_:)` - Get run loop source for observer

## Error Handling

### Common Error Codes
- `kAXErrorAttributeUnsupported` - Attribute not supported
- `kAXErrorNoValue` - No value for attribute
- `kAXErrorIllegalArgument` - Invalid argument
- `kAXErrorInvalidUIElement` - Invalid UI element
- `kAXErrorCannotComplete` - Cannot complete operation
- `kAXErrorNotImplemented` - Not implemented
- `kAXErrorFailure` - System failure
- `kAXErrorActionUnsupported` - Action not supported
- `kAXErrorInvalidUIElementObserver` - Invalid observer
- `kAXErrorNotificationUnsupported` - Notification not supported
- `kAXErrorNotificationAlreadyRegistered` - Notification already registered
- `kAXErrorNotificationNotRegistered` - Notification not registered

## Options and Configuration

### Copy Options
- `AXCopyMultipleAttributeOptions` - Options for multiple attribute copying
- `AXCopyMultipleAttributeOptions.stopOnError` - Stop on first error

## Usage Patterns

### Basic Element Access
```swift
// Create application element
let appElement = AXUIElementCreateApplication(pid)

// Get attribute names
var attributeNames: CFArray?
AXUIElementCopyAttributeNames(appElement, &attributeNames)

// Get attribute value
var value: CFTypeRef?
AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute, &value)
```

### Observer Setup
```swift
// Create observer
var observer: AXObserver?
AXObserverCreate(pid, callback, &observer)

// Add to run loop
if let observer = observer {
    let runLoopSource = AXObserverGetRunLoopSource(observer)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
}

// Add notification
AXObserverAddNotification(observer, element, kAXValueChangedNotification, nil)
```

### Text Marker Usage
```swift
// Create text marker
let marker = AXTextMarkerCreate(kCFAllocatorDefault, bytes, length)

// Create text range
let range = AXTextMarkerRangeCreate(kCFAllocatorDefault, startMarker, endMarker)
```
