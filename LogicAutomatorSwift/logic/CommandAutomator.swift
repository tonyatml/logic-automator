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
            
            // Activate Logic Pro to ensure it's in front
            await updateStep("Activating Logic Pro...", progress: 0.25)
            try await logicAutomator.activateLogic()
            
            // Parse and execute commands
            await updateStep("Parsing command...", progress: 0.3)
            
            if lowerCommand.contains("navigate") || lowerCommand.contains("go to") || lowerCommand.contains("goto") {
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
            
            // Delay to let user see completion status
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
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
    
    // MARK: - Command Handlers
    
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
    private func showHelp() async {
        await updateStep("Showing help...", progress: 0.5)
        
        let helpText = """
        Available Commands:
        
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
        
        await appendToLog(helpText)
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
}
