import SwiftUI
import Foundation

/// Main content view for the Logic Maestro application
/// Provides a user interface for controlling Logic Pro automation
struct ContentView: View {
    // MARK: - State Properties
    
    /// Observable object that handles Logic Pro automation logic
    @StateObject private var automator = CommandAutomator()
    
    /// Text input for user commands
    @State private var commandText = ""
    
    var body: some View {
        VStack {
            // MARK: - Header Section
            
            // Title bar with logo and app name
            HStack {
                Image("logo")
                    .padding(.vertical)
                
                Text("LOGIC MAESTRO")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // MARK: - Status Section
            
            // Status indicator showing connection and permission status
            StatusView(commandAutomator: automator)
                .padding(.top, -20)
            
            // MARK: - Command Input Section
            
            // Command input area with text editor and send button
            HStack (alignment: .center) {
                // Text input field for user commands
                TextEditor(text: $commandText)
                    .frame(height: 40)
                    .padding(.horizontal, 6)  // Internal padding for text positioning
                    .padding(.vertical, 6)    // Internal padding for text positioning
                    .overlay(
                        // Border around the text editor
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.leading,16)     // External padding for layout
                
                // Send button to execute the command
                Button(action: sendCommand) {
                    HStack {
                        Text("Send")
                            .font(.caption)
                    }
                    .frame(maxWidth: 80)
                    .padding(.vertical, 6)
                    
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .disabled(commandText.isEmpty)  // Disable when no text entered
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing,6)
            }
            
            // MARK: - Output Log Section
            
            // Scrollable area to display automation output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(automator.outputLog.isEmpty ? "No output yet..." : automator.outputLog)
                        .font(.system(.caption2, design: .monospaced))  // Monospace font for log readability
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .cornerRadius(6)
                        .textSelection(.enabled)  // Allow text selection for copying
                        .id("outputLog")  // ID for scrolling to this view
                }
                .frame(maxHeight: .infinity)  // Take remaining vertical space
                .padding(.horizontal, 12)
                .scrollIndicators(.visible, axes: .vertical)  // Show vertical scroll indicators
                .onChange(of: automator.outputLog) { _ in
                    // Auto-scroll to bottom when log content changes
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("outputLog", anchor: .bottom)
                    }
                }
            }
            
            Spacer()
            
            // MARK: - Control Buttons Section
            
            // Bottom control buttons for various functions
            HStack {
                // Clear log button
                Button(action: clearOutput) {
                    HStack {
                        Text("Clear Log")
                            .font(.caption)
                    }
                    .frame(maxWidth: 80)
                    .padding(.vertical, 6)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .disabled(automator.outputLog.isEmpty)  // Disable when log is empty
                .buttonStyle(PlainButtonStyle())
                
                // Settings button (currently uses clearOutput action as placeholder)
                Button(action: clearOutput) {
                    HStack {
                        Text("Settings")
                            .font(.caption)
                    }
                    .frame(maxWidth: 80)
                    .padding(.vertical, 6)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Help button (currently uses clearOutput action as placeholder)
                Button(action: automator.showHelp) {
                    HStack {
                        Text("Help")
                            .font(.caption)
                    }
                    .frame(maxWidth: 80)
                    .padding(.vertical, 6)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        // MARK: - View Configuration
        
        .frame(width: 300, height: 500)  // Fixed window size
        .background(.black)              // Dark theme background
        .foregroundColor(.white)         // Light text for dark theme
        
    }
    
    // MARK: - Action Methods
    
    /// Clears the output log
    private func clearOutput() {
        automator.clearLog()
    }

    /// Sends the current command text to the automator
    /// Clears the input field after sending
    private func sendCommand() {
        Task {
            await automator.processCommand(commandText)
            commandText = "" // Clear the command after sending
        }
    }
}

// MARK: - Status View Component

/// Displays the current status of Logic Pro connection and permissions
struct StatusView: View {
    /// Reference to the main automator object for status monitoring
    @ObservedObject var commandAutomator: CommandAutomator
    
    var body: some View {
        VStack {
            HStack {
                // MARK: - Connection Status Indicator
                
                // Logic Pro connection status with colored indicator
                HStack {
                    Circle()
                        .fill(commandAutomator.isLogicProRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(commandAutomator.isLogicProRunning ? "Logic Pro Connected" : "Logic Pro Not Running")
                        .font(.caption)
                }
                
                // MARK: - Permission Status Indicator
                
                // Permission status with colored indicator
                HStack {
                    Circle()
                        .fill(commandAutomator.hasPermissions ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(commandAutomator.hasPermissions ? "Permissions Granted" : "Permissions Required")
                        .font(.caption)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

/// SwiftUI preview for development and testing
#Preview {
    ContentView()
}
