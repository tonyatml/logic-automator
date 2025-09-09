//
//  SaveProtocolModal.swift
//  Logic Pro Project Explorer
//
//  Modal for saving recorded protocols with metadata
//

import SwiftUI

struct SaveProtocolModal: View {
    @Binding var isPresented: Bool
    @State private var protocolName: String = ""
    @State private var tags: String = ""
    @State private var description: String = ""
    @State private var showingValidationError = false
    
    let onSave: (ProtocolData) -> Void
    
    enum ProtocolVisibility: String, CaseIterable {
        case `private` = "Private"
        case shared = "Shared"
        case marketplace = "Marketplace"
    }
    
    struct ProtocolData {
        let name: String
        let tags: [String]
        let description: String
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Save Protocol")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // Form fields
            VStack(spacing: 16) {
                // Protocol Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protocol Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("e.g. Slice Region into 8", text: $protocolName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("e.g. editing, slicing, vocal, drums, fx", text: $tags)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    
                    Text("Separate tags with commas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Short description of what this protocol does...", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .lineLimit(3...6)
                }
                
            }
            .padding(.horizontal)
            
            // Validation error
            if showingValidationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text("Protocol name is required")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Save Protocol") {
                    saveProtocol()
                }
                .buttonStyle(.borderedProminent)
                .disabled(protocolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
    
    private func saveProtocol() {
        let trimmedName = protocolName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showingValidationError = true
            return
        }
        
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let protocolData = ProtocolData(
            name: trimmedName,
            tags: tagArray,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onSave(protocolData)
        isPresented = false
    }
}

#Preview {
    SaveProtocolModal(isPresented: .constant(true)) { protocolData in
        print("Saved protocol: \(protocolData.name)")
    }
}
