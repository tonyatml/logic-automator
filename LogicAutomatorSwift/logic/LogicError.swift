import Foundation

/// Define possible errors during Logic Pro automation process
enum LogicError: Error, LocalizedError {
    case appNotRunning
    case timeout(String)
    case elementNotFound(String)
    case failedToGetWindows
    case accessibilityNotEnabled
    case invalidProjectPath(String)
    case projectCreationFailed(String)
    case midiImportFailed(String)
    case menuOperationFailed(String)
    case tempoSettingFailed(String)
    case keySettingFailed(String)
    case playbackFailed(String)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .appNotRunning:
            return "Logic Pro is not running"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .elementNotFound(let element):
            return "Element not found: \(element)"
        case .failedToGetWindows:
            return "Failed to get Logic Pro windows"
        case .accessibilityNotEnabled:
            return "Accessibility permissions not granted. Please enable in System Preferences > Security & Privacy > Privacy > Accessibility"
        case .invalidProjectPath(let path):
            return "Invalid project path: \(path)"
        case .projectCreationFailed(let reason):
            return "Project creation failed: \(reason)"
        case .midiImportFailed(let reason):
            return "MIDI import failed: \(reason)"
        case .menuOperationFailed(let reason):
            return "Menu operation failed: \(reason)"
        case .tempoSettingFailed(let reason):
            return "Tempo setting failed: \(reason)"
        case .keySettingFailed(let reason):
            return "Key setting failed: \(reason)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .permissionDenied:
            return "Permission denied. Please check accessibility and automation permissions"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .appNotRunning:
            return "Please start Logic Pro first"
        case .accessibilityNotEnabled:
            return "Go to System Preferences > Security & Privacy > Privacy > Accessibility and add this app"
        case .permissionDenied:
            return "Check System Preferences for both Accessibility and Automation permissions"
        default:
            return "Please try again or check the error details"
        }
    }
}
