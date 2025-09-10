//
//  LogicMonitor.swift
//  logic
//
//  Logic Pro Event Monitor using AXObserver for UI event monitoring
//

import ApplicationServices
import AppKit
import SwiftUI

class LogicMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var lastNotification: String = ""
    @Published var notificationCount: Int = 0
    @Published var currentStatus = "Not started"
    @Published var logicProConnected = false
    @Published var isLearning = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedEventsCount: Int = 0
    
    private var observer: AXObserver?
    private var runLoopSource: CFRunLoopSource?
    private let logicBundleID = "com.apple.logic10"
    
    // Event filtering system
    private var eventFilter: EventFilter
    @Published var filteringStats = FilteringStats()
    @Published var filteringEnabled = true
    
    // Log callback
    var logCallback: ((String) -> Void)?
    
    // Server communication
    private var notificationBuffer: [[String: Any]] = []
    private let bufferSize = 10 // Send every 10 notifications
    private let bufferTimeout: TimeInterval = 5.0 // Or send every 5 seconds
    private var bufferTimer: Timer?
    private let serverURL = "https://logic-copilot-server.vercel.app/api/logs/batch" // Configure your server URL
    private let clientId = "logic-automator-client" // Client identifier
    
    // Session recording
    private var sessionNotifications: [[String: Any]] = []
    private var sessionStartTime: Date?
    private var sessionRecordingEnabled = true
    private var sessionFileURL: URL?
    private var sessionId: String?
    private let maxMemoryNotifications = 1000 // Keep only last 1000 notifications in memory
    
    // Timer for recording duration
    private var recordingTimer: Timer?
    
    // Callback function for AXObserver
    private let callback: AXObserverCallback = { observer, element, notification, context in
        let monitor = Unmanaged<LogicMonitor>.fromOpaque(context!).takeUnretainedValue()
        monitor.handleNotification(observer: observer, element: element, notification: notification)
    }
    
    init() {
        // Initialize event filter with saved configuration or defaults
        var config = FilteringConfiguration()
        
        // Load saved settings
        if let savedEventTypes = UserDefaults.standard.stringArray(forKey: "FilterEventTypes"), !savedEventTypes.isEmpty {
            config.meaningfulEventTypes = Set(savedEventTypes)
        }
        
        if let savedElementTypes = UserDefaults.standard.stringArray(forKey: "FilterElementTypes"), !savedElementTypes.isEmpty {
            config.meaningfulRoles = Set(savedElementTypes)
        }
        
        let savedDebounceTime = UserDefaults.standard.double(forKey: "FilterDebounceTime")
        if savedDebounceTime > 0 {
            config.debounceTime = savedDebounceTime
        }
        
        let savedMaxEvents = UserDefaults.standard.double(forKey: "FilterMaxEvents")
        if savedMaxEvents > 0 {
            config.maxEventsPerSecond = Int(savedMaxEvents)
        }
        
        config.strictMode = UserDefaults.standard.bool(forKey: "FilterStrictMode")
        
        self.eventFilter = EventFilter(configuration: config)
        
        checkLogicProStatus()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring Logic Pro events
    func startMonitoring() {
        // Check permissions
        guard checkAccessibilityPermissions() else {
            log("❌ Accessibility permissions required")
            currentStatus = "Permissions required"
            return
        }
        
        // Check if Logic Pro is running
        guard let logicApp = getLogicProApp() else {
            log("❌ Logic Pro is not running")
            currentStatus = "Logic Pro not running"
            logicProConnected = false
            return
        }
        
        currentStatus = "Starting monitoring..."
        logicProConnected = true
        
        let pid: pid_t = logicApp.processIdentifier
        
        // Create AXObserver
        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let observer = observer else {
            log("❌ Failed to create observer: \(result)")
            currentStatus = "Failed to create observer"
            return
        }
        
        log("✅ Successfully created AXObserver")
        
        // Add notification listeners
        let appElement = AXUIElementCreateApplication(pid)
        addNotifications(to: observer, for: appElement)
        
        // Add to run loop
        runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        isMonitoring = true
        currentStatus = "Monitoring Logic Pro events"
        log("✅ Started monitoring Logic Pro events")
        
        // Start session recording if enabled
        if sessionRecordingEnabled {
            startSessionRecording()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let observer = observer, let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
            self.observer = nil
            self.runLoopSource = nil
        }
        
        isMonitoring = false
        currentStatus = "Monitoring stopped"
        
        // Flush any remaining notifications to server
        flushBuffer()
        
        // Note: Session data is preserved for protocol saving, not uploaded automatically
        
        log("🛑 Stopped monitoring Logic Pro events")
    }
    
    /// Check Logic Pro connection status
    func checkLogicProStatus() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            logicProConnected = true
            currentStatus = "Logic Pro connected"
            log("Logic Pro connected, PID: \(logicApp.processIdentifier)")
        } else {
            logicProConnected = false
            currentStatus = "Logic Pro not running"
            log("Logic Pro is not running")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func getLogicProApp() -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == logicBundleID }
    }
    
    private func addNotifications(to observer: AXObserver, for appElement: AXUIElement) {
        // Available notification constants in macOS Accessibility API
        let notifications = [
            kAXWindowCreatedNotification,           // New window created
            kAXWindowMovedNotification,             // Window moved
            kAXWindowResizedNotification,           // Window resized
            kAXWindowMiniaturizedNotification,      // Window minimized
            kAXWindowDeminiaturizedNotification,    // Window restored from minimized
            kAXTitleChangedNotification,            // Window/element title changed
            kAXFocusedWindowChangedNotification,    // Focused window changed
            kAXFocusedUIElementChangedNotification, // Focused UI element changed
            kAXValueChangedNotification,            // Control value changed
            kAXSelectedChildrenChangedNotification, // Selected children changed
            kAXSelectedTextChangedNotification,     // Selected text changed
            kAXRowCountChangedNotification,         // Table row count changed
            kAXSelectedCellsChangedNotification,    // Selected table cells changed
            kAXMenuOpenedNotification,              // Menu opened
            kAXMenuClosedNotification,              // Menu closed
            kAXMenuItemSelectedNotification,        // Menu item selected
            kAXUIElementDestroyedNotification,      // UI element destroyed
            kAXCreatedNotification,                 // New child element created
            kAXApplicationActivatedNotification,    // Application activated
            kAXApplicationDeactivatedNotification,  // Application deactivated
            kAXApplicationHiddenNotification,       // Application hidden
            kAXApplicationShownNotification,        // Application shown
            kAXDrawerCreatedNotification,           // Drawer created
            kAXSheetCreatedNotification,            // Sheet created
            kAXHelpTagCreatedNotification,          // Help tag created
            kAXElementBusyChangedNotification,      // Element busy state changed
            kAXLayoutChangedNotification,           // Layout changed
            kAXMainWindowChangedNotification,       // Main window changed
            kAXMovedNotification,                   // Element moved
            kAXResizedNotification,                 // Element resized
            kAXRowExpandedNotification,             // Table row expanded
            kAXRowCollapsedNotification,            // Table row collapsed
            kAXSelectedRowsChangedNotification,     // Selected table rows changed
            kAXSelectedColumnsChangedNotification,  // Selected table columns changed
            kAXSelectedChildrenMovedNotification,   // Selected children moved
            kAXUnitsChangedNotification,            // Units changed (for rulers, etc.)
            kAXAnnouncementRequestedNotification    // Screen reader announcement requested
        ]
        
        for notification in notifications {
            let result = AXObserverAddNotification(
                observer,
                appElement,
                notification as CFString,
                Unmanaged.passUnretained(self).toOpaque()
            )
            
            if result == .success {
                log("✅ Added notification: \(notification)")
            } else {
                log("⚠️ Failed to add notification: \(notification) - Error: \(result)")
            }
        }
    }
    
    private func handleNotification(observer: AXObserver, element: AXUIElement, notification: CFString) {
        let notificationName = notification as String
        
        // Get element information - try multiple attributes for better description
        var elementAttributes = getElementAttributes(element)
        elementAttributes["command"] = notificationName
        
        // Apply event filtering if enabled
        if filteringEnabled {
            let (shouldRecord, reason) = eventFilter.shouldRecordEvent(elementAttributes)
            
            if !shouldRecord {
                // Log filtered event for debugging
                let role = elementAttributes["AXRole"] as? String ?? "Unknown"
                log("🚫 Filtered event: \(notificationName) | Role: \(role) | Reason: \(reason ?? "unknown")")
                return
            }
            
            // Add semantic information to the event
            elementAttributes = eventFilter.semanticizeEvent(elementAttributes)
        }
        
        // Add to session recording if enabled
        if sessionRecordingEnabled {
            addToSessionRecording(elementAttributes)
        } else {
            addToBuffer(elementAttributes)
        }
        
        // Get role information for display
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        // Get role description
        var roleDescription: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        let roleDescriptionString = roleDescription as? String ?? "Unknown"
        
        let message = "📢 Notification: \(notificationName) | Role: \(roleString) | RoleDesc: \(roleDescriptionString)"
        
        DispatchQueue.main.async {
            self.lastNotification = message
            self.notificationCount += 1
            
            // Update filtering statistics
            self.filteringStats = self.eventFilter.getStats()
        }
        
        log(message)
    }
    
    /// Get all available attributes as a dictionary for analysis
    private func getElementAttributes(_ element: AXUIElement) -> [String: Any] {
        // Get all attribute names
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        guard result == .success, let names = attributeNames as? [String] else {
            return [:]
        }
        
        var attributesDict: [String: Any] = [:]
        
        // Get values for all attributes
        for name in names {
            var value: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            
            if valueResult == .success {
                // Convert CFTypeRef to JSON-serializable types
                if let convertedValue = convertCFTypeToJSONSerializable(value) {
                    attributesDict[name] = convertedValue
                } else {
                    attributesDict[name] = "Unsupported type: \(type(of: value))"
                }
            } else {
                attributesDict[name] = "Error: \(valueResult.rawValue)"
            }
        }
        
        return attributesDict
    }
    
    /// Convert CFTypeRef to JSON-serializable types to avoid NSObject warnings
    private func convertCFTypeToJSONSerializable(_ value: CFTypeRef?) -> Any? {
        guard let value = value else { return nil }
        
        // Handle basic types
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            // Convert NSNumber to basic types to avoid NSObject
            if CFNumberIsFloatType(numberValue) {
                return numberValue.doubleValue
            } else {
                return numberValue.int64Value
            }
        } else if let boolValue = value as? Bool {
            return boolValue
        } else if CFGetTypeID(value) == CFArrayGetTypeID() {
            // Convert CFArray to Swift Array
            let arrayValue = value as! CFArray
            let count = CFArrayGetCount(arrayValue)
            var swiftArray: [Any] = []
            for i in 0..<count {
                let item = CFArrayGetValueAtIndex(arrayValue, i)
                if let convertedItem = convertCFTypeToJSONSerializable(item as CFTypeRef) {
                    swiftArray.append(convertedItem)
                }
            }
            return swiftArray
        } else if CFGetTypeID(value) == CFDictionaryGetTypeID() {
            // Convert CFDictionary to Swift Dictionary
            let dictValue = value as! CFDictionary
            var swiftDict: [String: Any] = [:]
            let keyCount = CFDictionaryGetCount(dictValue)
            
            // Allocate arrays for keys and values
            let keys = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: keyCount)
            let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: keyCount)
            defer {
                keys.deallocate()
                values.deallocate()
            }
            
            CFDictionaryGetKeysAndValues(dictValue, keys, values)
            
            for i in 0..<keyCount {
                if let keyPtr = keys[i],
                   let valuePtr = values[i],
                   let key = Unmanaged<CFString>.fromOpaque(keyPtr).takeUnretainedValue() as String?,
                   let convertedValue = convertCFTypeToJSONSerializable(valuePtr as CFTypeRef) {
                    swiftDict[key] = convertedValue
                }
            }
            return swiftDict
        } else {
            // For other types, convert to string description
            return String(describing: value)
        }
    }
    
    /// Print all available attributes of an element to console for debugging
    private func printAllElementAttributes(_ element: AXUIElement) {
        print("🔍 === AXUIElement Attributes Debug ===")
        
        // Get all attribute names
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let names = attributeNames as? [String] {
            print("📋 Available attributes (\(names.count)):")
            for (index, name) in names.enumerated() {
                print("  \(index + 1). \(name)")
                
                // Try to get the value for each attribute
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &value)
                
                if valueResult == .success {
                    if let stringValue = value as? String {
                        print("     Value: \"\(stringValue)\"")
                    } else if let numberValue = value as? NSNumber {
                        print("     Value: \(numberValue)")
                    } else if let boolValue = value as? Bool {
                        print("     Value: \(boolValue)")
                    } else if let arrayValue = value as? [Any] {
                        print("     Value: Array with \(arrayValue.count) items")
                    } else if let dictValue = value as? [String: Any] {
                        print("     Value: Dictionary with \(dictValue.count) keys")
                    } else {
                        print("     Value: \(type(of: value)) - \(String(describing: value))")
                    }
                } else {
                    print("     Value: Failed to get value (error: \(valueResult.rawValue))")
                }
            }
        } else {
            print("❌ Failed to get attribute names: \(result.rawValue)")
        }
        
        print("🔍 === End Attributes Debug ===")
    }
    
    /// Find text in child elements (similar to AccessibilityUtil method)
    private func findTextInChildren(_ element: AXUIElement) -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                // Check if child is a text element
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    if role == "AXStaticText" || role == "AXTextField" {
                        // Try to get title from child
                        var title: CFTypeRef?
                        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                        
                        if titleResult == .success, let title = title as? String, !title.isEmpty {
                            return title
                        }
                        
                        // Try to get description from child
                        var description: CFTypeRef?
                        let descResult = AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &description)
                        
                        if descResult == .success, let description = description as? String, !description.isEmpty {
                            return description
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func handleSpecificNotification(_ notification: String, element: AXUIElement, events: [String : Any])-> [String: Any]? {
        switch notification {
        // Window notifications
        case kAXWindowCreatedNotification:
            log("🪟 New window created")
        case kAXWindowMovedNotification:
            log("🪟 Window moved")
        case kAXWindowResizedNotification:
            log("🪟 Window resized")
        case kAXWindowMiniaturizedNotification:
            log("🪟 Window minimized")
        case kAXWindowDeminiaturizedNotification:
            log("🪟 Window restored")
            
        // Title and focus notifications
        case kAXTitleChangedNotification:
            log("🏷️ Title changed")
        case kAXFocusedWindowChangedNotification:
            log("🎯 Focused window changed")
        case kAXFocusedUIElementChangedNotification:
            log("🎯 Focused UI element changed")
            
        // Value and selection notifications
        case kAXValueChangedNotification:
            log("📊 Value changed")
        case kAXSelectedChildrenChangedNotification:
            log("👶 Selected children changed")
        case kAXSelectedTextChangedNotification:
            log("📝 Selected text changed")
            return AXElementDebugger.getSelectedChildren(notification, element)
        case kAXSelectedChildrenMovedNotification:
            log("👶 Selected children moved")
            
        // Menu notifications
        case kAXMenuOpenedNotification:
            log("📋 Menu opened")
            return AXMenuOpenedParser.parse(events, element: element)
        case kAXMenuClosedNotification:
            log("📋 Menu closed")
        case kAXMenuItemSelectedNotification:
            log("📋 Menu item selected")
            
        // Table and row notifications
        case kAXRowCountChangedNotification:
            log("📊 Row count changed")
        case kAXRowExpandedNotification:
            log("📊 Row expanded")
        case kAXRowCollapsedNotification:
            log("📊 Row collapsed")
        case kAXSelectedCellsChangedNotification:
            log("📊 Selected cells changed")
        case kAXSelectedRowsChangedNotification:
            log("📊 Selected rows changed")
        case kAXSelectedColumnsChangedNotification:
            log("📊 Selected columns changed")
            
        // Element lifecycle notifications
        case kAXUIElementDestroyedNotification:
            log("💀 UI element destroyed")
        case kAXCreatedNotification:
            log("✨ New element created")
        case kAXElementBusyChangedNotification:
            log("⏳ Element busy state changed")
            
        // Application notifications
        case kAXApplicationActivatedNotification:
            log("🚀 Application activated")
        case kAXApplicationDeactivatedNotification:
            log("💤 Application deactivated")
        case kAXApplicationHiddenNotification:
            log("👻 Application hidden")
        case kAXApplicationShownNotification:
            log("👁️ Application shown")
            
        // UI element notifications
        case kAXDrawerCreatedNotification:
            log("🗂️ Drawer created")
        case kAXSheetCreatedNotification:
            log("📄 Sheet created")
        case kAXHelpTagCreatedNotification:
            log("❓ Help tag created")
        case kAXLayoutChangedNotification:
            log("🏗️ Layout changed")
        case kAXMainWindowChangedNotification:
            log("🪟 Main window changed")
        case kAXMovedNotification:
            log("📍 Element moved")
        case kAXResizedNotification:
            log("📏 Element resized")
        case kAXUnitsChangedNotification:
            log("📐 Units changed")
        case kAXAnnouncementRequestedNotification:
            log("📢 Announcement requested")
            
        default:
            log("❓ Unknown notification: \(notification)")
        }
        
        return nil
    }
    
    public func log(_ message: String) {
        print("[LogicMonitor] \(message)")
        logCallback?(message)
    }
    
    // MARK: - Server Communication
    
    /// Add notification to buffer and send if needed
    private func addToBuffer(_ notification: [String: Any]) {
        notificationBuffer.append(notification)
        
        // Send if buffer is full
        if notificationBuffer.count >= bufferSize {
            sendBufferToServer()
        }
        
        // Start timer if this is the first notification
        if bufferTimer == nil {
            startBufferTimer()
        }
    }
    
    /// Start timer for periodic buffer sending
    private func startBufferTimer() {
        bufferTimer = Timer.scheduledTimer(withTimeInterval: bufferTimeout, repeats: false) { [weak self] _ in
            self?.sendBufferToServer()
        }
    }
    
    /// Send buffered notifications to server
    private func sendBufferToServer() {
        guard !notificationBuffer.isEmpty else { return }
        
        let notificationsToSend = notificationBuffer
        notificationBuffer.removeAll()
        bufferTimer?.invalidate()
        bufferTimer = nil
        
        // Send to server asynchronously
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.sendNotificationsToServer(notificationsToSend)
        }
    }
    
    /// Send notifications to server via HTTP POST
    private func sendNotificationsToServer(_ notifications: [[String: Any]]) {
        guard let url = URL(string: serverURL) else {
            print("❌ Invalid server URL: \(serverURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create payload with system information matching the example format
        let systemReport = SystemInfoUtil.getLightweightSystemReport()
        let payload: [String: Any] = [
            "client_id": clientId,
            "session_id": sessionId ?? "no-session",
            "system_info": systemReport["system_info"] ?? [:],
            "workflow": systemReport["workflow"] ?? [:],
            "performance": systemReport["performance"] ?? [:],
            "project_info": systemReport["project_info"] ?? [:],
            "protocol_data": systemReport["protocol_data"] ?? [:]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Server request failed: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Server response status: \(httpResponse.statusCode)")
                    print("📡 Server response headers: \(httpResponse.allHeaderFields)")
                    
                    if httpResponse.statusCode == 200 {
                        print("✅ Successfully sent \(notifications.count) notifications to server")
                    } else {
                        print("❌ Server returned status code: \(httpResponse.statusCode)")
                    }
                }
                
                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 Server response body: \(responseString)")
                    } else {
                        print("📡 Server response data (binary): \(data.count) bytes")
                    }
                } else {
                    print("📡 Server response: No data received")
                }
            }
            
            task.resume()
            
        } catch {
            print("❌ Failed to serialize notifications: \(error.localizedDescription)")
        }
    }
    
    /// Force send all buffered notifications (useful for cleanup)
    func flushBuffer() {
        sendBufferToServer()
    }
    
    /// Configure server URL for notifications
    func configureServerURL(_ url: String) {
        // This would require making serverURL mutable, but for now we'll use the constant
        print("📡 Server URL configured: \(url)")
        print("💡 To change server URL, modify the serverURL constant in LogicMonitor.swift")
    }
    
    // MARK: - Learning Mode
    
    /// Start learning mode (recording user actions)
    func startLearning() {
        guard !isLearning else { return }
        
        isLearning = true
        recordedEventsCount = 0
        recordingDuration = 0
        
        // Clear previous session data when starting a new learning session
        // This ensures clean state for new recording
        sessionNotifications.removeAll()
        sessionStartTime = Date()
        sessionFileURL = nil
        sessionId = nil
        
        // Start monitoring if not already active
        if !isMonitoring {
            startMonitoring()
        }
        
        // Start recording timer
        startRecordingTimer()
        
        log("🎓 Started learning mode - recording user actions")
    }
    
    /// Stop learning mode
    func stopLearning() {
        guard isLearning else { return }
        
        isLearning = false
        stopRecordingTimer()
        
        // Stop monitoring to prevent further events
        if isMonitoring {
            stopMonitoring()
        }
        
        log("🎓 Stopped learning mode - recorded \(recordedEventsCount) events")
    }
    
    /// Get all recorded events for protocol saving
    func getAllRecordedEvents() -> [[String: Any]] {
        return readAllNotificationsFromFile()
    }
    
    /// Start recording timer
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                if let startTime = self?.sessionStartTime {
                    self?.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    /// Stop recording timer
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Session Recording
    
    /// Enable session recording mode
    func enableSessionRecording() {
        sessionRecordingEnabled = true
        log("📹 Session recording enabled")
    }
    
    /// Disable session recording mode
    func disableSessionRecording() {
        sessionRecordingEnabled = false
        log("📹 Session recording disabled")
    }
    
    /// Start recording a new session
    private func startSessionRecording() {
        sessionStartTime = Date()
        sessionNotifications.removeAll()
        sessionId = UUID().uuidString
        
        // Create session file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionFileName = "logic_session_\(Int(sessionStartTime!.timeIntervalSince1970)).json"
        sessionFileURL = documentsPath.appendingPathComponent(sessionFileName)
        
        // Create the file immediately
        createSessionFile()
        
        log("📹 Started session recording at \(sessionStartTime?.description ?? "unknown time")")
        log("📁 Session file: \(sessionFileURL?.lastPathComponent ?? "unknown")")
        log("🆔 Session ID: \(sessionId ?? "unknown")")
    }
    
    /// Add notification to session recording
    private func addToSessionRecording(_ notification: [String: Any]) {
        var sessionNotification = notification
        let currentTime = Date().timeIntervalSince1970
        sessionNotification["sessionTimestamp"] = currentTime
        sessionNotification["relativeTime"] = currentTime - (sessionStartTime?.timeIntervalSince1970 ?? 0)
        
        // Add to memory (with size limit)
        sessionNotifications.append(sessionNotification)
        
        // Update event count for learning mode
        if isLearning {
            recordedEventsCount += 1
        }
        
        // Manage memory: keep only recent notifications in memory
        if sessionNotifications.count > maxMemoryNotifications {
            let notificationsToWrite = Array(sessionNotifications.prefix(sessionNotifications.count - maxMemoryNotifications))
            sessionNotifications = Array(sessionNotifications.suffix(maxMemoryNotifications))
            
            // Write older notifications to file
            appendNotificationsToFile(notificationsToWrite)
        }
        
        // Also append current notification to file for persistence
        appendNotificationToFile(sessionNotification)
    }
    
    /// End session recording and upload the complete session
    private func endSessionRecording() {
        guard let startTime = sessionStartTime else {
            log("❌ No active session to end")
            return
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Read all notifications from file and combine with memory
        let fileNotifications = readAllNotificationsFromFile()
        let allNotifications = fileNotifications + sessionNotifications
        
        log("📹 Ending session recording - Duration: \(String(format: "%.2f", duration))s")
        log("📊 Total notifications: \(allNotifications.count) (Memory: \(sessionNotifications.count), File: \(fileNotifications.count))")
        
        // Create session summary with complete system information matching the example format
        let systemReport = SystemInfoUtil.getLightweightSystemReport()
        let sessionData: [String: Any] = [
            "client_id": clientId,
            "session_id": sessionId ?? UUID().uuidString,
            "system_info": systemReport["system_info"] ?? [:],
            "workflow": systemReport["workflow"] ?? [:],
            "performance": systemReport["performance"] ?? [:],
            "project_info": systemReport["project_info"] ?? [:],
            "protocol_data": systemReport["protocol_data"] ?? [:]
        ]
        
        // Upload session data
        uploadSessionToServer(sessionData)
        
        // Keep session data for protocol saving and future reference
        // Data will only be cleared when user starts a new learning session
        log("📋 Session data preserved - will be cleared on next Start Learning")
    }
    
    /// Upload complete session data to server
    private func uploadSessionToServer(_ sessionData: [String: Any]) {
        log("🌐 Attempting to upload session data to: \(serverURL)")
        
        guard let url = URL(string: serverURL) else {
            log("❌ Invalid session server URL: \(serverURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionData, options: [.prettyPrinted, .sortedKeys])
            request.httpBody = jsonData
            
            log("📦 Session data size: \(jsonData.count) bytes")
            
            let task = URLSession.shared.dataTask(with: request) {[weak self] data, response, error in
                if let error = error {
                    self?.log("❌ Session upload failed: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self?.log("✅ Session upload response: \(httpResponse.statusCode)")
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Session upload response status: \(httpResponse.statusCode)")
                    print("📡 Session upload response headers: \(httpResponse.allHeaderFields)")
                    
                    if httpResponse.statusCode == 200 {
                        if let events = sessionData["events"] as? [[String: Any]] {
                            self?.log("✅ Successfully uploaded session with \(events.count) events")
                        } else {
                            print("✅ Successfully uploaded session")
                        }
                    } else {
                        self?.log("❌ Session upload returned status code: \(httpResponse.statusCode)")
                    }
                }
                
                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📡 Session upload response body: \(responseString)")
                    } else {
                        print("📡 Session upload response data (binary): \(data.count) bytes")
                    }
                } else {
                    print("📡 Session upload response: No data received")
                }
            }
            
            task.resume()
            
        } catch {
            log("❌ Failed to serialize session data: \(error.localizedDescription)")
        }
    }
    
    /// Get current session statistics
    func getSessionStats() -> [String: Any] {
        return [
            "recordingEnabled": sessionRecordingEnabled,
            "sessionActive": sessionStartTime != nil,
            "notificationCount": sessionNotifications.count,
            "sessionDuration": sessionStartTime?.timeIntervalSinceNow ?? 0
        ]
    }
    
    /// Force end current session and upload
    func endCurrentSession() {
        if sessionRecordingEnabled && sessionStartTime != nil {
            endSessionRecording()
        }
    }
    
    // MARK: - File Operations
    
    /// Append a single notification to the session file
    private func appendNotificationToFile(_ notification: [String: Any]) {
        guard let fileURL = sessionFileURL else { return }
        
        do {
            // Read existing data from file
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let systemReport = SystemInfoUtil.getLightweightSystemReport()
            var fileData: [String: Any] = [
                "client_id": clientId,
                "session_id": sessionId ?? "unknown",
                "system_info": systemReport["system_info"] ?? [:],
                "workflow": systemReport["workflow"] ?? [:],
                "performance": systemReport["performance"] ?? [:],
                "project_info": systemReport["project_info"] ?? [:],
                "protocol_data": systemReport["protocol_data"] ?? [:]
            ]
            
            if !content.isEmpty {
                if let data = content.data(using: .utf8),
                   let existingData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    fileData = existingData
                }
            }
            
            // Get existing protocol_data and its events
            var protocolData = fileData["protocol_data"] as? [String: Any] ?? [:]
            var events = protocolData["events"] as? [[String: Any]] ?? []
            
            // Add new notification to protocol_data events
            events.append(notification)
            protocolData["events"] = events
            fileData["protocol_data"] = protocolData
            
            // Write back to file with upload format
            let jsonData = try JSONSerialization.data(withJSONObject: fileData, options: [.prettyPrinted])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            
        } catch {
            // If file doesn't exist, create it
            if (error as NSError).code == NSFileReadNoSuchFileError {
                createSessionFile()
                appendNotificationToFile(notification)
            } else {
                log("❌ Failed to append notification to file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Append multiple notifications to the session file
    private func appendNotificationsToFile(_ notifications: [[String: Any]]) {
        guard let fileURL = sessionFileURL else { return }
        
        do {
            // Read existing data from file
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let systemReport = SystemInfoUtil.getLightweightSystemReport()
            var fileData: [String: Any] = [
                "client_id": clientId,
                "session_id": sessionId ?? "unknown",
                "system_info": systemReport["system_info"] ?? [:],
                "workflow": systemReport["workflow"] ?? [:],
                "performance": systemReport["performance"] ?? [:],
                "project_info": systemReport["project_info"] ?? [:],
                "protocol_data": systemReport["protocol_data"] ?? [:]
            ]
            
            if !content.isEmpty {
                if let data = content.data(using: .utf8),
                   let existingData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    fileData = existingData
                }
            }
            
            // Get existing protocol_data and its events
            var protocolData = fileData["protocol_data"] as? [String: Any] ?? [:]
            var events = protocolData["events"] as? [[String: Any]] ?? []
            
            // Add new notifications to protocol_data events
            events.append(contentsOf: notifications)
            protocolData["events"] = events
            fileData["protocol_data"] = protocolData
            
            // Write back to file with upload format
            let jsonData = try JSONSerialization.data(withJSONObject: fileData, options: [.prettyPrinted])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            
        } catch {
            log("❌ Failed to append notifications to file: \(error.localizedDescription)")
        }
    }
    
    /// Create initial session file
    private func createSessionFile() {
        guard let fileURL = sessionFileURL else { return }
        
        do {
            // Create file with upload format structure (including system info)
            let systemReport = SystemInfoUtil.getLightweightSystemReport()
            let initialData: [String: Any] = [
                "client_id": clientId,
                "session_id": sessionId ?? "unknown",
                "system_info": systemReport["system_info"] ?? [:],
                "workflow": systemReport["workflow"] ?? [:],
                "performance": systemReport["performance"] ?? [:],
                "project_info": systemReport["project_info"] ?? [:],
                "protocol_data": systemReport["protocol_data"] ?? [:]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: initialData, options: [.prettyPrinted])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            
            log("📁 Created session file: \(fileURL.lastPathComponent)")
        } catch {
            log("❌ Failed to create session file: \(error.localizedDescription)")
        }
    }
    
    /// Read all notifications from session file
    private func readAllNotificationsFromFile() -> [[String: Any]] {
        guard let fileURL = sessionFileURL else { return [] }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            if content.isEmpty {
                return []
            }
            
            if let data = content.data(using: .utf8),
               let fileData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let protocolData = fileData["protocol_data"] as? [String: Any],
               let events = protocolData["events"] as? [[String: Any]] {
                return events
            }
            
            return []
        } catch {
            log("❌ Failed to read session file: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get session file path for user access
    func getSessionFilePath() -> String? {
        return sessionFileURL?.path
    }
    
    /// Get session file size
    func getSessionFileSize() -> Int64 {
        guard let fileURL = sessionFileURL else { return 0 }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// Get Documents directory path
    func getDocumentsDirectoryPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.path
    }
    
    /// Open Documents directory in Finder
    func openDocumentsDirectoryInFinder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        NSWorkspace.shared.open(documentsPath)
        log("📁 Opened Documents directory: \(documentsPath.path)")
    }
    
    // MARK: - Event Filtering Control
    
    /// Enable or disable event filtering
    func setFilteringEnabled(_ enabled: Bool) {
        filteringEnabled = enabled
        log("🔧 Event filtering \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get current filtering statistics
    func getFilteringStats() -> FilteringStats {
        return eventFilter.getStats()
    }
    
    /// Reset filtering statistics
    func resetFilteringStats() {
        eventFilter.resetStats()
        filteringStats = FilteringStats()
        log("📊 Filtering statistics reset")
    }
    
    /// Enable or disable debug mode for filtering
    func setFilteringDebugMode(_ enabled: Bool) {
        eventFilter.setDebugMode(enabled)
        log("🐛 Filtering debug mode \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get raw events for debugging (only available in debug mode)
    func getRawFilteredEvents() -> [[String: Any]] {
        return eventFilter.getRawEvents()
    }
    
    /// Cleanup filtering system to prevent memory buildup
    func cleanupFiltering() {
        eventFilter.cleanup()
    }
    
    /// Update filter configuration
    func updateFilterConfiguration(_ config: FilteringConfiguration) {
        // Create new event filter with updated configuration
        eventFilter = EventFilter(configuration: config)
        log("🔧 Filter configuration updated with \(config.meaningfulEventTypes.count) event types and \(config.meaningfulRoles.count) element types")
    }
}

// MARK: - SwiftUI Integration

struct LogicMonitorView: View {
    @StateObject private var monitor = LogicMonitor()
    @State private var logMessages: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Logic Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Status display
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(monitor.logicProConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(monitor.logicProConnected ? "Logic Pro Connected" : "Logic Pro Not Running")
                        .font(.headline)
                }
                
                HStack {
                    Circle()
                        .fill(monitor.isMonitoring ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(monitor.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                        .font(.subheadline)
                }
                
                Text(monitor.currentStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                Button("Start Monitoring") {
                    monitor.startMonitoring()
                }
                .disabled(monitor.isMonitoring || !monitor.logicProConnected)
                .buttonStyle(.borderedProminent)
                
                Button("Stop Monitoring") {
                    monitor.stopMonitoring()
                }
                .disabled(!monitor.isMonitoring)
                .buttonStyle(.bordered)
                
                Button("Refresh Status") {
                    monitor.checkLogicProStatus()
                }
                .buttonStyle(.bordered)
            }
            
            // Statistics
            HStack {
                Text("Notification Count: \(monitor.notificationCount)")
                Spacer()
            }
            
            // Latest notification
            if !monitor.lastNotification.isEmpty {
                VStack(alignment: .leading) {
                    Text("Latest Notification:")
                        .font(.headline)
                    Text(monitor.lastNotification)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Log display
            VStack(alignment: .leading) {
                Text("Logs")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logMessages.reversed(), id: \.self) { message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            setupLogging()
        }
    }
    
    private func setupLogging() {
        monitor.logCallback = { message in
            DispatchQueue.main.async {
                logMessages.append(message)
                if logMessages.count > 100 {
                    logMessages.removeFirst(20)
                }
            }
        }
    }
}

#Preview {
    LogicMonitorView()
}
