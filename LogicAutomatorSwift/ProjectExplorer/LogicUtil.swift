import Cocoa
import ApplicationServices

/// Utility class for Logic Pro specific operations
class LogicUtil {
    
    static let logicBundleID = "com.apple.logic10"
    
    // MARK: - Logic Pro Application Management
    
    /// Get Logic Pro application instance
    static func getLogicApp() -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            return AXUIElementCreateApplication(logicApp.processIdentifier)
        }
        return nil
    }
    
    /// Check if Logic Pro is running
    static func isLogicProRunning() -> Bool {
        return getLogicApp() != nil
    }
    
    /// Get Logic Pro main window
    static func getLogicMainWindow(logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        guard let logicApp = getLogicApp() else {
            throw LogicError.appNotRunning
        }
        
        return try await AccessibilityUtil.getMainWindow(of: logicApp, logCallback: logCallback)
    }
    
    // MARK: - Logic Pro Element Finding
    
    /// Find the "Tracks contents" element that contains the actual tracks
    static func findTracksContentsElement(in element: AXUIElement, maxDepth: Int, logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        return try await AccessibilityUtil.findElementByDescriptionOrSubrole(
            in: element,
            descriptionKeywords: ["Tracks contents"],
            subroleKeywords: ["ArrangeContentsSectionView"],
            elementName: "Tracks contents",
            maxDepth: maxDepth,
            logCallback: logCallback
        )
    }
    
    /// Find the "Tracks header" element
    static func findTracksHeaderElement(in element: AXUIElement, maxDepth: Int, logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        return try await AccessibilityUtil.findElementByDescriptionOrSubrole(
            in: element,
            descriptionKeywords: ["Tracks header", "Track header"],
            subroleKeywords: [],
            elementName: "Tracks header",
            maxDepth: maxDepth,
            logCallback: logCallback
        )
    }
    
    /// Get all track elements from Tracks contents
    static func getTrackElements(_ mainWindow: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws -> [AXUIElement] {
        let tracksContents = try await findTracksContentsElement(in: mainWindow, maxDepth: 10)
        return try await getChildrenElements(from: tracksContents, elementType: "track", logCallback: logCallback)
    }

    /// Get all header elements from Tracks header
    static func getHeaderElements(_ mainWindow: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws -> [AXUIElement] {
        let tracksHeader = try await findTracksHeaderElement(in: mainWindow, maxDepth: 10)
        return try await getChildrenElements(from: tracksHeader, elementType: "header", logCallback: logCallback)
    }
    
    /// Generic function to get children elements from a parent element
    static func getChildrenElements(from parentElement: AXUIElement, elementType: String, logCallback: ((String) -> Void)? = nil) async throws -> [AXUIElement] {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parentElement, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("Found \(childrenArray.count) \(elementType) elements")
            return childrenArray
        } else {
            logCallback?("Failed to get children from \(elementType) parent element")
            return []
        }
    }
    
    /// Try to modify a text field value by appending "1"
    static func modifyTextFieldValue(_ textField: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws {
        // Try multiple methods to get the current value
        var currentValue: String? = nil
        
        // Method 1: Try kAXValueAttribute
        var value: CFTypeRef?
        let getValueResult = AXUIElementCopyAttributeValue(textField, kAXValueAttribute as CFString, &value)
        if getValueResult == .success, let value = value as? String {
            currentValue = value
            logCallback?("Got current value via kAXValueAttribute: '\(value)'")
        }
        
        // Method 2: Try kAXTitleAttribute
        if currentValue == nil {
            var title: CFTypeRef?
            let getTitleResult = AXUIElementCopyAttributeValue(textField, kAXTitleAttribute as CFString, &title)
            if getTitleResult == .success, let title = title as? String {
                currentValue = title
                logCallback?("Got current value via kAXTitleAttribute: '\(title)'")
            }
        }
        
        // Method 3: Try kAXDescriptionAttribute
        if currentValue == nil {
            var description: CFTypeRef?
            let getDescResult = AXUIElementCopyAttributeValue(textField, kAXDescriptionAttribute as CFString, &description)
            if getDescResult == .success, let description = description as? String {
                currentValue = description
                logCallback?("Got current value via kAXDescriptionAttribute: '\(description)'")
            }
        }
        
        if let currentValue = currentValue {
            logCallback?("Current text field value: '\(currentValue)'")
            
            // Create new value by appending "1"
            let newValue = currentValue + "1"
            logCallback?("Attempting to set new value: '\(newValue)'")
            
            // Try multiple methods to set the value
            // Method 1: Try kAXValueAttribute
            //let setValueResult = AXUIElementSetAttributeValue(textField, kAXValueAttribute as CFString, newValue as CFString)
            //logCallback?("Set value via kAXValueAttribute result: \(setValueResult)")
            
            // Method 2: Try kAXTitleAttribute
            //let setTitleResult = AXUIElementSetAttributeValue(textField, kAXTitleAttribute as CFString, newValue as CFString)
            //logCallback?("Set value via kAXTitleAttribute result: \(setTitleResult)")
            
            // Method 3: Try kAXDescriptionAttribute (since we can read from it)
            //let setDescResult = AXUIElementSetAttributeValue(textField, kAXDescriptionAttribute as CFString, newValue as CFString)
            //logCallback?("Set value via kAXDescriptionAttribute result: \(setDescResult)")
            
            // Verify if description was changed
            //if setDescResult == .success {
            //    var verifyDesc: CFTypeRef?
            //    let verifyDescResult = AXUIElementCopyAttributeValue(textField, kAXDescriptionAttribute as CFString, &verifyDesc)
            //    if verifyDescResult == .success, let verifyDesc = verifyDesc as? String {
            //        logCallback?("Verified description after change: '\(verifyDesc)'")
            //    }
            //}
            
            // Method 3: Try focusing first, then setting
            //logCallback?("Attempting to focus the text field...")
            //let focusResult = AXUIElementSetAttributeValue(textField, kAXFocusedAttribute as CFString, true as CFBoolean)
            //logCallback?("Focus result: \(focusResult)")
            
            // Wait a moment for focus to take effect
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Try setting value again after focusing
            //let setValueAfterFocusResult = AXUIElementSetAttributeValue(textField, kAXValueAttribute as CFString, newValue as CFString)
            //logCallback?("Set value after focus result: \(setValueAfterFocusResult)")
            
            // Method 4: Try using actions
            logCallback?("Trying to use actions to modify text field...")
            let actions = try await AccessibilityUtil.getAvailableActions(textField)
            logCallback?("Available actions: \(actions)")
            
            // Try AXSetValue action if available
            if actions.contains("AXSetValue") {
                let setValueActionResult = AXUIElementPerformAction(textField, "AXSetValue" as CFString)
                logCallback?("AXSetValue action result: \(setValueActionResult)")
            }
            
            // Try AXPress action (the only available action)
            if actions.contains("AXPress") {
                logCallback?("Trying AXPress action to enter edit mode...")
                let pressActionResult = AXUIElementPerformAction(textField, "AXPress" as CFString)
                logCallback?("AXPress action result: \(pressActionResult)")
                
                // Wait a moment for edit mode to activate
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Now try to send the new text
                logCallback?("Sending new text: '\(newValue)'")
                try await sendTextToElement(textField, text: newValue, logCallback: logCallback)
                
                // Wait a moment for text to be entered
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                // Press Enter to confirm the change
                logCallback?("Pressing Enter to confirm...")
                try await pressEnterKey()
                
                // Wait a moment for the change to take effect
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Check if the change was successful
                var finalDesc: CFTypeRef?
                let finalDescResult = AXUIElementCopyAttributeValue(textField, kAXDescriptionAttribute as CFString, &finalDesc)
                if finalDescResult == .success, let finalDesc = finalDesc as? String {
                    logCallback?("Final description after edit: '\(finalDesc)'")
                    if finalDesc == newValue {
                        logCallback?("✅ Successfully changed text field value!")
                    } else {
                        logCallback?("❌ Text field value was not changed as expected")
                    }
                }
            }
            
        } else {
            logCallback?("Could not get current text field value using any method")
            
            // Try to focus and set a default value anyway
            logCallback?("Attempting to focus the text field...")
            let focusResult = AXUIElementSetAttributeValue(textField, kAXFocusedAttribute as CFString, true as CFBoolean)
            logCallback?("Focus result: \(focusResult)")
            
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Try setting a test value
            let testValue = "TestValue1"
            logCallback?("Attempting to set test value: '\(testValue)'")
            let setTestValueResult = AXUIElementSetAttributeValue(textField, kAXValueAttribute as CFString, testValue as CFString)
            logCallback?("Set test value result: \(setTestValueResult)")
        }
    }
    
    /// Send text to an element using keyboard events
    static func sendTextToElement(_ element: AXUIElement, text: String, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Sending text '\(text)' to element...")
        
        // First, make sure the element is focused
        let focusResult = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFBoolean)
        //u3
        logCallback?("Focus result before sending text: \(focusResult)")
        
        // Wait a moment for focus
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Send each character
        for char in text {
            let charCode = Int(char.unicodeScalars.first?.value ?? 0)
            logCallback?("Sending character: '\(char)' (code: \(charCode))")
            
            // Create key down event
            if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(charCode), keyDown: true) {
                keyDownEvent.post(tap: .cghidEventTap)
            }
            
            // Create key up event
            if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: UInt16(charCode), keyDown: false) {
                keyUpEvent.post(tap: .cghidEventTap)
            }
            
            // Small delay between characters
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        logCallback?("Finished sending text")
    }
    
    /// Press Enter key
    static func pressEnterKey(logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Pressing Enter key...")
        
        // Enter key virtual key code is 36
        if let enterDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true) {
            enterDownEvent.post(tap: .cghidEventTap)
        }
        
        if let enterUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false) {
            enterUpEvent.post(tap: .cghidEventTap)
        }
        
        logCallback?("Enter key pressed")
    }
    
    // MARK: - Logic Pro Operations
    
    /// Activate Logic Pro application
    static func activateLogicPro(logCallback: ((String) -> Void)? = nil) async throws {
        guard let logicApp = getLogicApp() else {
            throw LogicError.appNotRunning
        }
        
        try await AccessibilityUtil.activateApplication(logicApp, bundleID: logicBundleID, logCallback: logCallback)
        
        let mainWindow = try await getLogicMainWindow(logCallback: logCallback)
        try await AccessibilityUtil.focusWindow(mainWindow, logCallback: logCallback)
    }
    
    /// Test all actions on tracks header and its children
    static func testAllActionsOnTracksHeader(_ tracksHeader: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("=== Testing all actions on Tracks Header and its children ===")
        
        try await activateLogicPro(logCallback: logCallback)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        try await AccessibilityUtil.testAllActionsOnElement(tracksHeader, elementName: "Tracks Header", logCallback: logCallback)
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(tracksHeader, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("Tracks Header has \(childrenArray.count) child elements to test")
            
            for (index, child) in childrenArray.enumerated() {
                logCallback?("--- Testing Child \(index) of Tracks Header ---")
                try await AccessibilityUtil.testAllActionsOnElement(child, elementName: "Tracks Header Child \(index)", logCallback: logCallback)
                
                if index < childrenArray.count - 1 {
                    logCallback?("Resting for 1 second before next child...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }
        
        logCallback?("=== Finished testing all actions on Tracks Header ===")
    }
    
    /// Click on a track element
    static func clickTrack(_ track: LogicTrack, element: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Attempting to click track: \(track.name)")
        
        let actions = try await AccessibilityUtil.getAvailableActions(element)
        logCallback?("Available actions for track '\(track.name)': \(actions)")
        
        for action in actions {
            logCallback?("Trying action: \(action)")
            let result = try await AccessibilityUtil.performAction(element, action: action)
            logCallback?("Action '\(action)' result: \(result)")
            
            if action == "AXShowMenu" {
                logCallback?("Action '\(action)' might show menu/popup, attempting to dismiss...")
                try await AccessibilityUtil.dismissMenuOrPopup(logCallback: logCallback)
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        try await findAndClickClickableChild(in: element, trackName: track.name, logCallback: logCallback)
    }
    
    /// Find and click a clickable child element
    static func findAndClickClickableChild(in element: AXUIElement, trackName: String, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Searching for clickable child elements in track: \(trackName)")
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("Track '\(trackName)' has \(childrenArray.count) child elements")
            
            for (index, child) in childrenArray.enumerated() {
                let actions = try await AccessibilityUtil.getAvailableActions(child)
                if !actions.isEmpty {
                    logCallback?("Found child \(index) with actions: \(actions)")
                    
                    for action in actions {
                        logCallback?("Trying child \(index) action: \(action)")
                        let actionResult = try await AccessibilityUtil.performAction(child, action: action)
                        logCallback?("Child \(index) action '\(action)' result: \(actionResult)")
                        
                        if action == "AXShowMenu" {
                            logCallback?("Child \(index) action '\(action)' might show menu/popup, attempting to dismiss...")
                            try await AccessibilityUtil.dismissMenuOrPopup(logCallback: logCallback)
                        }
                        
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    }
                    
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }
    }
    
    
    
}
