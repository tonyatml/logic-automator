//
//  EventFilter.swift
//  logic
//
//  Multi-level event filtering system for Logic Pro automation
//  Filters out noise and retains only meaningful user actions
//

import Foundation

/// Configuration for event filtering behavior
struct FilteringConfiguration {
    var enableEventTypeFiltering: Bool = true
    var enableElementTypeFiltering: Bool = true
    var enableFrequencyFiltering: Bool = true
    var enableContentFiltering: Bool = true
    var enableContextFiltering: Bool = true
    
    var debounceTime: TimeInterval = 0.5 // 500ms debounce window
    var maxEventsPerSecond: Int = 10
    var strictMode: Bool = false // More aggressive filtering
    
    // Event type filtering settings - Default high-probability meaningful events
    var meaningfulEventTypes: Set<String> = [
        "AXMenuOpened",           // Menu operations
        "AXMenuClosed",           // Menu closing
        "AXMenuItemSelected",     // Menu item selection
        "AXValueChanged",         // Value changes (needs further filtering)
        "AXFocusedUIElementChanged", // Focus changes (needs further filtering)
        "AXSelectedChildrenChanged", // Selection changes (needs further filtering)
        "AXButtonPressed"         // Button clicks (if available)
    ]
    
    var noiseEventTypes: Set<String> = [
        "AXSelectedTextChanged",  // Text selection changes
        "AXUIElementDestroyed",   // Element destruction
        "AXCreated",              // Element creation
        "AXRowCountChanged",      // Row count changes
        "AXAnnouncementRequested", // Screen reader announcements
        "AXLayoutChanged",        // Layout updates
        "AXWindowMoved",          // Window movements
        "AXWindowResized",        // Window resizing
        "AXMoved",                // Element movements
        "AXResized"               // Element resizing
    ]
    
    // UI element type filtering settings - Default high-probability meaningful elements
    var meaningfulRoles: Set<String> = [
        "AXButton",               // Buttons
        "AXMenuItem",             // Menu items
        "AXTextField",            // Text input fields
        "AXSlider",               // Sliders
        "AXMenu",                 // Menus
        "AXCheckBox",             // Checkboxes
        "AXRadioButton",          // Radio buttons
        "AXGroup"                 // Groups (including track headers and other interactive containers)
    ]
    
    var noiseRoles: Set<String> = [
        "AXUnknown",              // Unknown elements
        "AXStaticText",           // Static text
        "AXScrollArea",           // Scroll areas
        "AXSplitGroup",           // Split panes
        "AXLayoutItem"            // Layout containers
    ]
}

/// Statistics for event filtering performance
struct FilteringStats {
    var totalEvents: Int = 0
    var filteredEvents: Int = 0
    var noiseReductionPercentage: Double {
        guard totalEvents > 0 else { return 0.0 }
        return Double(totalEvents - filteredEvents) / Double(totalEvents) * 100.0
    }
    var averageEventsPerMinute: Double = 0.0
    var mostCommonEventTypes: [String: Int] = [:]
    var mostCommonElementTypes: [String: Int] = [:]
    var filteringReasons: [String: Int] = [:]
    
    mutating func recordEvent(_ event: [String: Any], wasFiltered: Bool, reason: String? = nil) {
        totalEvents += 1
        if !wasFiltered {
            filteredEvents += 1
        }
        
        // Track event types
        if let command = event["command"] as? String {
            mostCommonEventTypes[command, default: 0] += 1
        }
        
        // Track element types
        if let role = event["AXRole"] as? String {
            mostCommonElementTypes[role, default: 0] += 1
        }
        
        // Track filtering reasons
        if let reason = reason {
            filteringReasons[reason, default: 0] += 1
        }
    }
}

/// Event debouncer to prevent duplicate events within short time windows
class EventDebouncer {
    private var lastEventTime: [String: Date] = [:]
    private let debounceTime: TimeInterval
    
    init(debounceTime: TimeInterval = 0.5) {
        self.debounceTime = debounceTime
    }
    
    /// Generate a unique key for an event based on its characteristics
    private func generateEventKey(_ event: [String: Any]) -> String {
        let command = event["command"] as? String ?? "unknown"
        let role = event["AXRole"] as? String ?? "unknown"
        let title = event["AXTitle"] as? String ?? ""
        let identifier = event["AXIdentifier"] as? String ?? ""
        
        return "\(command)_\(role)_\(title)_\(identifier)"
    }
    
    /// Check if an event should be recorded based on debouncing
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
    
    /// Clear old entries to prevent memory buildup
    func cleanup() {
        let now = Date()
        lastEventTime = lastEventTime.filter { now.timeIntervalSince($0.value) < debounceTime * 10 }
    }
}

/// Event rate limiter to prevent excessive event recording
class EventRateLimiter {
    private var eventTimestamps: [Date] = []
    private let maxEventsPerSecond: Int
    
    init(maxEventsPerSecond: Int = 10) {
        self.maxEventsPerSecond = maxEventsPerSecond
    }
    
    /// Check if an event should be recorded based on rate limiting
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

/// Main event filtering class implementing multi-level filtering pipeline
class EventFilter {
    private let configuration: FilteringConfiguration
    private let debouncer: EventDebouncer
    private let rateLimiter: EventRateLimiter
    private var stats = FilteringStats()
    private var debugMode: Bool = false
    
    // Raw events for debugging (only stored in debug mode)
    private var rawEvents: [[String: Any]] = []
    
    init(configuration: FilteringConfiguration = FilteringConfiguration()) {
        self.configuration = configuration
        self.debouncer = EventDebouncer(debounceTime: configuration.debounceTime)
        self.rateLimiter = EventRateLimiter(maxEventsPerSecond: configuration.maxEventsPerSecond)
    }
    
    /// Main filtering method - determines if an event should be recorded
    func shouldRecordEvent(_ event: [String: Any]) -> (shouldRecord: Bool, reason: String?) {
        // Store raw event for debugging if enabled
        if debugMode {
            rawEvents.append(event)
            // Keep only last 1000 events in debug mode
            if rawEvents.count > 1000 {
                rawEvents.removeFirst(200)
            }
        }
        
        // Level 1: Event type filtering
        if configuration.enableEventTypeFiltering {
            if let command = event["command"] as? String {
                if configuration.noiseEventTypes.contains(command) {
                    stats.recordEvent(event, wasFiltered: true, reason: "noise_event_type")
                    return (false, "noise_event_type")
                }
                
                if !configuration.meaningfulEventTypes.contains(command) {
                    stats.recordEvent(event, wasFiltered: true, reason: "unknown_event_type")
                    return (false, "unknown_event_type")
                }
            }
        }
        
        // Level 2: UI element type filtering
        if configuration.enableElementTypeFiltering {
            if let role = event["AXRole"] as? String {
                if configuration.noiseRoles.contains(role) {
                    stats.recordEvent(event, wasFiltered: true, reason: "noise_element_type")
                    return (false, "noise_element_type")
                }
                
                if !configuration.meaningfulRoles.contains(role) {
                    stats.recordEvent(event, wasFiltered: true, reason: "unknown_element_type")
                    return (false, "unknown_element_type")
                }
            }
        }
        
        // Level 3: Content change filtering
        if configuration.enableContentFiltering {
            if let command = event["command"] as? String, command == "AXValueChanged" {
                if !isMeaningfulValueChange(event) {
                    stats.recordEvent(event, wasFiltered: true, reason: "insignificant_value_change")
                    return (false, "insignificant_value_change")
                }
            }
        }
        
        // Level 4: Frequency filtering (debouncing)
        if configuration.enableFrequencyFiltering {
            if !debouncer.shouldRecordEvent(event) {
                stats.recordEvent(event, wasFiltered: true, reason: "debounced")
                return (false, "debounced")
            }
            
            if !rateLimiter.shouldRecordEvent() {
                stats.recordEvent(event, wasFiltered: true, reason: "rate_limited")
                return (false, "rate_limited")
            }
        }
        
        // Level 5: Context filtering
        if configuration.enableContextFiltering {
            if getContextForEvent(event) == nil {
                stats.recordEvent(event, wasFiltered: true, reason: "no_context")
                return (false, "no_context")
            }
        }
        
        // Event passed all filters
        stats.recordEvent(event, wasFiltered: false)
        return (true, nil)
    }
    
    /// Analyze if a value change is meaningful
    private func isMeaningfulValueChange(_ event: [String: Any]) -> Bool {
        guard let oldValue = event["AXValue"] as? String,
              let newValue = event["AXValue"] as? String else {
            return true // If we can't determine, assume it's meaningful
        }
        
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
    
    /// Determine Logic Pro specific context for an event
    private func getContextForEvent(_ event: [String: Any]) -> String? {
        guard let role = event["AXRole"] as? String else { return nil }
        
        switch role {
        case "AXButton":
            if let title = event["AXTitle"] as? String {
                if title.contains("Play") || title.contains("Stop") || title.contains("Record") {
                    return "transport_control"
                }
            }
            return "button_interaction"
            
        case "AXSlider":
            return "parameter_adjustment"
            
        case "AXMenu":
            return "menu_navigation"
            
        case "AXMenuItem":
            return "menu_selection"
            
        case "AXTextField":
            return "text_input"
            
        case "AXCheckBox", "AXRadioButton":
            return "option_toggle"
            
        default:
            return "general_interaction"
        }
    }
    
    /// Add semantic information to an event
    func semanticizeEvent(_ event: [String: Any]) -> [String: Any] {
        var semanticEvent = event
        
        // Add semantic information
        if let command = event["command"] as? String {
            switch command {
            case "AXMenuOpened":
                semanticEvent["action_type"] = "menu_opened"
                semanticEvent["action_description"] = "Opened menu"
            case "AXMenuClosed":
                semanticEvent["action_type"] = "menu_closed"
                semanticEvent["action_description"] = "Closed menu"
            case "AXMenuItemSelected":
                semanticEvent["action_type"] = "menu_item_selected"
                semanticEvent["action_description"] = "Selected menu item"
            case "AXValueChanged":
                semanticEvent["action_type"] = "value_changed"
                semanticEvent["action_description"] = "Changed value"
            case "AXFocusedUIElementChanged":
                semanticEvent["action_type"] = "focus_changed"
                semanticEvent["action_description"] = "Changed focus"
            case "AXSelectedChildrenChanged":
                semanticEvent["action_type"] = "selection_changed"
                semanticEvent["action_description"] = "Changed selection"
            default:
                semanticEvent["action_type"] = "unknown"
                semanticEvent["action_description"] = "Unknown action"
            }
        }
        
        // Add context information
        if let context = getContextForEvent(event) {
            semanticEvent["context"] = context
        }
        
        // Add filtering metadata
        semanticEvent["filtered_at"] = Date().timeIntervalSince1970
        semanticEvent["filter_version"] = "1.0"
        
        return semanticEvent
    }
    
    /// Get current filtering statistics
    func getStats() -> FilteringStats {
        return stats
    }
    
    /// Reset statistics
    func resetStats() {
        stats = FilteringStats()
        rawEvents.removeAll()
    }
    
    /// Enable or disable debug mode
    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        if !enabled {
            rawEvents.removeAll()
        }
    }
    
    /// Get raw events for debugging (only available in debug mode)
    func getRawEvents() -> [[String: Any]] {
        return debugMode ? rawEvents : []
    }
    
    /// Cleanup old data to prevent memory buildup
    func cleanup() {
        debouncer.cleanup()
        if debugMode && rawEvents.count > 1000 {
            rawEvents.removeFirst(200)
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Check if a string represents a numeric value
    var isNumeric: Bool {
        return Double(self) != nil
    }
}
