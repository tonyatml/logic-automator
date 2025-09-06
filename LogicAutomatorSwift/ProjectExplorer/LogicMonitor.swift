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
        
        // Get element information
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String ?? "Unknown"
        
        // Get role information
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        let message = "📢 Notification: \(notificationName) | Role: \(roleString) | Title: \(titleString)"
        
        DispatchQueue.main.async {
            self.lastNotification = message
            self.notificationCount += 1
        }
        
        log(message)
        
        // Handle specific notifications
        handleSpecificNotification(notificationName, element: element)
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
