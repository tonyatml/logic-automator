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
    
    private let keys = ["C major", "G major", "D major", "A major", "E major", "B major", "F# major", "C# major",
                       "F major", "Bb major", "Eb major", "Ab major", "Db major", "Gb major", "Cb major",
                       "A minor", "E minor", "B minor", "F# minor", "C# minor", "G# minor", "D# minor", "A# minor",
                       "D minor", "G minor", "C minor", "F minor", "Bb minor", "Eb minor", "Ab minor"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            VStack(spacing: 8) {
                Text("Logic Automator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Swift-powered Logic Pro automation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // Status indicator
            StatusView(danceAutomator: danceAutomator)
            
            // Main configuration area
            ScrollView {
                VStack(spacing: 16) {
                    // Project name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter project name...", text: $projectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    
                    // Tempo and key
                    HStack(spacing: 16) {
                        // Tempo setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tempo (BPM)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(tempo) },
                                    set: { tempo = Int($0) }
                                ), in: 60...200, step: 1)
                                
                                Text("\(tempo)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(width: 50)
                            }
                        }
                        
                        // Key setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Key", selection: $key) {
                                ForEach(keys, id: \.self) { key in
                                    Text(key).tag(key)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // MIDI file selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MIDI File (Optional)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("Select MIDI file...", text: $midiFilePath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                            
                            Button("Browse") {
                                showingFilePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Preset buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Presets")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            PresetButton(title: "House", config: DanceGoAutomator.PresetConfigs.house)
                            PresetButton(title: "Techno", config: DanceGoAutomator.PresetConfigs.techno)
                            PresetButton(title: "Trance", config: DanceGoAutomator.PresetConfigs.trance)
                            PresetButton(title: "Dubstep", config: DanceGoAutomator.PresetConfigs.dubstep)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                // Create project button
                Button(action: createProject) {
                    HStack {
                        if danceAutomator.isWorking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        
                        Text(danceAutomator.isWorking ? "Creating..." : "Create Dance Project")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(danceAutomator.isWorking ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(danceAutomator.isWorking || projectName.isEmpty)
                
                // Stop button
                if danceAutomator.isWorking {
                    Button("Stop") {
                        // Here you can add stop logic
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                // Test new track button
                Button(action: testNewTrack) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .font(.title2)
                        Text("Test New Track")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(danceAutomator.isWorking)
                
                // Test MIDI import button
                if !midiFilePath.isEmpty {
                    Button(action: testMidiImport) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                            Text("Test MIDI Import")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(danceAutomator.isWorking)
                }
                
                // Advanced Region Operations Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced Region Operations")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Bar number input
                    HStack {
                        Text("Target Bar:")
                            .frame(width: 80, alignment: .leading)
                        TextField("33", value: $targetBar, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    // Track index input
                    HStack {
                        Text("Track Index:")
                            .frame(width: 80, alignment: .leading)
                        TextField("61", value: $targetTrackIndex, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    // Track name input (optional)
                    HStack {
                        Text("Track Name:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Optional", text: $targetTrackName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Audio file selection
                    HStack {
                        Text("Audio File:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Select audio file...", text: $audioFilePath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(true)
                        
                        Button("Browse") {
                            showingAudioFilePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Test Region Replacement button
                    if !audioFilePath.isEmpty {
                        Button(action: testRegionReplacement) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title2)
                                Text("Test Region Replacement")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(danceAutomator.isWorking)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 700)
        .background(Color(NSColor.controlBackgroundColor))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.midi],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    midiFilePath = file.path
                }
            case .failure(let error):
                print("File selection failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingAudioFilePicker,
            allowedContentTypes: [.audio, .wav, .aiff, .mp3],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    audioFilePath = file.path
                }
            case .failure(let error):
                print("Audio file selection failed: \(error.localizedDescription)")
            }
        }
        .alert("Error", isPresented: .constant(danceAutomator.lastError != nil)) {
            Button("OK") {
                danceAutomator.clearError()
            }
        } message: {
            if let error = danceAutomator.lastError {
                Text(error)
            }
        }
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
}

// MARK: - Status View
struct StatusView: View {
    @ObservedObject var danceAutomator: DanceGoAutomator
    
    var body: some View {
        VStack(spacing: 8) {
            // Connection status
            HStack {
                Circle()
                    .fill(danceAutomator.isLogicProRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(danceAutomator.isLogicProRunning ? "Logic Pro Connected" : "Logic Pro Not Running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Permission status
            HStack {
                Circle()
                    .fill(danceAutomator.hasPermissions ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(danceAutomator.hasPermissions ? "Permissions Granted" : "Permissions Required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current step
            if !danceAutomator.currentStep.isEmpty {
                VStack(spacing: 4) {
                    Text(danceAutomator.currentStep)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if danceAutomator.progress > 0 {
                        ProgressView(value: danceAutomator.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 20)
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
