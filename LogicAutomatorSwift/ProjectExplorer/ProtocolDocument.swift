import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Protocol Document for File Export

struct ProtocolDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let protocolData: SaveProtocolModal.ProtocolData?
    
    init(protocolData: SaveProtocolModal.ProtocolData?) {
        self.protocolData = protocolData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Parse the JSON to create ProtocolData
        guard let name = json["protocol_name"] as? String,
              let tags = json["tags"] as? [String],
              let description = json["description"] as? String else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        self.protocolData = SaveProtocolModal.ProtocolData(
            name: name,
            tags: tags,
            description: description
        )
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let protocolData = protocolData else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        
        // Create the protocol data dictionary
        let protocolDataDict: [String: Any] = [
            "protocol_name": protocolData.name,
            "tags": protocolData.tags,
            "description": protocolData.description,
            "created_at": Date().timeIntervalSince1970,
            "client_id": "logic-automator-client",
            "session_id": UUID().uuidString,
            "recorded_events_count": 0
        ]
        
        let data = try JSONSerialization.data(withJSONObject: protocolDataDict, options: [.prettyPrinted, .sortedKeys])
        return FileWrapper(regularFileWithContents: data)
    }
}
