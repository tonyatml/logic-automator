import SwiftUI
import Foundation

/// Main content view for the Logic Maestro application
/// Provides a user interface for controlling Logic Pro automation
struct ContentView: View {
    // MARK: - State Properties
    
    /// Observable object that handles Logic Pro automation logic
    @StateObject private var automator = CommandAutomator()
    
    /// Speech recognition manager
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    /// Text input for user commands
    @State private var commandText = ""
    
    @State private var textFocused = false
    
    var inputTxtview: some View {
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
    }
    
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
            
            // Command input area with text editor, microphone, and send button
            VStack(spacing: 8) {
                
                HStack (alignment: .center) {
                    // Text input field for user commands
                    inputTxtview
                    
                    // Microphone button for voice input
                    Button(action: toggleVoiceRecording) {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 18))
                            .foregroundColor(speechRecognizer.isRecording ? .red : .white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(speechRecognizer.isRecording ? 
                                          Color.red.opacity(0.3) : 
                                          Color.gray.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(speechRecognizer.isRecording ? 
                                                   Color.red.opacity(0.6) : 
                                                   Color.gray.opacity(0.4), 
                                                   lineWidth: 1)
                                    )
                            )
                            .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: speechRecognizer.isRecording)
                    }
                    .disabled(!speechRecognizer.isAuthorized)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 6)
                    
                    // Permission request button (shown when not authorized)
                    if !speechRecognizer.isAuthorized {
                        Button(action: {
                            Task {
                                await speechRecognizer.requestPermissions()
                            }
                        }) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 4)
                    }
                    
                    // Send button to execute the command
                    Button(action: sendCommand) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundColor(commandText.isEmpty ? .gray : .white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(commandText.isEmpty ? 
                                          Color.gray.opacity(0.3) : 
                                          Color.blue.opacity(0.6))
                                    .overlay(
                                        Circle()
                                            .stroke(commandText.isEmpty ? 
                                                   Color.gray.opacity(0.5) : 
                                                   Color.blue.opacity(0.8), 
                                                   lineWidth: 1)
                                    )
                            )
                            .scaleEffect(commandText.isEmpty ? 1.0 : 1.05)
                            .animation(.easeInOut(duration: 0.2), value: commandText.isEmpty)
                    }
                    .disabled(commandText.isEmpty)  // Disable when no text entered
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 6)
                }
                

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
                
                // Exit button
                Button(action: exitApp) {
                    HStack {
                        Text("Exit")
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
                    .onAppear {
                // Set up speech recognition callback
                speechRecognizer.onFinalResult = { text in
                    // Replace the text field content with the new recognition result
                    commandText = text
                    // try to auto execute command
                    sendCommand()
                }
            }
        
    }
    
    // MARK: - Action Methods
    
    /// Clears the output log
    private func clearOutput() {
        automator.clearLog()
    }

    /// Sends the current command text to the automator
    /// Clears the input field after sending
    private func sendCommand() {
        NSApplication.shared.deactivate()
        Task {
            await automator.processCommand(commandText)
            commandText = "" // Clear the command after sending
        }
    }
    
    /// Toggle voice recording on/off
    private func toggleVoiceRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
        } else {
            // Clear text field immediately when starting new recording
            commandText = ""
            
            // Check if we need to request permissions first
            if !speechRecognizer.isAuthorized {
                Task {
                    await speechRecognizer.requestPermissions()
                    // If permissions are granted, start recording
                    if speechRecognizer.isAuthorized {
                        await speechRecognizer.startRecording()
                    }
                }
            } else {
                Task {
                    await speechRecognizer.startRecording()
                }
            }
        }
    }
    
    /// Exit the application
    private func exitApp() {
        NSApplication.shared.terminate(nil)
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
