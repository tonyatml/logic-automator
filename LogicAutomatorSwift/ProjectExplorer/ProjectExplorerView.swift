import SwiftUI

/// Logic Pro Project Explorer UI Interface
struct ProjectExplorerView: View {
    @StateObject private var explorer = LogicProjectExplorer()
    @StateObject private var monitor = LogicMonitor()
    
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
                
                // Monitor control buttons
                HStack(spacing: 8) {
                    Button(action: {
                        monitor.startMonitoring()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Monitor")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(monitor.isMonitoring || !monitor.logicProConnected)
                    
                    Button(action: {
                        monitor.stopMonitoring()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Monitor")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(!monitor.isMonitoring)           
                }
                
                Button(action: {
                    Task {
                        await explorer.exploreProjectExample()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Explore Project")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(explorer.isExploring)
                
                Button(action: {
                    monitor.checkLogicProStatus()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Status")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    explorer.explorationResults = ""
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
                .disabled(explorer.explorationResults.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Log display area
            VStack(alignment: .leading, spacing: 16) {
                // Monitor status
                HStack {
                    Circle()
                        .fill(monitor.logicProConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(monitor.logicProConnected ? "Logic Pro Connected" : "Logic Pro Not Running")
                        .font(.headline)
                    
                    Spacer()
                    
                    Circle()
                        .fill(monitor.isMonitoring ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(monitor.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    // Session recording status
                    let sessionStats = monitor.getSessionStats()
                    if let recordingEnabled = sessionStats["recordingEnabled"] as? Bool, recordingEnabled {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session Recording")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            
                            if let notificationCount = sessionStats["notificationCount"] as? Int {
                                Text("\(notificationCount) notifications")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let filePath = monitor.getSessionFilePath() {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("File: \(URL(fileURLWithPath: filePath).lastPathComponent)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Location: ~/Documents/")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
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
                                .padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id("logContent")
                        }
                        .frame(maxHeight: 400)
                        .onChange(of: explorer.explorationResults) { _ in
                            // Auto-scroll to bottom when log content changes
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("logContent", anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 600)
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
}
