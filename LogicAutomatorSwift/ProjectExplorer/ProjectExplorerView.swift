import SwiftUI
import UniformTypeIdentifiers


/// Logic Pro Project Explorer UI Interface
struct ProjectExplorerView: View {
    @StateObject private var explorer = LogicProjectExplorer()
    @StateObject private var monitor = LogicMonitor()
    @State private var showingSaveProtocolModal = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var showingSaveDialog = false
    @State private var pendingProtocolData: SaveProtocolModal.ProtocolData?
    @State private var showingFilterConfig = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Logic Pro Explorer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Monitor status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(monitor.logicProConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(monitor.logicProConnected ? "Logic Pro" : "No Logic Pro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Learning Mode Buttons
                HStack(spacing: 8) {
                    // Start Learning Button
                    Button(action: {
                        monitor.startLearning()
                    }) {
                        HStack {
                            if monitor.isLearning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "brain.head.profile")
                            }
                            Text(monitor.isLearning ? "Learning..." : "Start Learning")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(monitor.isLearning ? Color.green.opacity(0.8) : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .scaleEffect(monitor.isLearning ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: monitor.isLearning)
                    }
                    .disabled(monitor.isLearning || !monitor.logicProConnected)
                    .help("Recording user actions to build a macro")
                    
                    // Stop Learning Button
                    Button(action: {
                        monitor.stopLearning()
                        showingSaveProtocolModal = true
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(!monitor.isLearning)
                    .help("Stop and save this recording session")
                    
                    // Save Protocol Button
                    Button(action: {
                        // Stop learning mode before saving
                        if monitor.isLearning {
                            monitor.stopLearning()
                        }
                        showingSaveProtocolModal = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Protocol")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(monitor.recordedEventsCount == 0)
                    .help("Save the recorded protocol")
                }
                
                
                Button(action: {
                    explorer.explorationResults = ""
                    monitor.recordedEventsCount = 0
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Log")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(explorer.explorationResults.isEmpty && monitor.recordedEventsCount == 0)
                .help("Erase current session events (cannot be undone)")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Log display area
            VStack(alignment: .leading, spacing: 16) {
                // Enhanced Status Bar
                HStack(spacing: 20) {
                    // Logic Pro Connection Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.logicProConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(monitor.logicProConnected ? "Logic Pro Connected" : "Logic Pro Not Running")
                            .font(.headline)
                    }
                    
                    // Monitoring Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.isMonitoring ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        
                        Text(monitor.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                            .font(.subheadline)
                    }
                    
                    // Learning/Recording Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.isLearning ? Color.red : Color.orange)
                            .frame(width: 12, height: 12)
                            .scaleEffect(monitor.isLearning ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: monitor.isLearning)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(monitor.isLearning ? "Recording" : "Session Recording")
                                .font(.subheadline)
                                .foregroundColor(monitor.isLearning ? .red : .orange)
                            
                            if monitor.isLearning {
                                HStack(spacing: 8) {
                                    Text(formatDuration(monitor.recordingDuration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(monitor.recordedEventsCount) actions recorded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Inactive")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Event Filtering Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(monitor.filteringEnabled ? Color.blue : Color.gray)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Event Filtering")
                                .font(.subheadline)
                                .foregroundColor(monitor.filteringEnabled ? .blue : .gray)
                            
                            if monitor.filteringEnabled {
                                let stats = monitor.filteringStats
                                HStack(spacing: 8) {
                                    Text("\(Int(stats.noiseReductionPercentage))% noise reduced")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(stats.filteredEvents)/\(stats.totalEvents) events")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Disabled")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Latest notification
                if !monitor.lastNotification.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Event:")
                            .font(.headline)
                        
                        Text(monitor.lastNotification)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Filtering Statistics (when filtering is enabled)
                if monitor.filteringEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Filtering Statistics:")
                                .font(.headline)
                            
                            // Filtering controls next to label
                            HStack(spacing: 12) {
                                // Filter Configuration Button
                                Button(action: {
                                    showingFilterConfig = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        Text("Filter")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                }
                                .help("Configure event filtering")
                                
                                // Reset Stats Button
                                Button(action: {
                                    monitor.resetFilteringStats()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Reset")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                }
                                .help("Reset filtering statistics")
                            }
                            
                            Spacer()
                        }
                        
                        let stats = monitor.filteringStats
                        if stats.totalEvents > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                // Overall statistics
                                HStack {
                                    Text("Total Events: \(stats.totalEvents)")
                                    Spacer()
                                    Text("Filtered: \(stats.filteredEvents)")
                                    Spacer()
                                    Text("Noise Reduction: \(Int(stats.noiseReductionPercentage))%")
                                        .foregroundColor(.green)
                                }
                                .font(.caption)
                                
                                // Most common event types
                                if !stats.mostCommonEventTypes.isEmpty {
                                    Text("Most Common Event Types:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(Array(stats.mostCommonEventTypes.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { eventType, count in
                                        HStack {
                                            Text("• \(eventType)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(count)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // Most common element types
                                if !stats.mostCommonElementTypes.isEmpty {
                                    Text("Most Common Element Types:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(Array(stats.mostCommonElementTypes.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { elementType, count in
                                        HStack {
                                            Text("• \(elementType)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(count)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // Filtering reasons
                                if !stats.filteringReasons.isEmpty {
                                    Text("Filtering Reasons:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(Array(stats.filteringReasons.sorted { $0.value > $1.value }.prefix(5)), id: \.key) { reason, count in
                                        HStack {
                                            Text("• \(reason)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(count)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                        } else {
                            Text("No events recorded yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Filtering Toggle (when filtering is disabled)
                if !monitor.filteringEnabled {
                    HStack {
                        Text("Event Filtering:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            monitor.setFilteringEnabled(true)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.caption)
                                Text("Enable Filtering")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .help("Enable event filtering to reduce noise")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Log display
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Event Logs:")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !explorer.explorationResults.isEmpty {
                            Text("\(explorer.explorationResults.components(separatedBy: "\n").count) lines")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(explorer.explorationResults.isEmpty ? "No logs yet..." : explorer.explorationResults)
                                .font(.system(.body, design: .monospaced))
                                //.padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id("logContent")
                        }
                        //.frame(maxHeight: 400)
                        .onChange(of: explorer.explorationResults) { _ in
                            // Auto-scroll to bottom when log content changes
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("logContent", anchor: .bottom)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingSaveProtocolModal) {
            SaveProtocolModal(isPresented: $showingSaveProtocolModal) { protocolData in
                saveProtocol(protocolData)
            }
        }
        .sheet(isPresented: $showingFilterConfig) {
            FilterConfigurationModal(isPresented: $showingFilterConfig, monitor: monitor)
        }
        .fileExporter(
            isPresented: $showingSaveDialog,
            document: ProtocolDocument(protocolData: pendingProtocolData),
            contentType: .json,
            defaultFilename: pendingProtocolData?.name ?? "protocol"
        ) { result in
            switch result {
            case .success(let url):
                if let protocolData = pendingProtocolData {
                    let success = saveProtocolToUserSelectedDirectory(protocolData, to: url)
                    if success {
                        toastMessage = "Protocol \"\(protocolData.name)\" saved successfully to \(url.lastPathComponent)"
                        // Clear the recorded events count after saving, but keep the log output
                        monitor.recordedEventsCount = 0
                        // explorer.explorationResults = "" // Don't clear log output
                    } else {
                        toastMessage = "Failed to save protocol \"\(protocolData.name)\""
                    }
                    showingToast = true
                    
                    // Hide toast after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingToast = false
                    }
                }
                pendingProtocolData = nil
            case .failure(let error):
                toastMessage = "Failed to save protocol: \(error.localizedDescription)"
                showingToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showingToast = false
                }
                pendingProtocolData = nil
            }
        }
        .overlay(
            // Toast notification
            Group {
                if showingToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toastMessage)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 10)
                        .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showingToast)
                }
            }
        )
        .onAppear {
            // Set up monitor logging to output to the explorer's log
            monitor.logCallback = { message in
                Task { @MainActor in
                    explorer.appendToLog(message)
                }
            }
            
            // SystemInfoUtil.printLightweightSystemInfo()
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveProtocol(_ protocolData: SaveProtocolModal.ProtocolData) {
        // Store protocol data and show save dialog
        pendingProtocolData = protocolData
        showingSaveDialog = true
    }
    
    private func saveProtocolToUserSelectedDirectory(_ protocolData: SaveProtocolModal.ProtocolData, to fileURL: URL) -> Bool {
        // Get current session data
        let systemReport = SystemInfoUtil.getLightweightSystemReport()
        
        // Get actual recorded events from LogicMonitor
        let recordedEvents = monitor.getAllRecordedEvents()
        
        // Create protocol data with actual events
        var protocolDataDict: [String: Any] = [
            "protocol_name": protocolData.name,
            "tags": protocolData.tags,
            "description": protocolData.description,
            "created_at": Date().timeIntervalSince1970,
            "client_id": "logic-automator-client",
            "session_id": UUID().uuidString,
            "system_info": systemReport["system_info"] ?? [:],
            "workflow": systemReport["workflow"] ?? [:],
            "performance": systemReport["performance"] ?? [:],
            "project_info": systemReport["project_info"] ?? [:],
            "protocol_data": [
                "protocol_name": protocolData.name,
                "tags": protocolData.tags,
                "description": protocolData.description,
                "events": recordedEvents
            ]
        ]
        
        // Add recorded events count
        protocolDataDict["recorded_events_count"] = monitor.recordedEventsCount
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: protocolDataDict, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: fileURL)
            
            monitor.log("✅ Protocol saved to: \(fileURL.path)")
            
            // Automatically upload protocol to server after saving locally
            uploadProtocolToServer(protocolDataDict)
            
            return true
        } catch {
            print("❌ Failed to save protocol: \(error)")
            return false
        }
    }
    
    private func uploadProtocolToServer(_ protocolData: [String: Any]) {
        let serverURL = "https://logic-copilot-server.vercel.app/api/logs/batch"
        
        guard let url = URL(string: serverURL) else {
            print("❌ Invalid server URL: \(serverURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: protocolData, options: [.prettyPrinted, .sortedKeys])
            request.httpBody = jsonData
            
            print("📤 Uploading protocol to server...")
            print("📦 Protocol data size: \(jsonData.count) bytes")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    monitor.log("❌ Protocol upload failed: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Protocol upload response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        monitor.log("✅ Protocol successfully uploaded to server")
                    } else {
                        monitor.log("❌ Protocol upload returned status code: \(httpResponse.statusCode)")
                    }
                }
            }
            
            task.resume()
        } catch {
            monitor.log("❌ Failed to serialize protocol data: \(error)")
        }
    }
}
