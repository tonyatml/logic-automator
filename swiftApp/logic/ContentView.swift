import SwiftUI
import Foundation

struct ContentView: View {
    @State private var commandText = ""
    @State private var outputText = ""
    @State private var isInitialized = false
    @State private var isRunning = false
    
    var body: some View {
        VStack {
            
            // Command Section
            VStack {
                
                TextField("Enter command...", text: $commandText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                
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
                    .disabled(commandText.isEmpty || isRunning )
                    .buttonStyle(PlainButtonStyle())
                    
                }
            }
            .padding()
            
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
                    Button(action: clearOutput) {
                        HStack {
                            Text("Clear")
                                .font(.caption)
                        }
                        .frame(maxWidth: 80)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .cornerRadius(6)
                    }
                    .disabled(outputText.isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
                
                ScrollView {
                    Text(outputText.isEmpty ? "No output yet..." : outputText)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 200, height: outputText.isEmpty ? 200: 400)
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
            let bundlePath = Bundle.main.bundlePath
            let pythonScriptPath = "\(bundlePath)/Contents/Resources/dance_go_automator.py"
            let projectRoot = getProjectRoot()
            let command = "cd '\(projectRoot)' && /usr/bin/python3 '\(pythonScriptPath)' \(commandText)"
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
