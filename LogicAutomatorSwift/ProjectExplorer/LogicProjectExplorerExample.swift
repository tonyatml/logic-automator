import Cocoa
import ApplicationServices

/// Logic Pro Project Explorer Usage Example
/// Demonstrates how to use LogicProjectExplorer and LogicRegionOperator
class LogicProjectExplorerExample: ObservableObject {
    private let projectExplorer = LogicProjectExplorer()
    private let regionOperator = LogicRegionOperator()
    
    @Published var isExploring = false
    @Published var explorationResults = ""
    
    init() {
        setupLogging()
    }
    
    // MARK: - Setup Logging
    
    private func setupLogging() {
        projectExplorer.logCallback = { [weak self] message in
            DispatchQueue.main.async {
                self?.explorationResults += "Explorer: \(message)\n"
            }
        }
        
        regionOperator.logCallback = { [weak self] message in
            DispatchQueue.main.async {
                self?.explorationResults += "Operator: \(message)\n"
            }
        }
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
            try await projectExplorer.exploreProject()
            
            // 2. Display track information
            // await displayTrackInformation()
            
            // 3. Display region information
            //await displayRegionInformation()
            
            // 4. Perform region operations example
            // await performRegionOperations()
            
        } catch {
            await MainActor.run {
                explorationResults += "Error: \(error.localizedDescription)\n"
            }
        }
        
        await MainActor.run {
            isExploring = false
        }
    }
    
    /// Display track information
    private func displayTrackInformation() async {
        await MainActor.run {
            explorationResults += "\n=== Track Information ===\n"
            
            for track in projectExplorer.tracks {
                explorationResults += "Track \(track.index): \(track.name)\n"
                explorationResults += "  Type: \(track.type.rawValue)\n"
                explorationResults += "  Position: \(track.position)\n"
                explorationResults += "  Size: \(track.size)\n"
                explorationResults += "  Property Count: \(track.properties.count)\n"
                
                // Display some important properties
                for (key, value) in track.properties {
                    if key.contains("Title") || key.contains("Value") || key.contains("Description") {
                        explorationResults += "    \(key): \(value)\n"
                    }
                }
                explorationResults += "\n"
            }
        }
    }
    
    /// Display region information
    private func displayRegionInformation() async {
        await MainActor.run {
            explorationResults += "\n=== Region Information ===\n"
            
            for region in projectExplorer.regions {
                explorationResults += "Region \(region.regionIndex) (Track \(region.trackIndex)): \(region.name)\n"
                explorationResults += "  Type: \(region.type.rawValue)\n"
                explorationResults += "  Position: \(region.position)\n"
                explorationResults += "  Size: \(region.size)\n"
                explorationResults += "  Property Count: \(region.properties.count)\n"
                
                // Display some important properties
                for (key, value) in region.properties {
                    if key.contains("Title") || key.contains("Value") || key.contains("Description") {
                        explorationResults += "    \(key): \(value)\n"
                    }
                }
                explorationResults += "\n"
            }
        }
    }
    
    /// Perform region operations example
    private func performRegionOperations() async {
        await MainActor.run {
            explorationResults += "\n=== Region Operations Example ===\n"
        }
        
        // Select first region for operations
        guard let firstRegion = projectExplorer.regions.first else {
            await MainActor.run {
                explorationResults += "No regions found for operations\n"
            }
            return
        }
        
        do {
            // 1. 获取区域数值
            let regionValues = try await regionOperator.getRegionValues(firstRegion)
            
            await MainActor.run {
                explorationResults += "Region '\(firstRegion.name)' values:\n"
                explorationResults += "  Volume: \(regionValues.volume)\n"
                explorationResults += "  Pan: \(regionValues.pan)\n"
                explorationResults += "  Start Time: \(regionValues.startTime)\n"
                explorationResults += "  End Time: \(regionValues.endTime)\n"
                explorationResults += "  Length: \(regionValues.length)\n"
                explorationResults += "  Velocity: \(regionValues.velocity)\n"
                explorationResults += "  Pitch: \(regionValues.pitch)\n"
            }
            
            // 2. Modify region values
            await modifyRegionValues(firstRegion)
            
        } catch {
            await MainActor.run {
                explorationResults += "Error getting region values: \(error.localizedDescription)\n"
            }
        }
    }
    
    /// Modify region values example
    private func modifyRegionValues(_ region: LogicRegion) async {
        await MainActor.run {
            explorationResults += "\nModifying region values...\n"
        }
        
        do {
            // Modify volume
            try await regionOperator.setRegionVolume(region, volume: 0.8)
            await MainActor.run {
                explorationResults += "Volume set to 0.8\n"
            }
            
            // Modify pan
            try await regionOperator.setRegionPan(region, pan: -0.5)
            await MainActor.run {
                explorationResults += "Pan set to -0.5\n"
            }
            
            // Modify velocity
            try await regionOperator.setRegionVelocity(region, velocity: 80)
            await MainActor.run {
                explorationResults += "Velocity set to 80\n"
            }
            
            // Modify pitch
            try await regionOperator.setRegionPitch(region, pitch: 12)
            await MainActor.run {
                explorationResults += "Pitch set to 12\n"
            }
            
            // Move region
            let newPosition = CGPoint(x: region.position.x + 100, y: region.position.y)
            try await regionOperator.moveRegion(region, to: newPosition)
            await MainActor.run {
                explorationResults += "Region moved to new position\n"
            }
            
            // Resize region
            let newSize = CGSize(width: region.size.width * 1.5, height: region.size.height)
            try await regionOperator.resizeRegion(region, to: newSize)
            await MainActor.run {
                explorationResults += "Region size adjusted to 1.5x\n"
            }
            
        } catch {
            await MainActor.run {
                explorationResults += "Error modifying region values: \(error.localizedDescription)\n"
            }
        }
    }
    
    // MARK: - Specific Function Examples
    
    /// Find tracks of specific type
    func findTracksByType(_ type: LogicTrackType) async -> [LogicTrack] {
        return projectExplorer.tracks.filter { $0.type == type }
    }
    
    /// Find regions of specific type
    func findRegionsByType(_ type: LogicRegionType) async -> [LogicRegion] {
        return projectExplorer.regions.filter { $0.type == type }
    }
    
    /// Batch modify track volumes
    func batchModifyTrackVolumes(volume: Float) async {
        await MainActor.run {
            explorationResults += "\nBatch modifying track volumes...\n"
        }
        
        for track in projectExplorer.tracks {
            // Track volume modification functionality needs to be implemented here
            await MainActor.run {
                explorationResults += "Track '\(track.name)' volume set to \(volume)\n"
            }
        }
    }
    
    /// Export project info to JSON
    func exportProjectInfoToJSON() async -> String? {
        let projectInfo = ProjectInfo(
            tracks: projectExplorer.tracks,
            regions: projectExplorer.regions,
            exportDate: Date()
        )
        
        do {
            let jsonData = try JSONEncoder().encode(projectInfo)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            await MainActor.run {
                explorationResults += "Error exporting JSON: \(error.localizedDescription)\n"
            }
            return nil
        }
    }
    
    /// Import project info from JSON
    func importProjectInfoFromJSON(_ jsonString: String) async {
        guard let jsonData = jsonString.data(using: .utf8) else {
            await MainActor.run {
                explorationResults += "Invalid JSON string\n"
            }
            return
        }
        
        do {
            let projectInfo = try JSONDecoder().decode(ProjectInfo.self, from: jsonData)
            await MainActor.run {
                explorationResults += "Successfully imported project info from JSON\n"
                explorationResults += "Import Date: \(projectInfo.exportDate)\n"
                explorationResults += "Track Count: \(projectInfo.tracks.count)\n"
                explorationResults += "Region Count: \(projectInfo.regions.count)\n"
            }
        } catch {
            await MainActor.run {
                explorationResults += "Error importing JSON: \(error.localizedDescription)\n"
            }
        }
    }
    
    // MARK: - Advanced Function Examples
    
    /// Analyze project structure
    func analyzeProjectStructure() async {
        await MainActor.run {
            explorationResults += "\n=== Project Structure Analysis ===\n"
        }
        
        // Count track types
        let trackTypeCounts = Dictionary(grouping: projectExplorer.tracks, by: { $0.type })
        await MainActor.run {
            explorationResults += "Track Type Statistics:\n"
            for (type, tracks) in trackTypeCounts {
                explorationResults += "  \(type.rawValue): \(tracks.count)\n"
            }
        }
        
        // Count region types
        let regionTypeCounts = Dictionary(grouping: projectExplorer.regions, by: { $0.type })
        await MainActor.run {
            explorationResults += "Region Type Statistics:\n"
            for (type, regions) in regionTypeCounts {
                explorationResults += "  \(type.rawValue): \(regions.count)\n"
            }
        }
        
        // Analyze track length distribution
        let trackLengths = projectExplorer.tracks.map { $0.size.width }
        let avgLength = trackLengths.reduce(0, +) / Double(trackLengths.count)
        await MainActor.run {
            explorationResults += "Average Track Length: \(avgLength)\n"
        }
        
        // Analyze region length distribution
        let regionLengths = projectExplorer.regions.map { $0.size.width }
        let avgRegionLength = regionLengths.reduce(0, +) / Double(regionLengths.count)
        await MainActor.run {
            explorationResults += "Average Region Length: \(avgRegionLength)\n"
        }
    }
    
    /// Find duplicate regions
    func findDuplicateRegions() async -> [String: [LogicRegion]] {
        var regionGroups: [String: [LogicRegion]] = [:]
        
        for region in projectExplorer.regions {
            let key = "\(region.name)_\(region.type.rawValue)_\(region.size.width)_\(region.size.height)"
            if regionGroups[key] == nil {
                regionGroups[key] = []
            }
            regionGroups[key]?.append(region)
        }
        
        // Only return region groups with duplicates
        return regionGroups.filter { $0.value.count > 1 }
    }
    
    /// Optimize project layout
    func optimizeProjectLayout() async {
        await MainActor.run {
            explorationResults += "\n=== Optimizing Project Layout ===\n"
        }
        
        // Group regions by track
        let regionsByTrack = Dictionary(grouping: projectExplorer.regions, by: { $0.trackIndex })
        
        for (trackIndex, regions) in regionsByTrack {
            // Sort by start time
            let sortedRegions = regions.sorted { region1, region2 in
                region1.position.x < region2.position.x
            }
            
            await MainActor.run {
                explorationResults += "Track \(trackIndex) has \(regions.count) regions\n"
            }
            
            // Check for overlaps
            for i in 0..<sortedRegions.count - 1 {
                let currentRegion = sortedRegions[i]
                let nextRegion = sortedRegions[i + 1]
                
                let currentEnd = currentRegion.position.x + currentRegion.size.width
                let nextStart = nextRegion.position.x
                
                if currentEnd > nextStart {
                    await MainActor.run {
                        explorationResults += "  Found overlap: Regions '\(currentRegion.name)' and '\(nextRegion.name)'\n"
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

/// Project Info (for JSON export/import)
struct ProjectInfo: Codable {
    let tracks: [LogicTrack]
    let regions: [LogicRegion]
    let exportDate: Date
}

// Make LogicTrack and LogicRegion support Codable
extension LogicTrack: Codable {
    enum CodingKeys: String, CodingKey {
        case index, name, type, properties, position, size
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(LogicTrackType.self, forKey: .type)
        properties = [:] // Simplified implementation
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        element = AXUIElementCreateSystemWide() // Placeholder
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
    }
}

extension LogicRegion: Codable {
    enum CodingKeys: String, CodingKey {
        case trackIndex, regionIndex, name, type, properties, position, size
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackIndex = try container.decode(Int.self, forKey: .trackIndex)
        regionIndex = try container.decode(Int.self, forKey: .regionIndex)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(LogicRegionType.self, forKey: .type)
        properties = [:] // Simplified implementation
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        element = AXUIElementCreateSystemWide() // Placeholder
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trackIndex, forKey: .trackIndex)
        try container.encode(regionIndex, forKey: .regionIndex)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
    }
}

// Make enums support Codable
extension LogicTrackType: Codable {}
extension LogicRegionType: Codable {}
