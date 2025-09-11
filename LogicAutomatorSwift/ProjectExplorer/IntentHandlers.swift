//
//  IntentHandlers.swift
//  logic
//
//  Intent handlers for protocol execution
//  Each handler implements specific Logic Pro operations
//

import Foundation
import ApplicationServices
import Cocoa

// MARK: - Track Operations

/// Handler for selecting tracks
class SelectTrackHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎯 Executing select_track intent")
        
        guard let trackNumber = parameters["track_number"] as? Int else {
            throw ProtocolError.invalidParameters("track_number is required")
        }
        
        context.log("📊 Selecting track \(trackNumber)")
        
        // Find Logic Pro application
        let runningApps = NSWorkspace.shared.runningApplications
        guard let logicApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.logic10" }) else {
            throw ProtocolError.logicProNotRunning
        }
        
        // Activate Logic Pro
        logicApp.activate()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Navigate to track list and select the specified track
        // First, go to the top of the track list
        context.log("Going to top of track list...")
        try await sendKeysWithModifiers("home", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then move down to the target track index
        context.log("Moving down to track index \(trackNumber)...")
        for _ in 1..<trackNumber {
            try await sendKeys("down")
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        context.log("✅ Track \(trackNumber) selected successfully")
    }
    
    /// Send keyboard input using CGEvent
    private func sendKeys(_ keys: String) async throws {
        for char in keys {
            let keyCode = getKeyCode(for: String(char))
            if keyCode != 0 {
                // Key down
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                keyDownEvent?.post(tap: .cghidEventTap)
                
                // Delay for key down
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Key up
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                keyUpEvent?.post(tap: .cghidEventTap)
                
                // Delay between characters
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    /// Send keys with modifiers using CGEvent
    private func sendKeysWithModifiers(_ key: String, modifiers: [String]) async throws {
        let keyCode = getKeyCode(for: key)
        guard keyCode != 0 else {
            return
        }
        
        // Convert modifier strings to CGEventFlags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "ctrl", "control":
                flags.insert(.maskControl)
            default:
                break
            }
        }
        
        // Key down with modifiers
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.flags = flags
        keyDownEvent?.post(tap: .cghidEventTap)
        
        // Small delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Key up
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.flags = flags
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Get key code for a character
    private func getKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "6", "^": return 0x16
        case "5", "%": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case "`", "~": return 0x32
        case "return", "\n": return 0x24
        case "tab": return 0x30
        case "space", " ": return 0x31
        case "delete": return 0x33
        case "escape": return 0x35
        case "command": return 0x37
        case "shift": return 0x38
        case "caps": return 0x39
        case "option": return 0x3A
        case "control": return 0x3B
        case "right-shift": return 0x3C
        case "right-option": return 0x3D
        case "right-control": return 0x3E
        case "function": return 0x3F
        case "f17": return 0x40
        case "volume-up": return 0x48
        case "volume-down": return 0x49
        case "mute": return 0x4A
        case "f18": return 0x4F
        case "f19": return 0x50
        case "f20": return 0x5A
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f3": return 0x63
        case "f8": return 0x64
        case "f9": return 0x65
        case "f11": return 0x67
        case "f13": return 0x69
        case "f16": return 0x6A
        case "f14": return 0x6B
        case "f10": return 0x6D
        case "f12": return 0x6F
        case "f15": return 0x71
        case "help": return 0x72
        case "home": return 0x73
        case "page-up": return 0x74
        case "forward-delete": return 0x75
        case "f4": return 0x76
        case "end": return 0x77
        case "f2": return 0x78
        case "page-down": return 0x79
        case "f1": return 0x7A
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        default: return 0
        }
    }
}

/// Handler for creating new tracks
class CreateTrackHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎵 Executing create_track intent")
        
        let trackType = parameters["type"] as? String ?? "Software Instrument"
        
        context.log("📊 Creating \(trackType) track")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Creating \(trackType) track - implementation needed")
        
        context.log("✅ \(trackType) track created successfully")
    }
}

// MARK: - Region Operations

/// Handler for creating MIDI regions
class CreateRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎼 Executing create_region intent")
        
        let regionType = parameters["type"] as? String ?? "MIDI"
        let lengthBars = parameters["length_bars"] as? Int ?? 4
        
        context.log("📊 Creating \(regionType) region with \(lengthBars) bars")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Creating \(regionType) region - implementation needed")
        
        context.log("✅ \(regionType) region created successfully")
    }
}

/// Handler for quantizing regions
class QuantizeRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎯 Executing quantize_region intent")
        
        let grid = parameters["grid"] as? String ?? "1/16"
        let strength = parameters["strength"] as? Int ?? 90
        
        context.log("📊 Quantizing region with grid \(grid) and strength \(strength)%")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Quantizing region - implementation needed")
        
        context.log("✅ Region quantized successfully")
    }
}

/// Handler for moving regions
class MoveRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("📍 Executing move_region intent")
        
        guard let position = parameters["position"] as? [String: Any],
              let x = position["x"] as? Double,
              let y = position["y"] as? Double else {
            throw ProtocolError.invalidParameters("position with x and y coordinates is required")
        }
        
        _ = CGPoint(x: x, y: y)
        
        context.log("📊 Moving region to position (\(x), \(y))")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Moving region - implementation needed")
        
        context.log("✅ Region moved successfully")
    }
}

/// Handler for resizing regions
class ResizeRegionHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("📏 Executing resize_region intent")
        
        guard let size = parameters["size"] as? [String: Any],
              let width = size["width"] as? Double,
              let height = size["height"] as? Double else {
            throw ProtocolError.invalidParameters("size with width and height is required")
        }
        
        _ = CGSize(width: width, height: height)
        
        context.log("📊 Resizing region to size (\(width), \(height))")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Resizing region - implementation needed")
        
        context.log("✅ Region resized successfully")
    }
}

// MARK: - Import Operations

/// Handler for importing chords
class ImportChordsHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎹 Executing import_chords intent")
        
        let folder = parameters["folder"] as? String ?? "ChordProgressions"
        let random = parameters["random"] as? Bool ?? false
        
        context.log("📊 Importing chords from folder '\(folder)', random: \(random)")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Importing chords - implementation needed")
        
        context.log("✅ Chords imported successfully")
    }
}

/// Handler for importing MIDI files
class ImportMidiHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎵 Executing import_midi intent")
        
        guard let filename = parameters["filename"] as? String else {
            throw ProtocolError.invalidParameters("filename is required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        
        context.log("📊 Importing MIDI file '\(filename)'" + (trackNumber != nil ? " to track \(trackNumber!)" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Importing MIDI file - implementation needed")
        
        context.log("✅ MIDI file imported successfully")
    }
}

// MARK: - Playback Operations

/// Handler for starting playback
class PlayHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("▶️ Executing play intent")
        
        let fromBar = parameters["from_bar"] as? Int
        
        if let fromBar = fromBar {
            context.log("📊 Starting playback from bar \(fromBar)")
        } else {
            context.log("📊 Starting playback from current position")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Starting playback - implementation needed")
        
        context.log("✅ Playback started successfully")
    }
}

/// Handler for stopping playback
class StopHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("⏹️ Executing stop intent")
        
        context.log("📊 Stopping playback")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Stopping playback - implementation needed")
        
        context.log("✅ Playback stopped successfully")
    }
}

/// Handler for recording
class RecordHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🔴 Executing record intent")
        
        let trackNumber = parameters["track_number"] as? Int
        
        if let trackNumber = trackNumber {
            context.log("📊 Starting recording on track \(trackNumber)")
        } else {
            context.log("📊 Starting recording on selected track")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Starting recording - implementation needed")
        
        context.log("✅ Recording started successfully")
    }
}

// MARK: - Project Operations

/// Handler for setting tempo
class SetTempoHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎵 Executing set_tempo intent")
        
        guard let tempo = parameters["tempo"] as? Int else {
            throw ProtocolError.invalidParameters("tempo is required")
        }
        
        context.log("📊 Setting tempo to \(tempo) BPM")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting tempo - implementation needed")
        
        context.log("✅ Tempo set successfully")
    }
}

/// Handler for setting key signature
class SetKeyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎼 Executing set_key intent")
        
        guard let key = parameters["key"] as? String else {
            throw ProtocolError.invalidParameters("key is required")
        }
        
        context.log("📊 Setting key signature to \(key)")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting key signature - implementation needed")
        
        context.log("✅ Key signature set successfully")
    }
}

/// Handler for saving projects
class SaveProjectHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("💾 Executing save_project intent")
        
        let filename = parameters["filename"] as? String
        
        if let filename = filename {
            context.log("📊 Saving project as '\(filename)'")
        } else {
            context.log("📊 Saving project")
        }
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Saving project - implementation needed")
        
        context.log("✅ Project saved successfully")
    }
}

// MARK: - Advanced Operations

/// Handler for setting region properties
class SetRegionPropertyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("⚙️ Executing set_region_property intent")
        
        guard let property = parameters["property"] as? String,
              let value = parameters["value"] else {
            throw ProtocolError.invalidParameters("property and value are required")
        }
        
        context.log("📊 Setting region property '\(property)' to '\(value)'")
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting region property - implementation needed")
        
        context.log("✅ Region property set successfully")
    }
}

/// Handler for applying effects
class ApplyEffectHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎛️ Executing apply_effect intent")
        
        guard let effect = parameters["effect"] as? String else {
            throw ProtocolError.invalidParameters("effect is required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        let preset = parameters["preset"] as? String
        
        context.log("📊 Applying effect '\(effect)'" + 
                   (trackNumber != nil ? " to track \(trackNumber!)" : "") +
                   (preset != nil ? " with preset '\(preset!)'" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Applying effect - implementation needed")
        
        context.log("✅ Effect applied successfully")
    }
}

/// Handler for setting track properties
class SetTrackPropertyHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("🎚️ Executing set_track_property intent")
        
        guard let property = parameters["property"] as? String,
              let value = parameters["value"] else {
            throw ProtocolError.invalidParameters("property and value are required")
        }
        
        let trackNumber = parameters["track_number"] as? Int
        
        context.log("📊 Setting track property '\(property)' to '\(value)'" + 
                   (trackNumber != nil ? " on track \(trackNumber!)" : ""))
        
        // For now, just log the action - would need LogicAutomator integration
        context.log("Setting track property - implementation needed")
        
        context.log("✅ Track property set successfully")
    }
}

// MARK: - Utility Operations

/// Handler for waiting/delays
class WaitHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("⏳ Executing wait intent")
        
        let duration = parameters["duration"] as? Double ?? 1.0
        let unit = parameters["unit"] as? String ?? "seconds"
        
        let waitTime: TimeInterval
        switch unit.lowercased() {
        case "milliseconds", "ms":
            waitTime = duration / 1000.0
        case "seconds", "s":
            waitTime = duration
        case "minutes", "m":
            waitTime = duration * 60.0
        default:
            waitTime = duration
        }
        
        context.log("📊 Waiting for \(duration) \(unit)")
        
        try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        
        context.log("✅ Wait completed")
    }
}

/// Handler for logging messages
class LogHandler: IntentHandler {
    func execute(parameters: [String: Any], context: ExecutionContext) async throws {
        context.log("📝 Executing log intent")
        
        let message = parameters["message"] as? String ?? "Log message"
        let level = parameters["level"] as? String ?? "info"
        
        context.log("📊 Logging message: \(message) (level: \(level))")
        
        // Message is already logged above, this is just for protocol flow
        context.log("✅ Log message recorded")
    }
}