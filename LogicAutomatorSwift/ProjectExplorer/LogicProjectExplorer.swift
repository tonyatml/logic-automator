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
        
        let mainWindow = try await LogicUtil.getLogicMainWindow()
        
        // 1. Get track header elements (each represents a track's header)
        let trackHeaderElements = try await LogicUtil.getHeaderElements(mainWindow, logCallback: log)
        log("1. Found \(trackHeaderElements.count) track header elements")
        
        // Print each track header element and its children attributes
        for (index, headerElement) in trackHeaderElements.enumerated() {
            try await AccessibilityUtil.testAllActionsOnElement(headerElement, elementName: "content \(index+1)", logCallback: log)
        }
        
        // 2. Get track content elements (each represents a track's content area)
        let trackContentElements = try await LogicUtil.getTrackElements(mainWindow, logCallback: log)
        log("2. Found \(trackContentElements.count) track content elements")
        
        // Print each track content element and its children attributes
        for (index, contentElement) in trackContentElements.enumerated() {
            try await AccessibilityUtil.testAllActionsOnElement(contentElement, elementName: "content \(index+1)", logCallback: log)
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
