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
            kAXTitleChangedNotification,            // Window/element title changed
            kAXFocusedWindowChangedNotification,    // Focused window changed
            kAXFocusedUIElementChangedNotification, // Focused UI element changed
            kAXValueChangedNotification,            // Control value changed
            kAXSelectedChildrenChangedNotification, // Selected children changed
            kAXMenuOpenedNotification,              // Menu opened
            kAXMenuClosedNotification               // Menu closed
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
        let elementDescription = getElementDescription(element)
        
        // Get role information
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        // Get role description
        var roleDescription: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        let roleDescriptionString = roleDescription as? String ?? "Unknown"
        
        let message = "📢 Notification: \(notificationName) | Role: \(roleString) | RoleDesc: \(roleDescriptionString) | Description: \(elementDescription)"
        
        DispatchQueue.main.async {
            self.lastNotification = message
            self.notificationCount += 1
        }
        
        log(message)
        
        // Handle specific notifications
        handleSpecificNotification(notificationName, element: element)
    }
    
    /// Get the best available description for an element
    private func getElementDescription(_ element: AXUIElement) -> String {
        // Print all available attributes to console for debugging
        printAllElementAttributes(element)
        
        var descriptions: [String] = []
        
        // Try multiple attributes and collect all non-empty values
        let attributes = [
            ("Description", kAXDescriptionAttribute),
            ("Title", kAXTitleAttribute),
            ("Value", kAXValueAttribute),
            ("Help", kAXHelpAttribute),
            ("Identifier", kAXIdentifierAttribute),
            ("Subrole", kAXSubroleAttribute)
        ]
        
        for (name, attribute) in attributes {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            if result == .success, let stringValue = value as? String, !stringValue.isEmpty {
                descriptions.append("\(name): \(stringValue)")
            }
        }
        
        // If we have multiple descriptions, combine them
        if descriptions.count > 1 {
            return descriptions.joined(separator: " | ")
        } else if descriptions.count == 1 {
            return descriptions[0]
        }
        
        // If no direct attribute works, try to find text in child elements
        if let childText = findTextInChildren(element) {
            return "ChildText: \(childText)"
        }
        
        return "Unknown"
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
        case kAXWindowCreatedNotification as String:
            log("🪟 New window created")
            
        case kAXTitleChangedNotification as String:
            log("🏷️ Title changed")
            
        case kAXFocusedWindowChangedNotification as String:
            log("🎯 Focused window changed")
            
        case kAXFocusedUIElementChangedNotification as String:
            log("🎯 Focused UI element changed")
            
        case kAXValueChangedNotification as String:
            log("📊 Value changed")
            
        case kAXSelectedChildrenChangedNotification as String:
            log("👶 Selected children changed")
            
        case kAXMenuOpenedNotification as String:
            log("📋 Menu opened")
            
        case kAXMenuClosedNotification as String:
            log("📋 Menu closed")
            
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
