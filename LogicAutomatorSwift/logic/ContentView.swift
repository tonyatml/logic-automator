import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var automator = DanceGoAutomator()
    @State private var projectName = ""
    @State private var commandText = ""
    
    var body: some View {
        VStack {
            // Title
            HStack {
                Image("logo")
                    .padding(.vertical)
                
                Text("LOGIC MAESTRO")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Status indicator
            StatusView(danceAutomator: automator)
                .padding(.top, -20)
            
            // Command input area
            HStack (alignment: .center) {
                TextEditor(text: $commandText)
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.leading,20)
                
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
                .disabled(commandText.isEmpty)
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing,6)
            }
            
            ScrollView {
                Text(automator.outputLog.isEmpty ? "No output yet..." : automator.outputLog)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .cornerRadius(6)
                    .textSelection(.enabled)
                
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)
            
            Spacer()
            
            // bottom buttons
            HStack {
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
                .disabled(automator.outputLog.isEmpty)
                .buttonStyle(PlainButtonStyle())
                
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
                .disabled(automator.outputLog.isEmpty)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: clearOutput) {
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
                .disabled(automator.outputLog.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .frame(width: 300, height: 500)
        .background(.black)
        .foregroundColor(.white)
        
    }
    
    private func clearOutput() {
        automator.clearLog()
    }

    private func sendCommand() {
        Task {
            await automator.processCommand(commandText)
            commandText = "" // Clear the command after sending
        }
    }
}

// MARK: - Status View
struct StatusView: View {
    @ObservedObject var danceAutomator: DanceGoAutomator
    
    var body: some View {
        VStack {
            HStack {
                // Connection status
                HStack {
                    Circle()
                        .fill(danceAutomator.isLogicProRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(danceAutomator.isLogicProRunning ? "Logic Pro Connected" : "Logic Pro Not Running")
                        .font(.caption)
                }
                
                // Permission status
                HStack {
                    Circle()
                        .fill(danceAutomator.hasPermissions ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(danceAutomator.hasPermissions ? "Permissions Granted" : "Permissions Required")
                        .font(.caption)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ContentView()
}
