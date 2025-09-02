import Cocoa
import ApplicationServices

/// Logic Pro Project Explorer - For traversing and operating Logic Pro projects
/// Based on macOS Accessibility API implementation
class LogicProjectExplorer: ObservableObject {
    private var logicApp: AXUIElement?
    private let logicBundleID = "com.apple.logic10"
    
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
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            self.logicApp = AXUIElementCreateApplication(logicApp.processIdentifier)
            isConnected = true
            currentStatus = "Connected to Logic Pro"
            log("Logic Pro connected with PID: \(logicApp.processIdentifier)")
        } else {
            self.logicApp = nil
            isConnected = false
            currentStatus = "Logic Pro not running"
            log("Logic Pro not found in running applications")
        }
    }
    
    // MARK: - Project Exploration Core Functions
    
    /// Explore entire Logic Pro project
    func exploreProject() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Exploring project..."
            tracks.removeAll()
            regions.removeAll()
        }
        
        log("Starting Logic Pro project exploration...")
        
        // 1. Get main window
        let mainWindow = try await getMainWindow()
        log("Found main window")
        
        // 2. Explore track list
        let trackList = try await findTrackList(in: mainWindow)
        log("Found track list")
        
        // 3. Traverse all tracks
        let discoveredTracks = try await exploreTracks(in: trackList)
        await MainActor.run {
            self.tracks = discoveredTracks
        }
        log("Discovered \(discoveredTracks.count) tracks")
        
        // 4. Explore regions in each track
        var allRegions: [LogicRegion] = []
        for track in discoveredTracks {
            let trackRegions = try await exploreRegions(in: track)
            allRegions.append(contentsOf: trackRegions)
        }
        
        let finalRegions = allRegions
        await MainActor.run {
            self.regions = finalRegions
            self.currentStatus = "Project exploration complete - \(discoveredTracks.count) tracks, \(finalRegions.count) regions"
        }
        
        log("Project exploration complete")
    }
    
    /// Get Logic Pro main window
    private func getMainWindow() async throws -> AXUIElement {
        guard let logicApp = logicApp else {
            throw LogicError.appNotRunning
        }
        
        // Get all windows
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(logicApp, kAXWindowsAttribute as CFString, &windows)
        
        guard result == .success, let windows = windows else {
            throw LogicError.failedToGetWindows
        }
        
        let windowsArray = windows as! [AXUIElement]
        log("Found \(windowsArray.count) windows")
        
        // Find main project window (usually title contains project name)
        for window in windowsArray {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let title = title as? String {
                log("Window title: \(title)")
                // Main project window usually doesn't contain "Untitled" or "Logic Pro"
                if !title.contains("Untitled") && !title.contains("Logic Pro") && title.contains(".logicx") {
                    log("Found main project window: \(title)")
                    return window
                }
            }
        }
        
        // If no specific window found, return first window
        if let firstWindow = windowsArray.first {
            log("Using first window as main window")
            return firstWindow
        }
        
        throw LogicError.failedToGetWindows
    }
    
    /// Find track list in window
    private func findTrackList(in window: AXUIElement) async throws -> AXUIElement {
        log("Finding track list in window...")
        
        // Recursively search for track list
        return try await findElementWithRole(in: window, role: "AXList", maxDepth: 10)
    }
    
    /// Explore all tracks in track list
    private func exploreTracks(in trackList: AXUIElement) async throws -> [LogicTrack] {
        log("Exploring track list...")
        
        var tracks: [LogicTrack] = []
        
        // Get child elements of track list
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(trackList, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            log("Unable to get child elements of track list")
            return tracks
        }
        
        let childrenArray = children as! [AXUIElement]
        log("Track list contains \(childrenArray.count) child elements")
        
        // Traverse each child element, look for tracks
        for (index, child) in childrenArray.enumerated() {
            if let track = try await analyzeTrackElement(child, index: index) {
                tracks.append(track)
                log("Discovered track \(index): \(track.name)")
            }
        }
        
        return tracks
    }
    
    /// Analyze track element
    private func analyzeTrackElement(_ element: AXUIElement, index: Int) async throws -> LogicTrack? {
        // Get track role
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard roleResult == .success, let role = role as? String else {
            return nil
        }
        
        // Check if it's a track-related element
        if !isTrackRelatedRole(role) {
            return nil
        }
        
        // Get track name
        let name = try await getTrackName(from: element)
        
        // Get track type
        let trackType = try await getTrackType(from: element)
        
        // Get track properties
        let properties = try await getTrackProperties(from: element)
        
        // Get track position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        return LogicTrack(
            index: index,
            name: name,
            type: trackType,
            properties: properties,
            position: position,
            size: size,
            element: element
        )
    }
    
    /// Check if role is track-related
    private func isTrackRelatedRole(_ role: String) -> Bool {
        // More precise track identification
        let trackRoles = [
            "AXRow",           // Track row
            "AXGroup"          // Track group
        ]
        return trackRoles.contains(role)
    }
    
    /// Get track name
    private func getTrackName(from element: AXUIElement) async throws -> String {
        // Try multiple methods to get track name
        
        // Method 1: Get title directly
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        if titleResult == .success, let title = title as? String, !title.isEmpty {
            return title
        }
        
        // Method 2: Get description
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        if descResult == .success, let description = description as? String, !description.isEmpty {
            return description
        }
        
        // Method 3: Find text in child elements (more precise search)
        if let childName = try await findTrackNameInChildren(element) {
            return childName
        }
        
        // Method 4: Try to get track index
        let index = try await getElementIndex(element)
        return "Track \(index)"
    }
    
    /// Get track type
    private func getTrackType(from element: AXUIElement) async throws -> LogicTrackType {
        // Determine track type by analyzing child elements and properties
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            // Find specific child elements to determine track type
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    switch role {
                    case "AXButton" where try await hasAudioIcon(child):
                        return .audio
                    case "AXButton" where try await hasMIDIIcon(child):
                        return .midi
                    case "AXButton" where try await hasSoftwareInstrumentIcon(child):
                        return .softwareInstrument
                    default:
                        continue
                    }
                }
            }
        }
        
        return .unknown
    }
    
    /// Get track properties
    private func getTrackProperties(from element: AXUIElement) async throws -> [String: Any] {
        var properties: [String: Any] = [:]
        
        // Get all supported properties
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let attributeNames = attributeNames {
            let namesArray = attributeNames as! [String]
            
            for attributeName in namesArray {
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, attributeName as CFString, &value)
                
                if valueResult == .success, let value = value {
                    properties[attributeName] = value
                }
            }
        }
        
        return properties
    }
    
    /// Explore regions in track
    private func exploreRegions(in track: LogicTrack) async throws -> [LogicRegion] {
        log("Exploring regions in track '\(track.name)'...")
        
        var regions: [LogicRegion] = []
        
        // Find regions in track element
        let trackRegions = try await findRegionsInElement(track.element)
        
        for (index, regionElement) in trackRegions.enumerated() {
            if let region = try await analyzeRegionElement(regionElement, trackIndex: track.index, regionIndex: index) {
                regions.append(region)
                log("Discovered region \(index): \(region.name)")
            }
        }
        
        return regions
    }
    
    /// Find regions in element
    private func findRegionsInElement(_ element: AXUIElement) async throws -> [AXUIElement] {
        var regions: [AXUIElement] = []
        
        // Recursively search for region elements
        try await searchForRegions(in: element, foundRegions: &regions, maxDepth: 5)
        
        return regions
    }
    
    /// Recursively search for regions
    private func searchForRegions(in element: AXUIElement, foundRegions: inout [AXUIElement], maxDepth: Int) async throws {
        guard maxDepth > 0 else { return }
        
        // Check if current element is a region
        if try await isRegionElement(element) {
            foundRegions.append(element)
            return
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                try await searchForRegions(in: child, foundRegions: &foundRegions, maxDepth: maxDepth - 1)
            }
        }
    }
    
    /// Check if element is a region
    private func isRegionElement(_ element: AXUIElement) async throws -> Bool {
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if roleResult == .success, let role = role as? String {
            // More precise region identification
            let regionRoles = ["AXGroup", "AXButton"]
            
            // Check if it contains region-related properties
            if regionRoles.contains(role) {
                // Further validation: check if it has region name or description
                var title: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
                
                if titleResult == .success, let title = title as? String, !title.isEmpty {
                    // Filter out some non-region elements
                    if !title.contains("M") && !title.contains("S") && !title.contains("R") && 
                       !title.contains("I") && !title.contains("dB") && !title.contains("%") &&
                       !title.contains("Track") {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Analyze region element
    private func analyzeRegionElement(_ element: AXUIElement, trackIndex: Int, regionIndex: Int) async throws -> LogicRegion? {
        // Get region name
        let name = try await getRegionName(from: element)
        
        // Get region type
        let regionType = try await getRegionType(from: element)
        
        // Get region properties
        let properties = try await getRegionProperties(from: element)
        
        // Get region position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        return LogicRegion(
            trackIndex: trackIndex,
            regionIndex: regionIndex,
            name: name,
            type: regionType,
            properties: properties,
            position: position,
            size: size,
            element: element
        )
    }
    
    /// Get region name
    private func getRegionName(from element: AXUIElement) async throws -> String {
        // Try multiple methods to get region name
        
        // Method 1: Get title directly
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        if titleResult == .success, let title = title as? String, !title.isEmpty {
            return title
        }
        
        // Method 2: Get description
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        if descResult == .success, let description = description as? String, !description.isEmpty {
            return description
        }
        
        // Method 3: Find region name in child elements
        if let childName = try await findRegionNameInChildren(element) {
            return childName
        }
        
        // Method 4: Try to get region index
        let index = try await getElementIndex(element)
        return "Region \(index)"
    }
    
    /// Get region type
    private func getRegionType(from element: AXUIElement) async throws -> LogicRegionType {
        // Determine region type by analyzing properties
        var properties: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &properties)
        
        if result == .success, let properties = properties as? String {
            if properties.contains("MIDI") {
                return .midi
            } else if properties.contains("Audio") {
                return .audio
            }
        }
        
        return .unknown
    }
    
    /// Get region properties
    private func getRegionProperties(from element: AXUIElement) async throws -> [String: Any] {
        var properties: [String: Any] = [:]
        
        // Get all supported properties
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let attributeNames = attributeNames {
            let namesArray = attributeNames as! [String]
            
            for attributeName in namesArray {
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, attributeName as CFString, &value)
                
                if valueResult == .success, let value = value {
                    properties[attributeName] = value
                }
            }
        }
        
        return properties
    }
    
    // MARK: - Helper Methods
    
    /// Recursively find element with specific role
    private func findElementWithRole(in element: AXUIElement, role: String, maxDepth: Int) async throws -> AXUIElement {
        guard maxDepth > 0 else {
            throw LogicError.elementNotFound("Element with role \(role) not found")
        }
        
        // Check current element
        var currentRole: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &currentRole)
        
        if roleResult == .success, let currentRole = currentRole as? String, currentRole == role {
            return element
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                do {
                    return try await findElementWithRole(in: child, role: role, maxDepth: maxDepth - 1)
                } catch {
                    continue
                }
            }
        }
        
        throw LogicError.elementNotFound("Element with role \(role) not found")
    }
    
    /// Find track name in child elements (more precise search)
    private func findTrackNameInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            // First look for track name labels
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    // Find track name text elements
                    if role == "AXStaticText" || role == "AXTextField" {
                        var title: CFTypeRef?
                        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                        
                        if titleResult == .success, let title = title as? String, !title.isEmpty {
                            // Filter out some common non-name text
                            if !title.contains("M") && !title.contains("S") && !title.contains("R") && 
                               !title.contains("I") && !title.contains("dB") && !title.contains("%") {
                                return title
                            }
                        }
                    }
                    
                    // Recursively search child elements
                    if let childName = try await findTrackNameInChildren(child) {
                        return childName
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find region name in child elements
    private func findRegionNameInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    // Find region name text elements
                    if role == "AXStaticText" || role == "AXTextField" {
                        var title: CFTypeRef?
                        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                        
                        if titleResult == .success, let title = title as? String, !title.isEmpty {
                            // Filter out some common non-name text
                            if !title.contains("M") && !title.contains("S") && !title.contains("R") && 
                               !title.contains("I") && !title.contains("dB") && !title.contains("%") &&
                               !title.contains("Track") {
                                return title
                            }
                        }
                    }
                    
                    // Recursively search child elements
                    if let childName = try await findRegionNameInChildren(child) {
                        return childName
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find text in child elements
    private func findTextInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String, role == "AXStaticText" {
                    var title: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                    if titleResult == .success, let title = title as? String, !title.isEmpty {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Get element position
    private func getElementPosition(_ element: AXUIElement) async throws -> CGPoint {
        var position: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        
        if result == .success, let position = position {
            // Position is usually an AXValue
            if let point = try await extractPointFromAXValue(position) {
                return point
            }
        }
        
        return CGPoint.zero
    }
    
    /// Get element size
    private func getElementSize(_ element: AXUIElement) async throws -> CGSize {
        var size: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        if result == .success, let size = size {
            // Size is usually an AXValue
            if let sizeValue = try await extractSizeFromAXValue(size) {
                return sizeValue
            }
        }
        
        return CGSize.zero
    }
    
    /// Extract point from AXValue
    private func extractPointFromAXValue(_ value: CFTypeRef) async throws -> CGPoint? {
        // Need to parse according to actual AXValue structure
        // Simplified implementation
        return nil
    }
    
    /// Extract size from AXValue
    private func extractSizeFromAXValue(_ value: CFTypeRef) async throws -> CGSize? {
        // Need to parse according to actual AXValue structure
        // Simplified implementation
        return nil
    }
    
    /// Get element index
    private func getElementIndex(_ element: AXUIElement) async throws -> Int {
        var index: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXIndexAttribute as CFString, &index)
        
        if result == .success, let index = index as? Int {
            return index
        }
        
        return 0
    }
    
    /// Check if has audio icon
    private func hasAudioIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
    }
    
    /// Check if has MIDI icon
    private func hasMIDIIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
    }
    
    /// Check if has software instrument icon
    private func hasSoftwareInstrumentIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
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

