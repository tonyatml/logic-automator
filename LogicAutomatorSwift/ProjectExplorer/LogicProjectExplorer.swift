import Cocoa
import ApplicationServices

/// Logic Pro Project Explorer - For traversing and operating Logic Pro projects
/// Based on macOS Accessibility API implementation
class LogicProjectExplorer: ObservableObject {
    @Published var isConnected = false
    @Published var currentStatus = "Not connected"
    @Published var tracks: [LogicTrack] = []
    @Published var regions: [LogicRegion] = []
    @Published var isExploring = false
    @Published var explorationResults = ""
    
    private let regionOperator = LogicRegionOperator()
    
    // Callback functions
    var logCallback: ((String) -> Void)?
    
    init() {
        setupLogicApp()
        setupLogging()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        print(message)
        logCallback?(message)
    }
    
    private func setupLogging() {
        regionOperator.logCallback = { [weak self] message in
            DispatchQueue.main.async {
                self?.explorationResults += "Operator: \(message)\n"
            }
        }
    }
    
    /// Append message to exploration results log
    func appendToLog(_ message: String) {
        DispatchQueue.main.async {
            self.explorationResults += "Monitor: \(message)\n"
        }
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
    
    // MARK: - Main Function Examples
    
    /// Complete project exploration example
    func exploreProjectExample() async {
        await MainActor.run {
            isExploring = true
            explorationResults = "Starting Logic Pro project exploration...\n"
        }
        
        do {
            // 1. Explore project
            try await exploreProject()
            
            // 2. Perform region operations
            await performRegionOperations()
            
            // 3. Analyze project structure
            await analyzeProjectStructure()
            
            // 4. Export project info
            if let jsonInfo = await exportProjectInfoToJSON() {
                explorationResults += "\nExported JSON:\n\(jsonInfo)\n"
            }
            
        } catch {
            explorationResults += "Error during exploration: \(error.localizedDescription)\n"
        }
        
        await MainActor.run {
            isExploring = false
        }
    }
    
    private func performRegionOperations() async {
        explorationResults += "\n=== Region Operations ===\n"
        
        // Get some regions to work with
        let audioRegions = await findRegionsByType(.audio)
        let midiRegions = await findRegionsByType(.midi)
        
        explorationResults += "Found \(audioRegions.count) audio regions and \(midiRegions.count) MIDI regions\n"
        
        // Example: Modify first region if available
        if let firstRegion = audioRegions.first {
            await modifyRegionValues(firstRegion)
        }
    }
    
    private func modifyRegionValues(_ region: LogicRegion) async {
        explorationResults += "Modifying region: \(region.name)\n"
        
        // Example region modifications
        explorationResults += "Region modification example for: \(region.name)\n"
        explorationResults += "Track: \(region.trackIndex), Region: \(region.regionIndex)\n"
        explorationResults += "Type: \(region.type.rawValue)\n"
        explorationResults += "Position: \(region.position), Size: \(region.size)\n"
        explorationResults += "Properties: \(region.properties)\n"
        
        // Note: Actual modification would require the AXUIElement, which is not stored in the Codable version
        explorationResults += "Note: Region modification requires AXUIElement access\n"
    }
    
    // MARK: - Search and Analysis Functions
    
    func findTracksByType(_ type: LogicTrackType) async -> [LogicTrack] {
        explorationResults += "Searching for \(type.rawValue) tracks...\n"
        // Implementation would filter tracks by type
        return tracks.filter { $0.type == type }
    }
    
    func findRegionsByType(_ type: LogicRegionType) async -> [LogicRegion] {
        explorationResults += "Searching for \(type.rawValue) regions...\n"
        // Implementation would filter regions by type
        return regions.filter { $0.type == type }
    }
    
    func batchModifyTrackVolumes(volume: Float) async {
        explorationResults += "Batch modifying track volumes to \(volume)...\n"
        // Implementation would modify all track volumes
        for track in tracks {
            explorationResults += "Modifying track '\(track.name)' volume to \(volume)\n"
        }
    }
    
    func exportProjectInfoToJSON() async -> String? {
        explorationResults += "Exporting project info to JSON...\n"
        
        let projectInfo = ProjectInfo(
            tracks: tracks,
            regions: regions,
            exportDate: Date(),
            version: "1.0"
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projectInfo)
            return String(data: data, encoding: .utf8)
        } catch {
            explorationResults += "Error encoding project info: \(error.localizedDescription)\n"
            return nil
        }
    }
    
    func importProjectInfoFromJSON(_ jsonString: String) async {
        explorationResults += "Importing project info from JSON...\n"
        
        guard let data = jsonString.data(using: .utf8) else {
            explorationResults += "Error: Invalid JSON string\n"
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let projectInfo = try decoder.decode(ProjectInfo.self, from: data)
            
            await MainActor.run {
                self.tracks = projectInfo.tracks
                self.regions = projectInfo.regions
            }
            
            explorationResults += "Successfully imported \(projectInfo.tracks.count) tracks and \(projectInfo.regions.count) regions\n"
            
        } catch {
            explorationResults += "Error decoding project info: \(error.localizedDescription)\n"
        }
    }
    
    func analyzeProjectStructure() async {
        explorationResults += "\n=== Project Structure Analysis ===\n"
        
        let trackTypes = Dictionary(grouping: tracks, by: { $0.type })
        let regionTypes = Dictionary(grouping: regions, by: { $0.type })
        
        explorationResults += "Track Analysis:\n"
        for (type, tracksOfType) in trackTypes {
            explorationResults += "  \(type.rawValue): \(tracksOfType.count) tracks\n"
        }
        
        explorationResults += "Region Analysis:\n"
        for (type, regionsOfType) in regionTypes {
            explorationResults += "  \(type.rawValue): \(regionsOfType.count) regions\n"
        }
        
        // Find duplicate regions
        let duplicates = await findDuplicateRegions()
        if !duplicates.isEmpty {
            explorationResults += "Duplicate Regions Found:\n"
            for (name, duplicateRegions) in duplicates {
                explorationResults += "  '\(name)': \(duplicateRegions.count) instances\n"
            }
        }
    }
    
    func findDuplicateRegions() async -> [String: [LogicRegion]] {
        explorationResults += "Searching for duplicate regions...\n"
        
        let groupedRegions = Dictionary(grouping: regions, by: { $0.name })
        let duplicates = groupedRegions.filter { $0.value.count > 1 }
        
        return duplicates
    }
    
    func optimizeProjectLayout() async {
        explorationResults += "\n=== Project Layout Optimization ===\n"
        
        // Example optimization suggestions
        let duplicateRegions = await findDuplicateRegions()
        if !duplicateRegions.isEmpty {
            explorationResults += "Optimization Suggestion: Remove \(duplicateRegions.count) duplicate region groups\n"
        }
        
        let emptyTracks = tracks.filter { track in
            !regions.contains { $0.trackIndex == track.index }
        }
        
        if !emptyTracks.isEmpty {
            explorationResults += "Optimization Suggestion: Remove \(emptyTracks.count) empty tracks\n"
        }
        
        explorationResults += "Project optimization analysis complete\n"
    }
}

// MARK: - Data Models

/// Logic Pro Track
struct LogicTrack: Codable {
    let index: Int
    let name: String
    let type: LogicTrackType
    let properties: [String: String] // Changed to String for Codable support
    let position: CGPoint
    let size: CGSize
    // Note: AXUIElement cannot be Codable, so it's excluded from export/import
}

/// Logic Pro Track Type
enum LogicTrackType: String, CaseIterable, Codable {
    case audio = "Audio"
    case midi = "MIDI"
    case softwareInstrument = "Software Instrument"
    case unknown = "Unknown"
}

/// Logic Pro Region
struct LogicRegion: Codable {
    let trackIndex: Int
    let regionIndex: Int
    let name: String
    let type: LogicRegionType
    let properties: [String: String] // Changed to String for Codable support
    let position: CGPoint
    let size: CGSize
    // Note: AXUIElement cannot be Codable, so it's excluded from export/import
}

/// Logic Pro Region Type
enum LogicRegionType: String, CaseIterable, Codable {
    case audio = "Audio"
    case midi = "MIDI"
    case unknown = "Unknown"
}

// MARK: - Project Info Model

/// Project information for export/import
struct ProjectInfo: Codable {
    let tracks: [LogicTrack]
    let regions: [LogicRegion]
    let exportDate: Date
    let version: String
}
