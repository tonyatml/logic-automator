import Foundation
import SwiftUI

/// Dance & Go automation class
/// Provides high-level dance project creation and automation functionality
class DanceGoAutomator: ObservableObject {
    private let logicAutomator = LogicAutomator()
    
    @Published var isWorking = false
    @Published var currentStep = ""
    @Published var progress: Double = 0.0
    @Published var lastError: String?
    
    // MARK: - Project Configuration
    
    /// Project configuration structure
    struct ProjectConfig {
        let name: String
        let tempo: Int
        let key: String
        let midiFile: String?
        let outputDirectory: String
        
        init(name: String, tempo: Int = 124, key: String = "A minor", midiFile: String? = nil, outputDirectory: String? = nil) {
            self.name = name
            self.tempo = tempo
            self.key = key
            self.midiFile = midiFile
            self.outputDirectory = outputDirectory ?? getDefaultOutputDirectory()
        }
    }
    
    // MARK: - Main Functions
    
    /// Create dance project
    /// - Parameter config: Project configuration
    func createDanceProject(config: ProjectConfig) async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
        }
        
        do {
            // Check permissions
            await updateStep("Checking permissions...", progress: 0.1)
            guard logicAutomator.checkAccessibilityPermissions() else {
                throw LogicError.accessibilityNotEnabled
            }
            
            // Launch Logic Pro
            await updateStep("Launching Logic Pro...", progress: 0.2)
            try await logicAutomator.launchLogicPro()
            
            // Create project
            await updateStep("Creating project from template...", progress: 0.3)
            let projectPath = try await createProjectFromTemplate(config: config)
            
            // Open project
            await updateStep("Opening project in Logic Pro...", progress: 0.5)
            try await logicAutomator.openProject(projectPath)
            
            // Set tempo
            await updateStep("Setting tempo to \(config.tempo) BPM...", progress: 0.6)
            try await logicAutomator.setTempo(config.tempo)
            
            // Set key
            await updateStep("Setting key to \(config.key)...", progress: 0.7)
            try await logicAutomator.setKey(config.key)
            
            // Import MIDI
            if let midiFile = config.midiFile {
                await updateStep("Importing MIDI file...", progress: 0.8)
                try await logicAutomator.importMIDI(midiFile)
            }
            
            // Start playback
            await updateStep("Starting playback...", progress: 0.9)
            try await logicAutomator.startPlayback()
            
            await updateStep("Project created successfully!", progress: 1.0)
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
    
    /// Quick create dance project (simplified interface)
    /// - Parameters:
    ///   - name: Project name
    ///   - tempo: Tempo (BPM)
    ///   - key: Key signature
    ///   - midiFile: MIDI file path (optional)
    func createDanceProject(name: String, tempo: Int = 124, key: String = "A minor", midiFile: String? = nil) async {
        let config = ProjectConfig(name: name, tempo: tempo, key: key, midiFile: midiFile)
        await createDanceProject(config: config)
    }
    
    // MARK: - Project Template Management
    
    /// Create project from template
    private func createProjectFromTemplate(config: ProjectConfig) async throws -> String {
        let templatePath = getTemplatePath()
        
        // Validate template path
        guard FileManager.default.fileExists(atPath: templatePath) else {
            throw LogicError.projectCreationFailed("Template not found: \(templatePath)")
        }
        
        // Create output directory
        let outputDir = config.outputDirectory
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        // Check if output directory is writable
        guard FileManager.default.isWritableFile(atPath: outputDir) else {
            throw LogicError.projectCreationFailed("Output directory not writable: \(outputDir)")
        }
        
        // Copy template to new project location
        let newProjectPath = "\(outputDir)/\(config.name).logicx"
        
        // If project already exists, delete it
        if FileManager.default.fileExists(atPath: newProjectPath) {
            try FileManager.default.removeItem(atPath: newProjectPath)
        }
        
        // Copy template
        try FileManager.default.copyItem(atPath: templatePath, toPath: newProjectPath)
        
        return newProjectPath
    }
    
    /// Get template path
    private func getTemplatePath() -> String {
        // First try to get template from Bundle
        if let bundlePath = Bundle.main.path(forResource: "dance_template", ofType: "logicx") {
            return bundlePath
        }
        
        // If not in Bundle, try to get from parent directory's templates folder
        let projectRoot = getProjectRoot()
        let templatePath = "\(projectRoot)/templates/dance_template.logicx"
        
        // Check if template exists
        if FileManager.default.fileExists(atPath: templatePath) {
            return templatePath
        }
        
        // If still not found, try the python resources templates folder
        let pythonTemplatePath = "\(projectRoot)/python resources/templates/dance_template.logicx"
        if FileManager.default.fileExists(atPath: pythonTemplatePath) {
            return pythonTemplatePath
        }
        
        // Last resort: try current directory
        let currentTemplatePath = "templates/dance_template.logicx"
        if FileManager.default.fileExists(atPath: currentTemplatePath) {
            return currentTemplatePath
        }
        
        return templatePath // Return the expected path even if not found
    }
    
    /// Get project root directory
    private func getProjectRoot() -> String {
        // Get parent directory of current working directory
        let currentPath = FileManager.default.currentDirectoryPath
        
        // If currently in LogicAutomatorSwift directory, return parent directory
        if currentPath.hasSuffix("LogicAutomatorSwift") {
            return currentPath.replacingOccurrences(of: "/LogicAutomatorSwift", with: "")
        }
        
        return currentPath
    }
    
    /// Get default output directory
    private static func getDefaultOutputDirectory() -> String {
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let projectsPath = "\(desktopPath.path)/LogicAutomator/Projects"
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: projectsPath, withIntermediateDirectories: true)
        
        return projectsPath
    }
    
    // MARK: - Status Updates
    
    /// Update current step and progress
    private func updateStep(_ step: String, progress: Double) async {
        print("step is: \(step)")
        await MainActor.run {
            currentStep = step
            self.progress = progress
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if Logic Pro is running
    var isLogicProRunning: Bool {
        logicAutomator.isConnected
    }
    
    /// Get current status
    var currentStatus: String {
        logicAutomator.currentStatus
    }
    
    /// Check permissions
    var hasPermissions: Bool {
        logicAutomator.checkAccessibilityPermissions()
    }
    
    // MARK: - Preset Configurations
    
    /// Preset dance project configurations
    struct PresetConfigs {
        static let house = ProjectConfig(name: "House Dance", tempo: 128, key: "A minor")
        static let techno = ProjectConfig(name: "Techno Track", tempo: 130, key: "D minor")
        static let trance = ProjectConfig(name: "Trance Journey", tempo: 138, key: "E major")
        static let dubstep = ProjectConfig(name: "Dubstep Drop", tempo: 140, key: "F minor")
        static let edm = ProjectConfig(name: "EDM Banger", tempo: 128, key: "C major")
    }
    
    /// Create project using preset
    func createPresetProject(_ preset: ProjectConfig) async {
        await createDanceProject(config: preset)
    }
    
    // MARK: - Batch Operations
    
    /// Create multiple projects
    func createMultipleProjects(_ configs: [ProjectConfig]) async {
        for (index, config) in configs.enumerated() {
            await updateStep("Creating project \(index + 1) of \(configs.count): \(config.name)", progress: Double(index) / Double(configs.count))
            await createDanceProject(config: config)
            
            // Pause between projects
            if index < configs.count - 1 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// Clear error
    func clearError() {
        lastError = nil
    }
    
    /// Retry last operation
    func retryLastOperation() async {
        // This can implement retry logic
        // Need to save last operation configuration
    }
    
    // MARK: - Track Testing
    
    /// Test new track creation
    func testNewTrack() async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
        }
        
        do {
            // Check permissions
            await updateStep("Checking permissions...", progress: 0.1)
            guard logicAutomator.checkAccessibilityPermissions() else {
                throw LogicError.accessibilityNotEnabled
            }
            
            // Launch Logic Pro
            await updateStep("Launching Logic Pro...", progress: 0.2)
            try await logicAutomator.launchLogicPro()
            
            // Create a simple project first
            await updateStep("Creating test project...", progress: 0.3)
            let config = ProjectConfig(name: "Track Test", tempo: 120, key: "C major")
            let projectPath = try await createProjectFromTemplate(config: config)
            
            // Open project
            await updateStep("Opening test project...", progress: 0.5)
            try await logicAutomator.openProject(projectPath)
            
            // Create new track
            await updateStep("Creating new track...", progress: 0.7)
            try await logicAutomator.newTrack()
            
            // Create specific track type
            await updateStep("Creating Software Instrument track...", progress: 0.8)
            try await logicAutomator.newTrack(type: "Software Instrument")
            
            await updateStep("Track creation test completed!", progress: 1.0)
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
    
    /// Test MIDI import functionality
    func testMidiImport(midiFilePath: String) async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
        }
        
        do {
            // Check permissions
            await updateStep("Checking permissions...", progress: 0.1)
            guard logicAutomator.checkAccessibilityPermissions() else {
                throw LogicError.accessibilityNotEnabled
            }
            
            // Launch Logic Pro
            await updateStep("Launching Logic Pro...", progress: 0.2)
            try await logicAutomator.launchLogicPro()
            
            // Create a simple project first
            await updateStep("Creating test project...", progress: 0.3)
            let config = ProjectConfig(name: "MIDI Test", tempo: 120, key: "C major")
            let projectPath = try await createProjectFromTemplate(config: config)
            
            // Open project
            await updateStep("Opening test project...", progress: 0.5)
            try await logicAutomator.openProject(projectPath)
            
            // Import MIDI file
            await updateStep("Importing MIDI file...", progress: 0.7)
            try await logicAutomator.importMIDI(midiFilePath)
            
            await updateStep("MIDI import test completed!", progress: 1.0)
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
    
    /// Test region replacement functionality
    func testRegionReplacement(bar: Int, audioFilePath: String, trackName: String? = nil, trackIndex: Int? = nil) async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
        }
        
        do {
            // Check permissions
            await updateStep("Checking permissions...", progress: 0.1)
            guard logicAutomator.checkAccessibilityPermissions() else {
                throw LogicError.accessibilityNotEnabled
            }
            
            // Launch Logic Pro
            await updateStep("Launching Logic Pro...", progress: 0.2)
            try await logicAutomator.launchLogicPro()
            
            // Create a simple project first
            await updateStep("Creating test project...", progress: 0.3)
            //let config = ProjectConfig(name: "Region Test", tempo: 120, key: "C major")
            //let projectPath = try await createProjectFromTemplate(config: config)
            
            // Open project
            await updateStep("Opening test project...", progress: 0.4)
            //try await logicAutomator.openProject(projectPath)
            
            // Just navigate to the specific bar
            await updateStep("Navigating to bar \(bar)...", progress: 0.6)
            try await logicAutomator.navigateToBar(bar)
            
            // Select track if specified
            if let trackIndex = trackIndex {
                await updateStep("Selecting track index \(trackIndex)...", progress: 0.7)
            //    try await logicAutomator.selectTrackByIndex(trackIndex)
            } else if let trackName = trackName {
                await updateStep("Selecting track '\(trackName)'...", progress: 0.7)
            //    try await logicAutomator.selectTrackByName(trackName)
            }
            
            await updateStep("Region replacement test completed!", progress: 1.0)
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
    
    /// Process natural language commands
    func processCommand(_ command: String) async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
            currentStep = "Processing command..."
        }
        
        do {
            let lowerCommand = command.lowercased()
            
            try await createDanceProject(name: "test")
            
            // Parse "Replace region at bar X with file Y"
            if lowerCommand.contains("replace") && lowerCommand.contains("bar") && lowerCommand.contains("file") {
                await updateStep("Parsing replace command...", progress: 0.2)
                
                // Extract bar number
                let barPattern = #"bar\s+(\d+)"#
                let barRegex = try NSRegularExpression(pattern: barPattern, options: .caseInsensitive)
                let barMatches = barRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
                
                guard let barMatch = barMatches.first,
                      let barRange = Range(barMatch.range(at: 1), in: command) else {
                    throw LogicError.menuOperationFailed("Could not parse bar number from command")
                }
                
                let barNumber = Int(command[barRange]) ?? 33
                
                // Extract file path (simplified - just use the last word as filename)
                let words = command.components(separatedBy: .whitespaces)
                let fileName = words.last ?? "test.midi"
                
                await updateStep("Executing replace command at bar \(barNumber)...", progress: 0.5)
                
                // Execute the command
                try await logicAutomator.navigateToBar(barNumber)
                
                await updateStep("Command executed successfully!", progress: 1.0)
                
            } else if lowerCommand.contains("navigate") || lowerCommand.contains("go to") {
                // Parse "Navigate to bar X" or "Go to bar X"
                await updateStep("Parsing navigation command...", progress: 0.2)
                
                let barPattern = #"bar\s+(\d+)"#
                let barRegex = try NSRegularExpression(pattern: barPattern, options: .caseInsensitive)
                let barMatches = barRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
                
                guard let barMatch = barMatches.first,
                      let barRange = Range(barMatch.range(at: 1), in: command) else {
                    throw LogicError.menuOperationFailed("Could not parse bar number from command")
                }
                
                let barNumber = Int(command[barRange]) ?? 33
                
                await updateStep("Navigating to bar \(barNumber)...", progress: 0.5)
                try await logicAutomator.navigateToBar(barNumber)
                
                await updateStep("Navigation completed!", progress: 1.0)
                
            } else if lowerCommand.contains("select") && lowerCommand.contains("track") {
                // Parse "Select track X" or "Select track by name Y"
                await updateStep("Parsing track selection command...", progress: 0.2)
                
                if lowerCommand.contains("index") || lowerCommand.contains("number") {
                    // Select by index
                    let indexPattern = #"(\d+)"#
                    let indexRegex = try NSRegularExpression(pattern: indexPattern, options: [])
                    let indexMatches = indexRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
                    
                    guard let indexMatch = indexMatches.first,
                          let indexRange = Range(indexMatch.range(at: 1), in: command) else {
                        throw LogicError.menuOperationFailed("Could not parse track index from command")
                    }
                    
                    let trackIndex = Int(command[indexRange]) ?? 61
                    
                    await updateStep("Selecting track index \(trackIndex)...", progress: 0.5)
                    try await logicAutomator.selectTrackByIndex(trackIndex)
                    
                    await updateStep("Track selection completed!", progress: 1.0)
                    
                } else {
                    // Select by name (simplified - just use the last word as track name)
                    let words = command.components(separatedBy: .whitespaces)
                    let trackName = words.last ?? "Bass"
                    
                    await updateStep("Selecting track '\(trackName)'...", progress: 0.5)
                    try await logicAutomator.selectTrackByName(trackName)
                    
                    await updateStep("Track selection completed!", progress: 1.0)
                }
                
            } else {
                throw LogicError.menuOperationFailed("Unknown command: \(command)")
            }
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
}

// MARK: - Extension: Project Configuration Convenience Methods
extension DanceGoAutomator.ProjectConfig {
    /// Create custom configuration
    static func custom(name: String, tempo: Int, key: String, midiFile: String? = nil) -> DanceGoAutomator.ProjectConfig {
        return DanceGoAutomator.ProjectConfig(name: name, tempo: tempo, key: key, midiFile: midiFile)
    }
    
    /// Validate configuration
    func validate() -> [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Project name cannot be empty")
        }
        
        if tempo < 60 || tempo > 200 {
            errors.append("Tempo must be between 60 and 200 BPM")
        }
        
        if let midiFile = midiFile, !FileManager.default.fileExists(atPath: midiFile) {
            errors.append("MIDI file not found: \(midiFile)")
        }
        
        return errors
    }
}
