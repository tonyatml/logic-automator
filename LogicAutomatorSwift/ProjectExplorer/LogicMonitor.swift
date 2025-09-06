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
    
    private var observer: AXObserver?
    private var runLoopSource: CFRunLoopSource?
    private let logicBundleID = "com.apple.logic10"
    
    // Log callback
    var logCallback: ((String) -> Void)?
    
    // Server communication
    private var notificationBuffer: [[String: Any]] = []
    private let bufferSize = 10 // Send every 10 notifications
    private let bufferTimeout: TimeInterval = 5.0 // Or send every 5 seconds
    private var bufferTimer: Timer?
    private let serverURL = "http://localhost:8080/api/notifications" // Configure your server URL
    
    // Callback function for AXObserver
    private let callback: AXObserverCallback = { observer, element, notification, context in
        let monitor = Unmanaged<LogicMonitor>.fromOpaque(context!).takeUnretainedValue()
        monitor.handleNotification(observer: observer, element: element, notification: notification)
    }
    
    init() {
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
        
        handleSpecificNotification(notificationName, element: element)
        
        // Get element information - try multiple attributes for better description
        var elementAttributes = getElementAttributes(element)
        elementAttributes["command"] = notificationName
        
        // Convert attributes dictionary to JSON string for display
        let elementDescription: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: elementAttributes, options: [.prettyPrinted, .sortedKeys])
            elementDescription = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            elementDescription = "{}"
        }

        // Add to buffer for server transmission
        addToBuffer(elementAttributes)
        
        // handle to serve the json string to the server
        print(elementDescription)
        
        // Get role information
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        // Get role description
        var roleDescription: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        let roleDescriptionString = roleDescription as? String ?? "Unknown"
        
        let message = "📢 Notification: \(notificationName) | Role: \(roleString) | RoleDesc: \(roleDescriptionString) "
        
        DispatchQueue.main.async {
            self.lastNotification = message
            self.notificationCount += 1
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
                if let stringValue = value as? String {
                    attributesDict[name] = stringValue
                } else if let numberValue = value as? NSNumber {
                    attributesDict[name] = numberValue
                } else if let boolValue = value as? Bool {
                    attributesDict[name] = boolValue
                } else if let arrayValue = value as? [Any] {
                    // Filter array to only include JSON-serializable values
                    let filteredArray = arrayValue.compactMap { item in
                        if item is String || item is NSNumber || item is Bool {
                            return item
                        } else {
                            return String(describing: item)
                        }
                    }
                    attributesDict[name] = filteredArray
                } else if let dictValue = value as? [String: Any] {
                    // Filter dictionary to only include JSON-serializable values
                    var filteredDict: [String: Any] = [:]
                    for (key, val) in dictValue {
                        if val is String || val is NSNumber || val is Bool {
                            filteredDict[key] = val
                        } else {
                            filteredDict[key] = String(describing: val)
                        }
                    }
                    attributesDict[name] = filteredDict
                } else {
                    // Convert non-serializable types to string
                    attributesDict[name] = String(describing: value)
                }
            } else {
                attributesDict[name] = "Error: \(valueResult.rawValue)"
            }
        }
        
        return attributesDict
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
    
    private func handleSpecificNotification(_ notification: String, element: AXUIElement) {
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
        case kAXSelectedChildrenMovedNotification:
            log("👶 Selected children moved")
            
        // Menu notifications
        case kAXMenuOpenedNotification:
            log("📋 Menu opened")
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
    }
    
    private func log(_ message: String) {
        print("[LogicMonitor] \(message)")
        logCallback?(message)
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
        
        // Create payload
        let payload: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "count": notifications.count,
            "notifications": notifications
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
                    if httpResponse.statusCode == 200 {
                        print("✅ Successfully sent \(notifications.count) notifications to server")
                    } else {
                        print("❌ Server returned status code: \(httpResponse.statusCode)")
                    }
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📡 Server response: \(responseString)")
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
