import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var danceAutomator = DanceGoAutomator()
    @State private var projectName = ""
    @State private var tempo = 124
    @State private var key = "A minor"
    @State private var midiFilePath = ""
    @State private var showingFilePicker = false
    @State private var audioFilePath = "/Users/tonyniu/Desktop/test.midi"
    @State private var showingAudioFilePicker = false
    @State private var targetBar = 33
    @State private var targetTrackName = ""
    @State private var targetTrackIndex = 61
    @State private var showingPresetPicker = false
    @State private var selectedPreset: DanceGoAutomator.ProjectConfig?
    @State private var commandText = ""
    // Remove this line as we'll use danceAutomator.outputLog instead
    
    private let keys = ["C major", "G major", "D major", "A major", "E major", "B major", "F# major", "C# major",
                        "F major", "Bb major", "Eb major", "Ab major", "Db major", "Gb major", "Cb major",
                        "A minor", "E minor", "B minor", "F# minor", "C# minor", "G# minor", "D# minor", "A# minor",
                        "D minor", "G minor", "C minor", "F minor", "Bb minor", "Eb minor", "Ab minor"]
    
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
            StatusView(danceAutomator: danceAutomator)
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
                Text(danceAutomator.outputLog.isEmpty ? "No output yet..." : danceAutomator.outputLog)
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
                .disabled(danceAutomator.outputLog.isEmpty)
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
                .disabled(danceAutomator.outputLog.isEmpty)
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
                .disabled(danceAutomator.outputLog.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .frame(width: 300, height: 500)
        .background(.black)
        .foregroundColor(.white)
        
    }
    
    private func clearOutput() {
        danceAutomator.clearLog()
    }
    
    private func createProject() {
        Task {
            await danceAutomator.createDanceProject(
                name: projectName,
                tempo: tempo,
                key: key,
                midiFile: midiFilePath.isEmpty ? nil : midiFilePath
            )
        }
    }
    
    private func testNewTrack() {
        Task {
            await danceAutomator.testNewTrack()
        }
    }
    
    private func testMidiImport() {
        Task {
            await danceAutomator.testMidiImport(midiFilePath: midiFilePath)
        }
    }
    
    private func testRegionReplacement() {
        Task {
            let trackName = targetTrackName.isEmpty ? nil : targetTrackName
            await danceAutomator.testRegionReplacement(
                bar: targetBar,
                audioFilePath: audioFilePath,
                trackName: trackName,
                trackIndex: targetTrackIndex
            )
        }
    }
    
    private func sendCommand() {
        Task {
            await danceAutomator.processCommand(commandText)
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

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let config: DanceGoAutomator.ProjectConfig
    @StateObject private var danceAutomator = DanceGoAutomator()
    
    var body: some View {
        Button(action: {
            Task {
                await danceAutomator.createPresetProject(config)
            }
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(config.tempo) BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(danceAutomator.isWorking)
    }
}

#Preview {
    ContentView()
}
