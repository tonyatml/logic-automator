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
    static func getTrackElements(from tracksContents: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws -> [AXUIElement] {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(tracksContents, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("Found \(childrenArray.count) track elements in Tracks contents")
            return childrenArray
        } else {
            logCallback?("Failed to get children from Tracks contents")
            return []
        }
    }
    
    /// Get all region elements from Tracks header
    static func getRegionElements(from tracksHeader: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws -> [AXUIElement] {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(tracksHeader, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("Found \(childrenArray.count) region elements in Tracks header")
            return childrenArray
        } else {
            logCallback?("Failed to get children from Tracks header")
            return []
        }
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
    static func clickTrack(_ track: LogicTrack, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Attempting to click track: \(track.name)")
        
        let actions = try await AccessibilityUtil.getAvailableActions(track.element)
        logCallback?("Available actions for track '\(track.name)': \(actions)")
        
        for action in actions {
            logCallback?("Trying action: \(action)")
            let result = try await AccessibilityUtil.performAction(track.element, action: action)
            logCallback?("Action '\(action)' result: \(result)")
            
            if action == "AXShowMenu" {
                logCallback?("Action '\(action)' might show menu/popup, attempting to dismiss...")
                try await AccessibilityUtil.dismissMenuOrPopup(logCallback: logCallback)
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        try await findAndClickClickableChild(in: track.element, trackName: track.name, logCallback: logCallback)
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
