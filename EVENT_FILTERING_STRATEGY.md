# Event Filtering Strategy for Logic Pro Automation

## Overview

When recording user interactions with Logic Pro through accessibility events, we capture a massive amount of data, but most of it is noise. This document outlines a comprehensive strategy to filter and retain only meaningful user actions that represent actual workflow steps.

## Problem Statement

Current event recording captures hundreds of accessibility events, including:
- Text selection changes
- Element creation/destruction
- Automatic UI updates
- System-generated events
- Cursor movements

Most of these events don't represent meaningful user actions and create noise in the recorded protocols.

## Event Classification Analysis

### Current Event Types

From analysis of recorded events, we can categorize them into:

1. **Text Selection Changes** (`AXSelectedTextChanged`) - Usually meaningless
2. **Value Changes** (`AXValueChanged`) - Potentially meaningful (like text input)
3. **Menu Operations** (`AXMenuOpened`, `AXMenuClosed`) - Usually meaningful user actions
4. **Button Interactions** (`AXButtonPressed`) - Meaningful user actions
5. **Focus Changes** (`AXFocusedUIElementChanged`) - Context-dependent
6. **Element Lifecycle** (`AXCreated`, `AXUIElementDestroyed`) - Usually noise

## Filtering Strategy

### 1. Event Type Filtering

#### Meaningful Event Types (Keep)
```swift
let meaningfulEventTypes = [
    "AXMenuOpened",           // Menu operations
    "AXMenuClosed",           // Menu closing
    "AXButtonPressed",        // Button clicks
    "AXMenuItemSelected",     // Menu item selection
    "AXValueChanged",         // Value changes (needs further filtering)
    "AXFocusedUIElementChanged", // Focus changes (needs further filtering)
    "AXSelectedChildrenChanged", // Selection changes (needs further filtering)
    "AXSliderValueChanged",   // Slider adjustments
    "AXCheckBoxToggled",      // Checkbox state changes
]
```

#### Noise Event Types (Ignore)
```swift
let noiseEventTypes = [
    "AXSelectedTextChanged",  // Text selection changes
    "AXUIElementDestroyed",   // Element destruction
    "AXCreated",              // Element creation
    "AXRowCountChanged",      // Row count changes
    "AXAnnouncementRequested", // Screen reader announcements
    "AXLayoutChanged",        // Layout updates
    "AXWindowMoved",          // Window movements
    "AXWindowResized",        // Window resizing
]
```

### 2. UI Element Type Filtering

#### Meaningful UI Element Types
```swift
let meaningfulRoles = [
    "AXButton",               // Buttons
    "AXMenuItem",             // Menu items
    "AXTextField",            // Text input fields
    "AXSlider",               // Sliders
    "AXCheckBox",             // Checkboxes
    "AXRadioButton",          // Radio buttons
    "AXMenu",                 // Menus
    "AXToolbar",              // Toolbars
    "AXComboBox",             // Dropdown menus
    "AXTabGroup",             // Tab controls
]
```

#### Noise UI Element Types
```swift
let noiseRoles = [
    "AXUnknown",              // Unknown elements
    "AXStaticText",           // Static text
    "AXGroup",                // Groups (usually just containers)
    "AXScrollArea",           // Scroll areas
    "AXSplitGroup",           // Split panes
    "AXLayoutItem",           // Layout containers
]
```

### 3. Frequency-Based Filtering

#### Debounce Mechanism
```swift
// Record same operation only once within short time window
let debounceTime: TimeInterval = 0.5 // 500ms debounce window

class EventDebouncer {
    private var lastEventTime: [String: Date] = [:]
    
    func shouldRecordEvent(_ event: [String: Any]) -> Bool {
        let eventKey = generateEventKey(event)
        let now = Date()
        
        if let lastTime = lastEventTime[eventKey],
           now.timeIntervalSince(lastTime) < debounceTime {
            return false
        }
        
        lastEventTime[eventKey] = now
        return true
    }
}
```

#### Rate Limiting
```swift
// Limit maximum events per second
let maxEventsPerSecond = 10

class EventRateLimiter {
    private var eventTimestamps: [Date] = []
    
    func shouldRecordEvent() -> Bool {
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)
        
        // Remove old timestamps
        eventTimestamps = eventTimestamps.filter { $0 > oneSecondAgo }
        
        if eventTimestamps.count >= maxEventsPerSecond {
            return false
        }
        
        eventTimestamps.append(now)
        return true
    }
}
```

### 4. Content Change Filtering

#### Value Change Analysis
```swift
func isMeaningfulValueChange(oldValue: String, newValue: String) -> Bool {
    // Ignore empty value changes
    if oldValue.isEmpty && newValue.isEmpty { return false }
    
    // Ignore pure numeric changes (might be auto-calculated)
    if oldValue.isNumeric && newValue.isNumeric { return false }
    
    // Ignore very short changes (might be cursor movement)
    if abs(oldValue.count - newValue.count) <= 1 { return false }
    
    // Ignore changes that are just whitespace
    if oldValue.trimmingCharacters(in: .whitespaces) == 
       newValue.trimmingCharacters(in: .whitespaces) { return false }
    
    return true
}
```

### 5. Context-Aware Filtering

#### Logic Pro Specific Contexts
```swift
let logicProContexts = [
    "track_selection",        // Track selection
    "region_editing",         // Region editing
    "plugin_manipulation",    // Plugin operations
    "transport_control",      // Transport control
    "menu_navigation",        // Menu navigation
    "parameter_adjustment",   // Parameter changes
    "file_operations",        // File open/save operations
]

func getContextForEvent(_ event: [String: Any]) -> String? {
    // Analyze event to determine Logic Pro context
    if let role = event["AXRole"] as? String {
        switch role {
        case "AXButton":
            if let title = event["AXTitle"] as? String {
                if title.contains("Play") || title.contains("Stop") {
                    return "transport_control"
                }
            }
        case "AXSlider":
            return "parameter_adjustment"
        case "AXMenu":
            return "menu_navigation"
        default:
            break
        }
    }
    return nil
}
```

## Implementation Architecture

### Multi-Level Filtering Pipeline

```swift
class EventFilter {
    private let debouncer = EventDebouncer()
    private let rateLimiter = EventRateLimiter()
    
    func shouldRecordEvent(_ event: [String: Any]) -> Bool {
        // Level 1: Event type filtering
        guard let command = event["command"] as? String,
              meaningfulEventTypes.contains(command) else {
            return false
        }
        
        // Level 2: UI element type filtering
        guard let role = event["AXRole"] as? String,
              meaningfulRoles.contains(role) else {
            return false
        }
        
        // Level 3: Content change filtering
        if command == "AXValueChanged" {
            guard isMeaningfulValueChange(event) else { return false }
        }
        
        // Level 4: Frequency filtering
        guard debouncer.shouldRecordEvent(event) else { return false }
        guard rateLimiter.shouldRecordEvent() else { return false }
        
        // Level 5: Context filtering
        guard getContextForEvent(event) != nil else { return false }
        
        return true
    }
}
```

### Semantic Event Recognition

```swift
func semanticizeEvent(_ event: [String: Any]) -> [String: Any] {
    var semanticEvent = event
    
    // Add semantic information
    if let command = event["command"] as? String {
        switch command {
        case "AXMenuOpened":
            semanticEvent["action_type"] = "menu_opened"
            semanticEvent["action_description"] = "Opened menu"
        case "AXValueChanged":
            semanticEvent["action_type"] = "value_changed"
            semanticEvent["action_description"] = "Changed value"
        case "AXButtonPressed":
            semanticEvent["action_type"] = "button_pressed"
            semanticEvent["action_description"] = "Pressed button"
        default:
            semanticEvent["action_type"] = "unknown"
        }
    }
    
    // Add context information
    if let context = getContextForEvent(event) {
        semanticEvent["context"] = context
    }
    
    return semanticEvent
}
```

## Expected Results

### Performance Improvements

- **90%+ noise reduction**: From hundreds of events down to dozens of meaningful events
- **Smaller file sizes**: Reduced storage and transmission costs
- **Faster processing**: Less data to analyze and process
- **Better user experience**: Cleaner, more focused protocol recordings

### Data Quality Improvements

- **Higher signal-to-noise ratio**: Only meaningful user actions are recorded
- **Better pattern recognition**: Easier to identify workflow patterns
- **Improved automation accuracy**: More reliable protocol generation
- **Enhanced debugging**: Cleaner logs for troubleshooting

## Configuration Options

### User-Configurable Settings

```swift
struct FilteringConfiguration {
    var enableEventTypeFiltering: Bool = true
    var enableElementTypeFiltering: Bool = true
    var enableFrequencyFiltering: Bool = true
    var enableContentFiltering: Bool = true
    var enableContextFiltering: Bool = true
    
    var debounceTime: TimeInterval = 0.5
    var maxEventsPerSecond: Int = 10
    var strictMode: Bool = false // More aggressive filtering
}
```

### Debug Mode

```swift
class EventRecorder {
    var debugMode: Bool = false
    
    func recordEvent(_ event: [String: Any]) {
        if debugMode {
            // Record all events for debugging
            rawEvents.append(event)
        }
        
        if shouldRecordEvent(event) {
            filteredEvents.append(semanticizeEvent(event))
        }
    }
}
```

## Implementation Phases

### Phase 1: Basic Filtering
- Implement event type filtering
- Implement UI element type filtering
- Add basic debouncing

### Phase 2: Advanced Filtering
- Add content change analysis
- Implement rate limiting
- Add context awareness

### Phase 3: Optimization
- Fine-tune filtering parameters
- Add user configuration options
- Implement statistical reporting

### Phase 4: Intelligence
- Machine learning-based filtering
- Pattern recognition
- Adaptive filtering based on user behavior

## Monitoring and Analytics

### Filtering Statistics

```swift
struct FilteringStats {
    var totalEvents: Int
    var filteredEvents: Int
    var noiseReductionPercentage: Double
    var averageEventsPerMinute: Double
    var mostCommonEventTypes: [String: Int]
    var mostCommonElementTypes: [String: Int]
}
```

### Quality Metrics

- **Precision**: Percentage of recorded events that are meaningful
- **Recall**: Percentage of meaningful events that are captured
- **F1 Score**: Harmonic mean of precision and recall
- **User Satisfaction**: Feedback on protocol quality

## Conclusion

This comprehensive filtering strategy will significantly improve the quality of recorded protocols by focusing on meaningful user actions while eliminating noise. The multi-level approach ensures robust filtering while maintaining flexibility for different use cases and user preferences.

The implementation should be done progressively, starting with basic filtering and gradually adding more sophisticated techniques based on real-world usage patterns and user feedback.
