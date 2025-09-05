import Cocoa
import ApplicationServices

/// Logic Pro Project Explorer - For traversing and operating Logic Pro projects
/// Based on macOS Accessibility API implementation
class LogicProjectExplorer: ObservableObject {
    @Published var isConnected = false
    @Published var currentStatus = "Not connected"
    @Published var tracks: [LogicTrack] = []
    @Published var regions: [LogicRegion] = []
    
    // Callback functions
    var logCallback: ((String) -> Void)?
    
    init() {
        setupLogicApp()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        print(message)
        logCallback?(message)
    }
    
    // MARK: - Initialization
    
    private func setupLogicApp() {
        if LogicUtil.isLogicProRunning() {
            isConnected = true
            currentStatus = "Connected to Logic Pro"
            log("Logic Pro is running")
        } else {
            isConnected = false
            currentStatus = "Logic Pro not running"
            log("Logic Pro not found in running applications")
        }
    }
    
    // MARK: - Project Exploration Core Functions
    
    /// Explore entire Logic Pro project
    func exploreProject() async throws {
        guard LogicUtil.isLogicProRunning() else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Exploring project..."
            tracks.removeAll()
            regions.removeAll()
        }
        
        log("Starting Logic Pro project exploration...")
        
        // 1. Get main window
        let mainWindow = try await LogicUtil.getLogicMainWindow(logCallback: log)
        log("1. Found main window")

        // find element of "Tracks contents"
        let tracksContents = try await LogicUtil.findTracksContentsElement(in: mainWindow, maxDepth: 10, logCallback: log)
        log("2. Found tracks contents: \(tracksContents)")
        
        // Print tracks contents element info and its children
        try await AccessibilityUtil.printElementRoleInfo(tracksContents, elementName: "Tracks Contents", logCallback: log)

        // find element of "Tracks header"
        let tracksHeader = try await LogicUtil.findTracksHeaderElement(in: mainWindow, maxDepth: 10, logCallback: log)
        log("3. Found tracks header: \(tracksHeader)")
        
        // Print tracks header element info and its children
        try await AccessibilityUtil.printElementRoleInfo(tracksHeader, elementName: "Tracks Header", logCallback: log)
        
        // Get track header elements (each represents a track's header)
        let trackHeaderElements = try await LogicUtil.getTrackElements(from: tracksHeader, logCallback: log)
        log("4. Found \(trackHeaderElements.count) track header elements")
        
        // Print each track header element and its children attributes
        for (index, headerElement) in trackHeaderElements.enumerated() {
            log("=== Track Header Element \(index) ===")
            try await AccessibilityUtil.printElementRoleInfo(headerElement, elementName: "Track Header \(index)", logCallback: log)
            try await AccessibilityUtil.printElementAttributes(headerElement, prefix: "  ", logCallback: log)
            
            // Print children attributes
            var children: CFTypeRef?
            let childrenResult = AXUIElementCopyAttributeValue(headerElement, kAXChildrenAttribute as CFString, &children)
            if childrenResult == .success, let children = children {
                let childrenArray = children as! [AXUIElement]
                log("  Track Header \(index) has \(childrenArray.count) children:")
                
                for (childIndex, child) in childrenArray.enumerated() {
                    log("    --- Child \(childIndex) of Track Header \(index) ---")
                    try await AccessibilityUtil.printElementRoleInfo(child, elementName: "Track Header \(index) Child \(childIndex)", logCallback: log)
                    try await AccessibilityUtil.printElementAttributes(child, prefix: "      ", logCallback: log)
                    
                    // Check if this child is a text field and try to modify it
                    if let role = try await AccessibilityUtil.getElementRole(child), role == "AXTextField" {
                        log("    4...")
                        try await LogicUtil.modifyTextFieldValue(child, logCallback: log)
                    }
                }
            }
            log("=== End Track Header Element \(index) ===")
        }
        
        // Get track content elements (each represents a track's content area)
        let trackContentElements = try await LogicUtil.getTrackElements(from: tracksContents, logCallback: log)
        log("5. Found \(trackContentElements.count) track content elements")
        
        // Print each track content element and its children attributes
        for (index, contentElement) in trackContentElements.enumerated() {
            log("=== Track Content Element \(index) ===")
            try await AccessibilityUtil.printElementRoleInfo(contentElement, elementName: "Track Content \(index)", logCallback: log)
            try await AccessibilityUtil.printElementAttributes(contentElement, prefix: "  ", logCallback: log)
            
            // Print children attributes
            var children: CFTypeRef?
            let childrenResult = AXUIElementCopyAttributeValue(contentElement, kAXChildrenAttribute as CFString, &children)
            if childrenResult == .success, let children = children {
                let childrenArray = children as! [AXUIElement]
                log("  Track Content \(index) has \(childrenArray.count) children:")
                
                for (childIndex, child) in childrenArray.enumerated() {
                    log("    --- Child \(childIndex) of Track Content \(index) ---")
                    try await AccessibilityUtil.printElementRoleInfo(child, elementName: "Track Content \(index) Child \(childIndex)", logCallback: log)
                    try await AccessibilityUtil.printElementAttributes(child, prefix: "      ", logCallback: log)
                }
            }
            log("=== End Track Content Element \(index) ===")
        }
        
        // Test all actions on tracks header children
        // try await LogicUtil.testAllActionsOnTracksHeader(tracksHeader, logCallback: log)
        
        log("Project exploration complete")
    }
}

// MARK: - Data Models

/// Logic Pro Track
struct LogicTrack {
    let index: Int
    let name: String
    let type: LogicTrackType
    let properties: [String: Any]
    let position: CGPoint
    let size: CGSize
    let element: AXUIElement
}

/// Logic Pro Track Type
enum LogicTrackType: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case softwareInstrument = "Software Instrument"
    case unknown = "Unknown"
}

/// Logic Pro Region
struct LogicRegion {
    let trackIndex: Int
    let regionIndex: Int
    let name: String
    let type: LogicRegionType
    let properties: [String: Any]
    let position: CGPoint
    let size: CGSize
    let element: AXUIElement
}

/// Logic Pro Region Type
enum LogicRegionType: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case unknown = "Unknown"
}
