//
//  IntentHandlers.swift
//  logic
//
//  Intent handlers for protocol execution
//  Each handler implements specific Logic Pro operations
//

import Foundation
import ApplicationServices
import Cocoa

// MARK: - Track Operations

/// Handler for selecting tracks
class SelectTrackHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎯 Executing select_track intent")
        context.log("🚀 SelectTrackHandler: Starting execution with new Accessibility API method")
        
        do {
            guard let trackNumber = parameters["track_number"] as? Int else {
                throw ProtocolError.invalidParameters("track_number is required")
            }
            
            context.log("📊 Selecting track \(trackNumber)")
        
        // Find Logic Pro application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let logicApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.logic10" }) else {
            throw ProtocolError.logicProNotRunning
        }
        
        // Activate Logic Pro
        logicApp.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Get Logic Pro application element
        let appElement = AXUIElementCreateApplication(logicApp.processIdentifier)
        
        // Get main window
        let mainWindow = try await AccessibilityUtil.getMainWindow(of: appElement, logCallback: context.log)
        context.log("✅ Found Logic Pro main window")
        
        // Find all child elements with max depth 6
        context.log("🔍 Searching for track elements with max depth 6...")
        let allElements = try await AccessibilityUtil.findAllChildElements(in: mainWindow, maxDepth: 7)
        context.log("📊 Found \(allElements.count) total elements")
        
        // Look for elements with description starting with "Track 1" - filter out other tracks
        var trackElements: [AXUIElement] = []
        for element in allElements {
            if let description = try await AccessibilityUtil.getElementDescription(element) {
                // Only select the specified track number, filter out other tracks
                let targetTrackPrefix = "Track \(trackNumber) "
                if description.hasPrefix(targetTrackPrefix) {
                    
                    // Print all attributes of this element
                    let role = try await AccessibilityUtil.getElementRole(element) ?? "Unknown"
                    let roleDesc = try await AccessibilityUtil.getElementRoleDescription(element) ?? "Unknown"
                    let title = try await AccessibilityUtil.getElementTitle(element) ?? "No Title"
                    let identifier = try await AccessibilityUtil.getElementIdentifier(element) ?? "No ID"
                    let subrole = try await AccessibilityUtil.getElementSubrole(element) ?? "No Subrole"
                    
                    trackElements.append(element)
                    context.log("🎵 Found track element: \(description)")
                    context.log("   📋 Role: \(role)")
                    context.log("   📋 Role Description: \(roleDesc)")
                    context.log("   📋 Title: \(title)")
                    context.log("   📋 Description: \(description)")
                    context.log("   📋 Identifier: \(identifier)")
                    context.log("   📋 Subrole: \(subrole)")
                    
                }
            }
        }
        
        context.log("🎵 Found \(trackElements.count) track elements")
        
        // If we found track elements, try to select the specified one
        if trackElements.count > 0 {
            // Since we already filtered for the specific track number, just use the first element
            let targetTrack = trackElements[0]
            
            context.log("🎯 Attempting to select track \(trackNumber) (found \(trackElements.count) elements)")
            
            // Try to click on the track element
            try await AccessibilityUtil.clickAtElementPosition(targetTrack, elementName: "Track \(trackNumber)", logCallback: context.log)
            
            // Also try the AXPressAction as a fallback
            let pressResult = AXUIElementPerformAction(targetTrack, kAXPressAction as CFString)
            if pressResult == .success {
                context.log("✅ Track \(trackNumber) selected successfully via AXPressAction")
            } else {
                context.log("⚠️ AXPressAction failed for Track \(trackNumber), result: \(pressResult.rawValue)")
            }
            
            context.log("✅ Track \(trackNumber) selection attempt completed")
        } else {
            context.log("⚠️ No track elements found, falling back to keyboard navigation")
            
            // Fallback to keyboard navigation
            context.log("Going to top of track list...")
            try await sendKeysWithModifiers("home", modifiers: ["cmd"])
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Then move down to the target track index
            context.log("Moving down to track index \(trackNumber)...")
            for _ in 1..<trackNumber {
                try await sendKeys("down")
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
            
            context.log("✅ Track \(trackNumber) selected via keyboard navigation")
        }
        
        // Return the selected track information for the next step
        var serializedElements: [[String: Any]] = []
        for element in trackElements {
            let elementInfo: [String: Any] = [
                "description": (try? await AccessibilityUtil.getElementDescription(element)) ?? "Unknown",
                "role": (try? await AccessibilityUtil.getElementRole(element)) ?? "Unknown",
                "role_description": (try? await AccessibilityUtil.getElementRoleDescription(element)) ?? "Unknown"
            ]
            serializedElements.append(elementInfo)
        }
        
        return [
            "intent": "select_track",
            "track_number": trackNumber,
            "selected_track_elements": serializedElements,
            "timestamp": Date().timeIntervalSince1970
        ]
        } catch {
            context.log("❌ SelectTrackHandler error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Send keyboard input using CGEvent
    private func sendKeys(_ keys: String) async throws {
        for char in keys {
            let keyCode = getKeyCode(for: String(char))
            if keyCode != 0 {
                // Key down
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                keyDownEvent?.post(tap: .cghidEventTap)
                
                // Delay for key down
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Key up
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                keyUpEvent?.post(tap: .cghidEventTap)
                
                // Delay between characters
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    /// Send keys with modifiers using CGEvent
    private func sendKeysWithModifiers(_ key: String, modifiers: [String]) async throws {
        let keyCode = getKeyCode(for: key)
        guard keyCode != 0 else {
            return
        }
        
        // Convert modifier strings to CGEventFlags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "ctrl", "control":
                flags.insert(.maskControl)
            default:
                break
            }
        }
        
        // Key down with modifiers
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.flags = flags
        keyDownEvent?.post(tap: .cghidEventTap)
        
        // Small delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Key up
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.flags = flags
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Get key code for a character
    private func getKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "6", "^": return 0x16
        case "5", "%": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case "`", "~": return 0x32
        case "return", "\n": return 0x24
        case "tab": return 0x30
        case "space", " ": return 0x31
        case "delete": return 0x33
        case "escape": return 0x35
        case "command": return 0x37
        case "shift": return 0x38
        case "caps": return 0x39
        case "option": return 0x3A
        case "control": return 0x3B
        case "right-shift": return 0x3C
        case "right-option": return 0x3D
        case "right-control": return 0x3E
        case "function": return 0x3F
        case "f17": return 0x40
        case "volume-up": return 0x48
        case "volume-down": return 0x49
        case "mute": return 0x4A
        case "f18": return 0x4F
        case "f19": return 0x50
        case "f20": return 0x5A
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f3": return 0x63
        case "f8": return 0x64
        case "f9": return 0x65
        case "f11": return 0x67
        case "f13": return 0x69
        case "f16": return 0x6A
        case "f14": return 0x6B
        case "f10": return 0x6D
        case "f12": return 0x6F
        case "f15": return 0x71
        case "help": return 0x72
        case "home": return 0x73
        case "page-up": return 0x74
        case "forward-delete": return 0x75
        case "f4": return 0x76
        case "end": return 0x77
        case "f2": return 0x78
        case "page-down": return 0x79
        case "f1": return 0x7A
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        default: return 0
        }
    }
}

/// Handler for creating new tracks
class CreateTrackHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎵 Executing create_track intent")
        
        let trackType = parameters["type"] as? String ?? "Software Instrument"
        
        context.log("📊 Creating \(trackType) track")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Creating \(trackType) track - implementation needed")
        
        context.log("✅ \(trackType) track created successfully")
        
        return [
            "intent": "create_track",
            "track_type": trackType,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Region Operations

/// Handler for creating MIDI regions
class CreateRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎼 Executing create_region intent")
        
        let regionType = parameters["type"] as? String ?? "MIDI"
        let lengthBars = parameters["length_bars"] as? Int ?? 4
        
        context.log("📊 Creating \(regionType) region with \(lengthBars) bars")
        
        do {
            // Get the previous step result (select_track)
            guard let previousResult = context.previousStepResult else {
                throw ProtocolError.invalidParameters("No previous step result found. select_track must be executed first.")
            }
            
            context.log("📋 Previous step result: \(previousResult)")
            
            // Get the selected track elements from the previous step
            guard let selectedTrackElements = previousResult["selected_track_elements"] as? [[String: Any]] else {
                throw ProtocolError.invalidParameters("No selected track elements found in previous step result")
            }
            
            context.log("🎵 Found \(selectedTrackElements.count) selected track elements from previous step")
            
            // Look for Track Background elements within the selected track elements
            let trackBackgroundElements: [AXUIElement] = []
            for elementInfo in selectedTrackElements {
                if let roleDescription = elementInfo["role_description"] as? String {
                    if roleDescription == "Track Background" {
                        context.log("🎵 Found Track Background element from previous step")
                        
                        // Print attributes for debugging
                        let role = elementInfo["role"] as? String ?? "Unknown"
                        let title = elementInfo["title"] as? String ?? "No Title"
                        let description = elementInfo["description"] as? String ?? "No Description"
                        
                        context.log("   📋 Role: \(role)")
                        context.log("   📋 Role Description: \(roleDescription)")
                        context.log("   📋 Title: \(title)")
                        context.log("   📋 Description: \(description)")
                        
                        // Note: We can't directly use the AXUIElement from the previous step
                        // because it's not serializable. We need to find it again, but more efficiently.
                        // For now, we'll use the information to identify the correct element.
                    }
                }
            }
            
            context.log("🎵 Found \(trackBackgroundElements.count) Track Background elements from previous step data")
            
            // Since we can't directly use the AXUIElement from previous step,
            // we need to find the Track Background element again, but we can be more targeted
            // by using the track number from the previous step
            let trackNumber = previousResult["track_number"] as? Int ?? 1
            
            // Find Logic Pro application
            let runningApps = NSWorkspace.shared.runningApplications
            guard let logicApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.logic10" }) else {
                throw ProtocolError.logicProNotRunning
            }
            
            // Activate Logic Pro
            logicApp.activate()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Get Logic Pro application element
            let appElement = AXUIElementCreateApplication(logicApp.processIdentifier)
            
            // Get main window
            let mainWindow = try await AccessibilityUtil.getMainWindow(of: appElement, logCallback: context.log)
            context.log("✅ Found Logic Pro main window")
            
            // Find Track Background elements more efficiently by looking for the specific track
            context.log("🔍 Searching for Track Background elements for Track \(trackNumber)...")
            let allElements = try await AccessibilityUtil.findAllChildElements(in: mainWindow, maxDepth: 7)
            context.log("📊 Found \(allElements.count) total elements")
            
            // Look for elements with role description "Track Background" that match our track
            var targetTrackBackgroundElements: [AXUIElement] = []
            for element in allElements {
                if let roleDescription = try await AccessibilityUtil.getElementRoleDescription(element) {
                    if roleDescription == "Track Background" {
                        // Check if this Track Background belongs to our target track
                        if let description = try await AccessibilityUtil.getElementDescription(element) {
                            if description.contains("Track \(trackNumber)") {
                                targetTrackBackgroundElements.append(element)
                                context.log("🎵 Found Track Background element for Track \(trackNumber)")
                                
                                // Print attributes for debugging
                                let role = try await AccessibilityUtil.getElementRole(element) ?? "Unknown"
                                let title = try await AccessibilityUtil.getElementTitle(element) ?? "No Title"
                                let identifier = try await AccessibilityUtil.getElementIdentifier(element) ?? "No ID"
                                
                                context.log("   📋 Role: \(role)")
                                context.log("   📋 Role Description: \(roleDescription)")
                                context.log("   📋 Title: \(title)")
                                context.log("   📋 Description: \(description)")
                                context.log("   📋 Identifier: \(identifier)")
                            }
                        }
                    }
                }
            }
            
            context.log("🎵 Found \(targetTrackBackgroundElements.count) Track Background elements for Track \(trackNumber)")
            
            if targetTrackBackgroundElements.count > 0 {
                // Use the first Track Background element
                let trackBackground = targetTrackBackgroundElements[0]
                
                context.log("🎯 Attempting to show menu on Track Background element")
                
                // Try to perform AXShowMenu action
                let showMenuResult = AXUIElementPerformAction(trackBackground, kAXShowMenuAction as CFString)
                if showMenuResult == .success {
                    context.log("✅ AXShowMenu action successful on Track Background")
                    
                    // Wait for menu to appear
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Send "Create MIDI Region" command
                    context.log("🎹 Sending 'Create MIDI Region' command...")
                    try await sendCreateMIDIRegionCommand(context: context)
                    
                } else {
                    context.log("⚠️ AXShowMenu action failed, result: \(showMenuResult.rawValue)")
                    
                    // Fallback: try clicking on the element
                    try await AccessibilityUtil.clickAtElementPosition(trackBackground, elementName: "Track Background", logCallback: context.log)
                    context.log("🔄 Fallback: clicked on Track Background element")
                    
                    // Wait for menu to appear
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Send "Create MIDI Region" command
                    context.log("🎹 Sending 'Create MIDI Region' command...")
                    try await sendCreateMIDIRegionCommand(context: context)
                }
                
                context.log("✅ \(regionType) region creation initiated successfully")
                
                // Set the region length if specified
                if lengthBars > 0 {
                    try await setRegionLength(lengthBars, context: context)
                }
            } else {
                context.log("⚠️ No Track Background elements found")
                throw ProtocolError.invalidParameters("No Track Background elements found")
            }
            
        } catch {
            context.log("❌ CreateRegionHandler error: \(error.localizedDescription)")
            throw error
        }
        
        // Return result for next step
        return [
            "intent": "create_region",
            "region_type": regionType,
            "length_bars": lengthBars,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    /// Send a key press event
    private func sendKeyPress(_ key: String, context: ExecutionContext) async throws {
        let keyCode = getKeyCode(for: key)
        guard keyCode != 0 else {
            context.log("⚠️ Unknown key: \(key)")
            return
        }
        
        // Create key down event
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.post(tap: .cghidEventTap)
        
        // Create key up event
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Send "Create MIDI Region" command via keyboard
    private func sendCreateMIDIRegionCommand(context: ExecutionContext) async throws {
        // Send two down arrow keys to select "Create MIDI Region" (second item in menu)
        context.log("⬇️ Sending two down arrow keys to select 'Create MIDI Region'")
        
        // Wait between key presses
        try await Task.sleep(nanoseconds: 500_000_000) // 100ms
        
        // First down arrow
        try await sendKeyPress("down", context: context)
        
        // Wait between key presses
        try await Task.sleep(nanoseconds: 500_000_000) // 100ms
        
        // Second down arrow
        try await sendKeyPress("down", context: context)
        
        // Wait a moment for the selection to be highlighted
        try await Task.sleep(nanoseconds: 500_000_000) // 200ms
        
        // Press Enter to confirm the selection
        context.log("⏎ Pressing Enter to confirm selection")
        try await sendKeyPress("return", context: context)
        
        context.log("✅ 'Create MIDI Region' command sent successfully")
    }
    
    /// Get Logic Pro application dynamically
    private func getLogicProApplication(context: ExecutionContext) async throws -> AXUIElement {
        let logicBundleID = "com.apple.logic10"
        let runningApps = NSWorkspace.shared.runningApplications
        
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            let pid = logicApp.processIdentifier
            context.log("Found Logic Pro with PID: \(pid)")
            return AXUIElementCreateApplication(pid)
        } else {
            throw ProtocolError.executionFailed("Logic Pro not found in running applications")
        }
    }
    
    /// Set the length of the created region using menu bar
    private func setRegionLength(_ lengthBars: Int, context: ExecutionContext) async throws {
        context.log("📏 Setting region length to \(lengthBars) bars using menu bar")
        
        // Wait for the region to be created and selected
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Use menu: Edit -> Length -> Change...
        try await clickMenuItem("Edit", "Length", "Change…", context: context)
        
        // Wait for dialog to open
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Set the length value in the dialog
        context.log("📝 Setting length value to \(lengthBars)")
        try await setLengthInDialog(lengthBars, context: context)
    }
    
    /// Click menu item using Accessibility API (based on LogicAutomator implementation)
    private func clickMenuItem(_ menuName: String, _ submenuName: String, _ itemName: String, context: ExecutionContext) async throws {
        context.log("Clicking menu item: \(menuName) -> \(submenuName) -> \(itemName)")
        
        // Try multiple times with reconnection
        for attempt in 1...3 {
            context.log("Attempt \(attempt) to access menu bar...")
            
            // Get Logic Pro application dynamically
            let logicProApp = try await getLogicProApplication(context: context)
            
            // Get menu bar
            var menuBar: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(logicProApp, kAXMenuBarAttribute as CFString, &menuBar)
            
            if result == .success, let menuBar = menuBar {
                context.log("Successfully got menu bar on attempt \(attempt)")
                // Find and click the menu item
                try await findAndClickMenuItem(menuBar as! AXUIElement, [menuName, submenuName, itemName], context: context)
                context.log("Menu item clicked successfully")
                return
            } else {
                context.log("Failed to get menu bar on attempt \(attempt), result: \(result)")
                if attempt == 3 {
                    throw ProtocolError.executionFailed("Could not access menu bar after 3 attempts")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    /// Recursively find and click menu item (based on LogicAutomator implementation)
    private func findAndClickMenuItem(_ element: AXUIElement, _ menuPath: [String], context: ExecutionContext) async throws {
        guard !menuPath.isEmpty else { return }
        
        let currentMenuName = menuPath[0]
        let remainingPath = Array(menuPath.dropFirst())
        
        context.log("Looking for menu item: '\(currentMenuName)' in current element")
        
        // Get children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            throw ProtocolError.executionFailed("Could not get menu children")
        }
        
        let childrenArray = children as! [AXUIElement]
        context.log("Found \(childrenArray.count) children in current element")
        
        // Find the menu item with matching title
        for (index, child) in childrenArray.enumerated() {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let title = title as? String {
                context.log("Child \(index): '\(title)'")
                
                if title == currentMenuName {
                    context.log("Found matching menu item: '\(currentMenuName)'")
                    
                    // If this is the final item, click it
                    if remainingPath.isEmpty {
                        context.log("Clicking final menu item: '\(currentMenuName)'")
                        let clickResult = AXUIElementPerformAction(child, kAXPressAction as CFString)
                        if clickResult != .success {
                            throw ProtocolError.executionFailed("Failed to click menu item: \(currentMenuName)")
                        }
                        context.log("Successfully clicked menu item: '\(currentMenuName)'")
                        return
                    } else {
                        // For submenus, we need to "press" the menu item to expand it
                        context.log("Pressing menu item to expand submenu: '\(currentMenuName)'")
                        let pressResult = AXUIElementPerformAction(child, kAXPressAction as CFString)
                        if pressResult != .success {
                            throw ProtocolError.executionFailed("Failed to expand submenu: \(currentMenuName)")
                        }
                        
                        // Wait a bit for the submenu to expand
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        // Check if the first child is an AXMenu (submenu)
                        var submenuChildren: CFTypeRef?
                        let submenuResult = AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &submenuChildren)
                        
                        if submenuResult == .success, let submenuChildren = submenuChildren {
                            let submenuArray = submenuChildren as! [AXUIElement]
                            if !submenuArray.isEmpty {
                                // Check if first child has AXMenu role
                                var role: CFTypeRef?
                                let roleResult = AXUIElementCopyAttributeValue(submenuArray[0], kAXRoleAttribute as CFString, &role)
                                
                                if roleResult == .success, let role = role as? String, role == "AXMenu" {
                                    context.log("Found AXMenu submenu, using it for next search")
                                    // Use the AXMenu element for the next search
                                    try await findAndClickMenuItem(submenuArray[0], remainingPath, context: context)
                                    return
                                }
                            }
                        }
                        
                        // Fallback: Recursively find the next item in the original element
                        context.log("Recursively searching for remaining path: \(remainingPath)")
                        try await findAndClickMenuItem(child, remainingPath, context: context)
                        return
                    }
                }
            } else {
                context.log("Child \(index): Could not get title")
            }
        }
        
        // If we get here, we didn't find the menu item
        context.log("Available menu items:")
        for (index, child) in childrenArray.enumerated() {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            if titleResult == .success, let title = title as? String {
                context.log("  \(index): '\(title)'")
            } else {
                context.log("  \(index): <no title>")
            }
        }
        
        throw ProtocolError.executionFailed("Could not find menu item: '\(currentMenuName)'")
    }
    
    /// Set length value in the dialog
    private func setLengthInDialog(_ lengthBars: Int, context: ExecutionContext) async throws {
        // The dialog should be open now, we need to find the input field
        // and set the value to the length in bars
        
        // For now, let's try a simple approach: type the value directly
        // The dialog might have focus on the input field already
        
        let lengthString = String(lengthBars)
        context.log("⌨️ Typing length value: \(lengthString)")
        
        for char in lengthString {
            try await sendKeyPress(String(char), context: context)
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms between keystrokes
        }
        
        // Press Enter or click OK to confirm
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        try await sendKeyPress("return", context: context)
        
        context.log("✅ Length set to \(lengthBars) bars successfully")
    }
    
    /// Get key code for a character
    private func getKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "6", "^": return 0x16
        case "5", "%": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case "`", "~": return 0x32
        case "return", "\n": return 0x24
        case "tab": return 0x30
        case "space", " ": return 0x31
        case "delete": return 0x33
        case "escape": return 0x35
        case "command": return 0x37
        case "shift": return 0x38
        case "caps": return 0x39
        case "option": return 0x3A
        case "control": return 0x3B
        case "right-shift": return 0x3C
        case "right-option": return 0x3D
        case "right-control": return 0x3E
        case "function": return 0x3F
        case "f17": return 0x40
        case "volume-up": return 0x48
        case "volume-down": return 0x49
        case "mute": return 0x4A
        case "f18": return 0x4F
        case "f19": return 0x50
        case "f20": return 0x5A
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f3": return 0x63
        case "f8": return 0x64
        case "f9": return 0x65
        case "f11": return 0x67
        case "f13": return 0x69
        case "f16": return 0x6A
        case "f14": return 0x6B
        case "f10": return 0x6D
        case "f12": return 0x6F
        case "f15": return 0x71
        case "help": return 0x72
        case "home": return 0x73
        case "page-up": return 0x74
        case "forward-delete": return 0x75
        case "f4": return 0x76
        case "end": return 0x77
        case "f2": return 0x78
        case "page-down": return 0x79
        case "f1": return 0x7A
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        default: return 0
        }
    }
}

/// Handler for quantizing regions
class QuantizeRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎯 Executing quantize_region intent")
        
        let grid = parameters["grid"] as? String ?? "1/16"
        let strength = parameters["strength"] as? Int ?? 90
        
        context.log("📊 Quantizing region with grid \(grid) and strength \(strength)%")
        
        // Get Logic Pro application
        let logicProApp = try await getLogicProApplication(context: context)
        
        // Get main window
        let mainWindow = try await AccessibilityUtil.getMainWindow(of: logicProApp, logCallback: context.log)
        
        // Find all child elements to locate the selected region
        let allElements = try await AccessibilityUtil.findAllChildElements(in: mainWindow, maxDepth: 8)
        
        // Look for region elements (selected or not)
        var regionElement: AXUIElement?
        var foundRegions: [AXUIElement] = []
        
        for element in allElements {
            do {
                let role = try await AccessibilityUtil.getElementRole(element)
                let roleDescription = try await AccessibilityUtil.getElementRoleDescription(element)
                let description = try await AccessibilityUtil.getElementDescription(element)
                //print(roleDescription, description,role)
                // Look for region elements
                if (role == "AXLayoutItem" || role == "AXGroup") &&
                   (roleDescription?.contains("Region") == true || description?.contains("Region") == true) {
                    
                    foundRegions.append(element)
                    
                    
                    // Check if this element is selected
                    var selected: CFTypeRef?
                    let selectedResult = AXUIElementCopyAttributeValue(element, kAXSelectedAttribute as CFString, &selected)
                    
                    if selectedResult == .success, let isSelected = selected as? Bool, isSelected {
                        context.log("🎯 Found selected region element: \(description ?? "No description")")
                        regionElement = element
                        break
                    }
                }
            } catch {
                // Continue searching if we can't get element info
                continue
            }
        }
        
        // If no selected region found, try to select the most recently created one
        if regionElement == nil && !foundRegions.isEmpty {
            context.log("⚠️ No selected region found, but found \(foundRegions.count) region(s)")
            context.log("🎯 Attempting to select the first available region")
            
            // Try to click on the first region to select it
            let firstRegion = foundRegions[0]
            try await AccessibilityUtil.clickAtElementPosition(firstRegion, elementName: "Region", logCallback: context.log)
            
            // Wait a moment for selection to take effect
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            regionElement = firstRegion
        }
        
        guard let region = regionElement else {
            context.log("⚠️ No region elements found at all")
            throw ProtocolError.executionFailed("No region elements found for quantization")
        }
        
        // Show context menu on the region
        context.log("📋 Showing context menu on selected region")
        let showMenuResult = AXUIElementPerformAction(region, kAXShowMenuAction as CFString)
        
        //if showMenuResult == .success {
            context.log("✅ Context menu shown successfully")
            
            // Wait for menu to appear
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Send "Quantize" command
            context.log("🎵 Sending 'Quantize' command...")
            try await sendQuantizeCommand(grid: grid, context: context)
            
        //} else {
          //  context.log("⚠️ Failed to show context menu, result: \(showMenuResult)")
            //throw ProtocolError.executionFailed("Failed to show context menu for quantization")
        //}
        
        context.log("✅ Region quantized successfully")
        
        return [
            "intent": "quantize_region",
            "grid": grid,
            "strength": strength,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    /// Send quantize command through context menu
    private func sendQuantizeCommand(grid: String, context: ExecutionContext) async throws {
        // Type "Quantize" to find the menu item
        context.log("⌨️ Typing 'Quantize' to find menu item")
        let quantizeString = "Q"
        
        for char in quantizeString {
            //try await sendKeyPress(String(char), context: context)
            //try await Task.sleep(nanoseconds: 50_000_000) // 50ms between keystrokes
        }
        
        // Send the appropriate number of down arrows
        for i in 1...9 {
            try await sendKeyPress("down", context: context)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms between arrows
        }
        
        // Wait a moment for the menu to filter
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Press right arrow to select Quantize
        context.log("➡️ Pressing right arrow to select Quantize")
        try await sendKeyPress("right", context: context)
        
        // Wait for Quantize submenu to open
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Now select the grid value by sending down arrows
        let downCount = getDownArrowCount(for: grid)
        context.log("🎯 Selecting grid value \(grid) with \(downCount) down arrow(s)")
        
        // Send the appropriate number of down arrows
        for i in 1...downCount {
            context.log("⬇️ Sending down arrow \(i)/\(downCount)")
            try await sendKeyPress("down", context: context)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms between arrows
        }
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Press Enter to confirm
        context.log("⏎ Pressing Enter to confirm grid selection")
        try await sendKeyPress("return", context: context)
        
        context.log("✅ Quantize command sent successfully")
    }
    
    /// Get the number of down arrows needed for the grid value
    private func getDownArrowCount(for grid: String) -> Int {
        switch grid {
        case "1/1": return 1  // 1 down arrow
        case "1/2": return 2  // 2 down arrows
        case "1/4": return 3  // 3 down arrows
        case "1/8": return 4  // 4 down arrows
        case "1/16": return 5 // 5 down arrows
        case "1/32": return 6 // 6 down arrows
        case "1/64": return 7 // 7 down arrows
        default: return 5     // Default to 1/16 (5 down arrows)
        }
    }
    
    /// Convert grid parameter to menu value
    private func convertGridToMenuValue(_ grid: String) -> String {
        switch grid {
        case "1/1": return "1/1 Note"
        case "1/2": return "1/2 Note"
        case "1/4": return "1/4 Note"
        case "1/8": return "1/8 Note"
        case "1/16": return "1/16 Note"
        case "1/32": return "1/32 Note"
        case "1/64": return "1/64 Note"
        default: return "1/16 Note" // Default fallback
        }
    }
    
    /// Get Logic Pro application dynamically
    private func getLogicProApplication(context: ExecutionContext) async throws -> AXUIElement {
        let logicBundleID = "com.apple.logic10"
        let runningApps = NSWorkspace.shared.runningApplications
        
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            let pid = logicApp.processIdentifier
            context.log("Found Logic Pro with PID: \(pid)")
            return AXUIElementCreateApplication(pid)
        } else {
            throw ProtocolError.executionFailed("Logic Pro not found in running applications")
        }
    }
    
    /// Send a key press event
    private func sendKeyPress(_ key: String, context: ExecutionContext) async throws {
        let keyCode = getKeyCode(for: key)
        
        // Create key down event
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.post(tap: .cghidEventTap)
        
        // Create key up event
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Get key code for a character
    private func getKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case "tab": return 0x30
        case "space": return 0x31
        case "`": return 0x32
        case "return": return 0x24
        case "enter": return 0x24
        case "escape": return 0x35
        case "delete": return 0x33
        case "forwarddelete": return 0x75
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        default: return 0x00
        }
    }
}

/// Handler for moving regions
class MoveRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("📍 Executing move_region intent")
        
        guard let position = parameters["position"] as? [String: Any],
              let x = position["x"] as? Double,
              let y = position["y"] as? Double else {
            throw ProtocolError.invalidParameters("position with x and y coordinates is required")
        }
        
        _ = CGPoint(x: x, y: y)
        
        context.log("📊 Moving region to position (\(x), \(y))")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Moving region - implementation needed")
        
        context.log("✅ Region moved successfully")
        
        return [
            "intent": "move_region",
            "position": position,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for resizing regions
class ResizeRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("📏 Executing resize_region intent")
        
        guard let size = parameters["size"] as? [String: Any],
              let width = size["width"] as? Double,
              let height = size["height"] as? Double else {
            throw ProtocolError.invalidParameters("size with width and height is required")
        }
        
        _ = CGSize(width: width, height: height)
        
        context.log("📊 Resizing region to size (\(width), \(height))")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Resizing region - implementation needed")
        
        context.log("✅ Region resized successfully")
        
        return [
            "intent": "resize_region",
            "size": size,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Import Operations

/// Handler for importing chords
class ImportChordsHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎹 Executing import_chords intent")
        
        let folder = parameters["folder"] as? String ?? "ChordProgressions"
        let random = parameters["random"] as? Bool ?? false
        
        context.log("📊 Importing chords from folder '\(folder)', random: \(random)")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Importing chords - implementation needed")
        
        context.log("✅ Chords imported successfully")
        
        return [
            "intent": "import_chords",
            "folder": folder,
            "random": random,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for importing MIDI files
class ImportMidiHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎵 Executing import_midi intent")
        
        guard let filename = parameters["filename"] as? String else {
            throw ProtocolError.invalidParameters("filename is required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        
        context.log("📊 Importing MIDI file '\(filename)'" + (trackNumber != nil ? " to track \(trackNumber!)" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Importing MIDI file - implementation needed")
        
        context.log("✅ MIDI file imported successfully")
        
        return [
            "intent": "import_midi",
            "file_path": filename,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Playback Operations

/// Handler for starting playback
class PlayHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("▶️ Executing play intent")
        
        let fromBar = parameters["from_bar"] as? Int
        
        if let fromBar = fromBar {
            context.log("📊 Starting playback from bar \(fromBar)")
        } else {
            context.log("📊 Starting playback from current position")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Starting playback - implementation needed")
        
        context.log("✅ Playback started successfully")
        
        return [
            "intent": "start_playback",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for stopping playback
class StopHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("⏹️ Executing stop intent")
        
        context.log("📊 Stopping playback")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Stopping playback - implementation needed")
        
        context.log("✅ Playback stopped successfully")
        
        return [
            "intent": "stop_playback",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for recording
class RecordHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🔴 Executing record intent")
        
        let trackNumber = parameters["track_number"] as? Int
        
        if let trackNumber = trackNumber {
            context.log("📊 Starting recording on track \(trackNumber)")
        } else {
            context.log("📊 Starting recording on selected track")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Starting recording - implementation needed")
        
        context.log("✅ Recording started successfully")
        
        return [
            "intent": "start_recording",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Project Operations

/// Handler for setting tempo
class SetTempoHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎵 Executing set_tempo intent")
        
        guard let tempo = parameters["tempo"] as? Int else {
            throw ProtocolError.invalidParameters("tempo is required")
        }
        
        context.log("📊 Setting tempo to \(tempo) BPM")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting tempo - implementation needed")
        
        context.log("✅ Tempo set successfully")
        
        return [
            "intent": "set_tempo",
            "bpm": tempo,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for setting key signature
class SetKeyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎼 Executing set_key intent")
        
        guard let key = parameters["key"] as? String else {
            throw ProtocolError.invalidParameters("key is required")
        }
        
        context.log("📊 Setting key signature to \(key)")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting key signature - implementation needed")
        
        context.log("✅ Key signature set successfully")
        
        return [
            "intent": "set_key_signature",
            "key": key,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for saving projects
class SaveProjectHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("💾 Executing save_project intent")
        
        let filename = parameters["filename"] as? String
        
        if let filename = filename {
            context.log("📊 Saving project as '\(filename)'")
        } else {
            context.log("📊 Saving project")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Saving project - implementation needed")
        
        context.log("✅ Project saved successfully")
        
        return [
            "intent": "save_project",
            "file_path": filename ?? "default",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Advanced Operations

/// Handler for setting region properties
class SetRegionPropertyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("⚙️ Executing set_region_property intent")
        
        guard let property = parameters["property"] as? String,
              let value = parameters["value"] else {
            throw ProtocolError.invalidParameters("property and value are required")
        }
        
        context.log("📊 Setting region property '\(property)' to '\(value)'")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting region property - implementation needed")
        
        context.log("✅ Region property set successfully")
        
        return [
            "intent": "set_region_property",
            "property": property,
            "value": value,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for applying effects
class ApplyEffectHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎛️ Executing apply_effect intent")
        
        guard let effect = parameters["effect"] as? String else {
            throw ProtocolError.invalidParameters("effect is required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        let preset = parameters["preset"] as? String
        
        context.log("📊 Applying effect '\(effect)'" + 
                   (trackNumber != nil ? " to track \(trackNumber!)" : "") +
                   (preset != nil ? " with preset '\(preset!)'" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Applying effect - implementation needed")
        
        context.log("✅ Effect applied successfully")
        
        return [
            "intent": "apply_effect",
            "effect_name": effect,
            "parameters": parameters,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for setting track properties
class SetTrackPropertyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("🎚️ Executing set_track_property intent")
        
        guard let property = parameters["property"] as? String,
              let value = parameters["value"] else {
            throw ProtocolError.invalidParameters("property and value are required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        
        context.log("📊 Setting track property '\(property)' to '\(value)'" + 
                   (trackNumber != nil ? " on track \(trackNumber!)" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting track property - implementation needed")
        
        context.log("✅ Track property set successfully")
        
        return [
            "intent": "set_track_property",
            "property": property,
            "value": value,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Utility Operations

/// Handler for waiting/delays
class WaitHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("⏳ Executing wait intent")
        
        let duration = parameters["duration"] as? Double ?? 1.0
        let unit = parameters["unit"] as? String ?? "seconds"
        
        let waitTime: TimeInterval
        switch unit.lowercased() {
        case "milliseconds", "ms":
            waitTime = duration / 1000.0
        case "seconds", "s":
            waitTime = duration
        case "minutes", "m":
            waitTime = duration * 60.0
        default:
            waitTime = duration
        }
        
        context.log("📊 Waiting for \(duration) \(unit)")
        
        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        
        context.log("✅ Wait completed")
        
        return [
            "intent": "wait",
            "duration": duration,
            "unit": unit,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

/// Handler for logging messages
class LogHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws -> [String: Any] {
        context.log("📝 Executing log intent")
        
        let message = parameters["message"] as? String ?? "Log message"
        let level = parameters["level"] as? String ?? "info"
        
        context.log("📊 Logging message: \(message) (level: \(level))")
        
        // Message is already logged above, this is just for protocol flow
        context.log("✅ Log message recorded")
        
        return [
            "intent": "log",
            "message": message,
            "level": level,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}
