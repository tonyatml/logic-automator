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
        
        // Get track elements from Tracks contents
        let trackElements = try await LogicUtil.getTrackElements(from: tracksContents, logCallback: log)
        log("4. Found \(trackElements.count) track elements")
        
        // Get region elements from Tracks header
        let regionElements = try await LogicUtil.getRegionElements(from: tracksHeader, logCallback: log)
        log("5. Found \(regionElements.count) region elements")
        
        // Test all actions on tracks header children
        try await LogicUtil.testAllActionsOnTracksHeader(tracksHeader, logCallback: log)
        
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