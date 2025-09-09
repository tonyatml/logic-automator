//
//  ProtocolLibraryManager.swift
//  Logic Pro Project Explorer
//
//  Manages the local protocol library and server synchronization
//

import Foundation

class ProtocolLibraryManager: ObservableObject {
    @Published var protocols: [SavedProtocol] = []
    
    struct SavedProtocol: Identifiable, Codable {
        let id = UUID()
        let name: String
        let tags: [String]
        let description: String
        let visibility: String
        let createdAt: TimeInterval
        let filePath: String
        let recordedEventsCount: Int
        let sessionId: String
    }
    
    private let protocolsDirectory: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        protocolsDirectory = documentsPath.appendingPathComponent("LogicAutomator/Protocols")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: protocolsDirectory, withIntermediateDirectories: true)
        
        loadProtocols()
    }
    
    /// Load all protocols from the local library
    func loadProtocols() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: protocolsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            protocols = files.compactMap { fileURL in
                guard fileURL.pathExtension == "json" else { return nil }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    guard let name = json?["protocol_name"] as? String,
                          let tags = json?["tags"] as? [String],
                          let description = json?["description"] as? String,
                          let visibility = json?["visibility"] as? String,
                          let createdAt = json?["created_at"] as? TimeInterval,
                          let sessionId = json?["session_id"] as? String,
                          let recordedEventsCount = json?["recorded_events_count"] as? Int else {
                        return nil
                    }
                    
                    return SavedProtocol(
                        name: name,
                        tags: tags,
                        description: description,
                        visibility: visibility,
                        createdAt: createdAt,
                        filePath: fileURL.path,
                        recordedEventsCount: recordedEventsCount,
                        sessionId: sessionId
                    )
                } catch {
                    print("❌ Failed to load protocol from \(fileURL.lastPathComponent): \(error)")
                    return nil
                }
            }
            
            // Sort by creation date (newest first)
            protocols.sort { $0.createdAt > $1.createdAt }
            
        } catch {
            print("❌ Failed to load protocols: \(error)")
        }
    }
    
    /// Get protocol file path
    func getProtocolFilePath(for name: String) -> String? {
        return protocols.first { $0.name == name }?.filePath
    }
    
    /// Delete a protocol
    func deleteProtocol(_ savedProtocol: SavedProtocol) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: savedProtocol.filePath)
            loadProtocols() // Reload the list
            return true
        } catch {
            print("❌ Failed to delete protocol: \(error)")
            return false
        }
    }
    
    /// Get protocols by tag
    func getProtocolsByTag(_ tag: String) -> [SavedProtocol] {
        return protocols.filter { $0.tags.contains(tag) }
    }
    
    /// Get protocols by visibility
    func getProtocolsByVisibility(_ visibility: String) -> [SavedProtocol] {
        return protocols.filter { $0.visibility == visibility }
    }
    
    /// Search protocols
    func searchProtocols(_ query: String) -> [SavedProtocol] {
        let lowercaseQuery = query.lowercased()
        return protocols.filter { savedProtocol in
            savedProtocol.name.lowercased().contains(lowercaseQuery) ||
            savedProtocol.description.lowercased().contains(lowercaseQuery) ||
            savedProtocol.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    /// Get library statistics
    func getLibraryStats() -> (total: Int, private: Int, shared: Int, marketplace: Int) {
        let total = protocols.count
        let privateCount = protocols.filter { $0.visibility == "Private" }.count
        let sharedCount = protocols.filter { $0.visibility == "Shared" }.count
        let marketplaceCount = protocols.filter { $0.visibility == "Marketplace" }.count
        
        return (total, privateCount, sharedCount, marketplaceCount)
    }
    
    /// Get all unique tags
    func getAllTags() -> [String] {
        let allTags = protocols.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
}
