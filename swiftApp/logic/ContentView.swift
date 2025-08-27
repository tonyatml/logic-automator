import SwiftUI
import Foundation

struct ContentView: View {
    @State private var commandText = ""
    @State private var outputText = ""
    @State private var isInitialized = false
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Dance & Go Automator")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            // Initialization Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Setup")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if isInitialized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Button(action: runSetup) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.caption)
                        Text("Initialize Setup")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(isInitialized ? Color.green.opacity(0.2) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .disabled(isInitialized)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            Divider()
            
            // Command Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Command")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter command...", text: $commandText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .lineLimit(2...4)
                
                HStack(spacing: 8) {
                    Button(action: sendCommand) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane")
                                    .font(.caption)
                            }
                            Text("Send")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(commandText.isEmpty || isRunning || !isInitialized)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: clearOutput) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("Clear")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Output Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if !outputText.isEmpty {
                        Text("\(outputText.components(separatedBy: "\n").count) lines")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                ScrollView {
                    Text(outputText.isEmpty ? "No output yet..." : outputText)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
                .frame(maxHeight: 120)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 320, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func runSetup() {
        isRunning = true
        outputText += "🔧 Running setup...\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let setupResult = runShellCommand("cd '\(getProjectRoot())' && chmod +x setup.sh && ./setup.sh")
            
            DispatchQueue.main.async {
                outputText += setupResult
                isInitialized = true
                isRunning = false
                outputText += "✅ Setup completed!\n"
            }
        }
    }
    
    private func sendCommand() {
        guard !commandText.isEmpty else { return }
        
        isRunning = true
        outputText += "🚀 Sending command: \(commandText)\n"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let command = "cd '\(getProjectRoot())' && python3 dance_go_automator.py \(commandText)"
            let result = runShellCommand(command)
            
            DispatchQueue.main.async {
                outputText += result
                isRunning = false
                outputText += "✅ Command completed!\n"
            }
        }
    }
    
    private func clearOutput() {
        outputText = ""
    }
    
    private func getProjectRoot() -> String {
        // Get the path to the parent directory (logic-automator)
        let currentPath = FileManager.default.currentDirectoryPath
        return currentPath.replacingOccurrences(of: "/swiftApp/logic", with: "")
    }
    
    private func runShellCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Error: Could not read output"
            
            return output
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
