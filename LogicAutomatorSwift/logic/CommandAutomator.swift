import Foundation
import SwiftUI

/// Generic command automation class
/// Provides high-level command processing and Logic Pro automation functionality
class CommandAutomator: ObservableObject {
    private let logicAutomator = LogicAutomator()
    
    init() {
        // Set up logging callback
        logicAutomator.logCallback = { [weak self] message in
            Task { @MainActor in
                await self?.appendToLog(message)
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var isWorking = false
    @Published var currentStep = ""
    @Published var progress: Double = 0.0
    @Published var lastError: String?
    @Published var outputLog: String = ""
    
    // MARK: - Status Properties
    
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
    
    // MARK: - Command Processing
    
    /// Process natural language commands
    /// - Parameter command: The command string to process
    func processCommand(_ command: String) async {
        await MainActor.run {
            isWorking = true
            progress = 0.0
            lastError = nil
            currentStep = "Processing command..."
        }
        
        // Add command to log
        await appendToLog("🔄 Processing command: \(command)")
        
        do {
            let lowerCommand = command.lowercased()
            
            // Check permissions first
            await updateStep("Checking permissions...", progress: 0.1)
            guard logicAutomator.checkAccessibilityPermissions() else {
                throw LogicError.accessibilityNotEnabled
            }
            
            // Launch Logic Pro if not running
            if !logicAutomator.isConnected {
                await updateStep("Launching Logic Pro...", progress: 0.2)
                try await logicAutomator.launchLogicPro()
            }
            
            // Note: Individual command handlers will activate Logic Pro as needed
            // This prevents duplicate activation calls
            
            // Parse and execute commands
            await updateStep("Parsing command...", progress: 0.3)
            
            if lowerCommand.contains("open") {
                try await handleOpenCommand(command)
            } else if lowerCommand.contains("create") {
                try await handleCreateCommand(command)
            } else if lowerCommand.contains("navigate") || lowerCommand.contains("go to") || lowerCommand.contains("goto") {
                try await handleNavigationCommand(command)
            } else if lowerCommand.contains("select") && lowerCommand.contains("track") {
                try await handleTrackSelectionCommand(command)
            } else if lowerCommand.contains("replace") && lowerCommand.contains("region") {
                try await handleRegionReplacementCommand(command)
            } else if lowerCommand.contains("import") && lowerCommand.contains("midi") {
                try await handleMidiImportCommand(command)
            } else if lowerCommand.contains("new") && lowerCommand.contains("track") {
                try await handleNewTrackCommand(command)
            } else if lowerCommand.contains("set") && lowerCommand.contains("tempo") {
                try await handleTempoCommand(command)
            } else if lowerCommand.contains("set") && lowerCommand.contains("key") {
                try await handleKeyCommand(command)
            } else if lowerCommand.contains("play") || lowerCommand.contains("start") {
                try await handlePlaybackCommand(command)
            } else if lowerCommand.contains("stop") || lowerCommand.contains("pause") {
                try await handleStopCommand(command)
            } else if lowerCommand.contains("help") || lowerCommand.contains("commands") {
                await showHelp()
            } else {
                throw LogicError.menuOperationFailed("Unknown command: \(command)")
            }
            
            await updateStep("Command executed successfully!", progress: 1.0)
            
            // Add success message to log
            await appendToLog("✅ Command executed successfully: \(command)")
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                currentStep = "Error: \(error.localizedDescription)"
            }
            
            // Add error to log
            await appendToLog("❌ Error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isWorking = false
        }
    }
    
    // MARK: - Command Handlers
    
    /// Handle open command (launch Logic Pro)
    private func handleOpenCommand(_ command: String) async throws {
        await updateStep("Executing open command...", progress: 0.5)
        
        if !logicAutomator.isConnected {
            await updateStep("Launching Logic Pro...", progress: 0.7)
            try await logicAutomator.launchLogicPro()
            await updateStep("Logic Pro launched successfully!", progress: 1.0)
        } else {
            await updateStep("Logic Pro is already running, activating...", progress: 0.7)
            try await logicAutomator.activateLogic()
            await updateStep("Logic Pro activated!", progress: 1.0)
        }
    }
    
    /// Handle create project command (create [name])
    private func handleCreateCommand(_ command: String) async throws {
        await updateStep("Executing create project command...", progress: 0.5)
        
        // Extract project name from command
        let projectName = extractProjectName(from: command)
        
        await updateStep("Creating project: \(projectName)...", progress: 0.6)
        
        // Create project configuration
        let config = ProjectConfig(name: projectName)
        
        // Create project from template
        let projectPath = try await createProjectFromTemplate(config: config)
        
        await updateStep("Opening project in Logic Pro...", progress: 0.8)
        try await logicAutomator.openProject(projectPath)
        
        await updateStep("Project '\(projectName)' created and opened successfully!", progress: 1.0)
    }
    
    /// Handle navigation commands (go to bar X)
    private func handleNavigationCommand(_ command: String) async throws {
        await updateStep("Executing navigation command...", progress: 0.5)
        
        let barPattern = #"bar\s+(\d+)"#
        let barRegex = try NSRegularExpression(pattern: barPattern, options: .caseInsensitive)
        let barMatches = barRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
        
        guard let barMatch = barMatches.first,
              let barRange = Range(barMatch.range(at: 1), in: command) else {
            throw LogicError.menuOperationFailed("Could not parse bar number from command")
        }
        
        let barNumber = Int(command[barRange]) ?? 1
        
        await updateStep("Navigating to bar \(barNumber)...", progress: 0.7)
        try await logicAutomator.navigateToBar(barNumber)
    }
    
    /// Handle track selection commands
    private func handleTrackSelectionCommand(_ command: String) async throws {
        await updateStep("Executing track selection command...", progress: 0.5)
        
        if command.lowercased().contains("index") || command.lowercased().contains("number") {
            // Select by index
            let indexPattern = #"(\d+)"#
            let indexRegex = try NSRegularExpression(pattern: indexPattern, options: [])
            let indexMatches = indexRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
            
            guard let indexMatch = indexMatches.first,
                  let indexRange = Range(indexMatch.range(at: 1), in: command) else {
                throw LogicError.menuOperationFailed("Could not parse track index from command")
            }
            
            let trackIndex = Int(command[indexRange]) ?? 1
            
            await updateStep("Selecting track index \(trackIndex)...", progress: 0.7)
            try await logicAutomator.selectTrackByIndex(trackIndex)
            
        } else {
            // Select by name
            let words = command.components(separatedBy: .whitespaces)
            let trackName = words.last ?? "Track 1"
            
            await updateStep("Selecting track '\(trackName)'...", progress: 0.7)
            try await logicAutomator.selectTrackByName(trackName)
        }
    }
    
    /// Handle region replacement commands
    private func handleRegionReplacementCommand(_ command: String) async throws {
        await updateStep("Executing region replacement command...", progress: 0.5)
        
        // Extract bar number
        let barPattern = #"bar\s+(\d+)"#
        let barRegex = try NSRegularExpression(pattern: barPattern, options: .caseInsensitive)
        let barMatches = barRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
        
        guard let barMatch = barMatches.first,
              let barRange = Range(barMatch.range(at: 1), in: command) else {
            throw LogicError.menuOperationFailed("Could not parse bar number from command")
        }
        
        let barNumber = Int(command[barRange]) ?? 1
        
        // Extract file path (simplified - just use the last word as filename)
        let words = command.components(separatedBy: .whitespaces)
        let fileName = words.last ?? "region.midi"
        
        await updateStep("Replacing region at bar \(barNumber) with \(fileName)...", progress: 0.7)
        try await logicAutomator.navigateToBar(barNumber)
        // TODO: Implement actual region replacement
    }
    
    /// Handle MIDI import commands
    private func handleMidiImportCommand(_ command: String) async throws {
        await updateStep("Executing MIDI import command...", progress: 0.5)
        
        let words = command.components(separatedBy: .whitespaces)
        let fileName = words.last ?? "import.midi"
        
        await updateStep("Importing MIDI file: \(fileName)...", progress: 0.7)
        try await logicAutomator.importMIDI(fileName)
    }
    
    /// Handle new track commands
    private func handleNewTrackCommand(_ command: String) async throws {
        await updateStep("Executing new track command...", progress: 0.5)
        
        let trackType = extractTrackType(from: command)
        
        await updateStep("Creating new \(trackType) track...", progress: 0.7)
        try await logicAutomator.newTrack(type: trackType)
    }
    
    /// Handle tempo commands
    private func handleTempoCommand(_ command: String) async throws {
        await updateStep("Executing tempo command...", progress: 0.5)
        
        let tempoPattern = #"(\d+)"#
        let tempoRegex = try NSRegularExpression(pattern: tempoPattern, options: [])
        let tempoMatches = tempoRegex.matches(in: command, options: [], range: NSRange(command.startIndex..., in: command))
        
        guard let tempoMatch = tempoMatches.first,
              let tempoRange = Range(tempoMatch.range(at: 1), in: command) else {
            throw LogicError.menuOperationFailed("Could not parse tempo from command")
        }
        
        let tempo = Int(command[tempoRange]) ?? 120
        
        await updateStep("Setting tempo to \(tempo) BPM...", progress: 0.7)
        try await logicAutomator.setTempo(tempo)
    }
    
    /// Handle key commands
    private func handleKeyCommand(_ command: String) async throws {
        await updateStep("Executing key command...", progress: 0.5)
        
        let key = extractKey(from: command)
        
        await updateStep("Setting key to \(key)...", progress: 0.7)
        try await logicAutomator.setKey(key)
    }
    
    /// Handle playback commands
    private func handlePlaybackCommand(_ command: String) async throws {
        await updateStep("Executing playback command...", progress: 0.5)
        
        await updateStep("Starting playback...", progress: 0.7)
        try await logicAutomator.startPlayback()
    }
    
    /// Handle stop commands
    private func handleStopCommand(_ command: String) async throws {
        await updateStep("Executing stop command...", progress: 0.5)
        
        await updateStep("Stopping playback...", progress: 0.7)
        try await logicAutomator.stopPlayback()
    }
    
    /// Show help information
    func showHelp() {
        
        let helpText = """
        Available Commands:
        
        Application Control:
        - "open" (launch/activate Logic Pro)
        - "create PROJECT_NAME" (create new project)
        
        Navigation:
        - "go to bar X" or "navigate to bar X"
        
        Track Management:
        - "select track X" (by index)
        - "select track NAME" (by name)
        - "new track" or "new track TYPE"
        
        Playback:
        - "play" or "start"
        - "stop" or "pause"
        
        Project Settings:
        - "set tempo X" (X = BPM)
        - "set key X" (X = key signature)
        
        File Operations:
        - "import midi FILENAME"
        - "replace region at bar X with FILENAME"
        
        Other:
        - "help" or "commands"
        """
        
        let alert = NSAlert()
        alert.messageText = "Logic Maestro Commands"
        alert.informativeText = helpText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
    }
    
    // MARK: - Utility Methods
    
    /// Extract track type from command
    private func extractTrackType(from command: String) -> String {
        let lowerCommand = command.lowercased()
        
        if lowerCommand.contains("software instrument") || lowerCommand.contains("instrument") {
            return "Software Instrument"
        } else if lowerCommand.contains("audio") {
            return "Audio"
        } else if lowerCommand.contains("drum") {
            return "Drum Machine"
        } else if lowerCommand.contains("external") {
            return "External MIDI"
        } else {
            return "Software Instrument" // Default
        }
    }
    
    /// Extract key from command
    private func extractKey(from command: String) -> String {
        let lowerCommand = command.lowercased()
        
        // Common keys
        let keys = ["c major", "c minor", "g major", "g minor", "d major", "d minor", 
                   "a major", "a minor", "e major", "e minor", "b major", "b minor",
                   "f major", "f minor", "bb major", "bb minor", "eb major", "eb minor"]
        
        for key in keys {
            if lowerCommand.contains(key) {
                return key.capitalized
            }
        }
        
        return "C Major" // Default
    }
    
    /// Update current step and progress
    private func updateStep(_ step: String, progress: Double) async {
        await appendToLog("Step: \(step)")
        await MainActor.run {
            currentStep = step
            self.progress = progress
        }
    }
    
    /// Append message to output log
    private func appendToLog(_ message: String) async {
        await MainActor.run {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timestamp = formatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(message)\n"
            outputLog += logEntry
        }
    }
    
    /// Clear output log
    func clearLog() {
        outputLog = ""
    }
    
    /// Clear error
    func clearError() {
        lastError = nil
    }
    
    // MARK: - Project Configuration
    
    /// Project configuration structure
    struct ProjectConfig {
        let name: String
        let tempo: Int
        let key: String
        let midiFile: String?
        let outputDirectory: String
        
        init(name: String, tempo: Int = 120, key: String = "C Major", midiFile: String? = nil, outputDirectory: String? = nil) {
            self.name = name
            self.tempo = tempo
            self.key = key
            self.midiFile = midiFile
            self.outputDirectory = outputDirectory ?? getDefaultOutputDirectory()
        }
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
    
    // MARK: - Utility Methods
    
    /// Extract project name from command
    private func extractProjectName(from command: String) -> String {
        let words = command.components(separatedBy: .whitespaces)
        
        // Find the word after "create"
        if let createIndex = words.firstIndex(of: "create") {
            let nextIndex = createIndex + 1
            if nextIndex < words.count {
                return words[nextIndex]
            }
        }
        
        // If no name found, use default
        return "New Project"
    }
}
