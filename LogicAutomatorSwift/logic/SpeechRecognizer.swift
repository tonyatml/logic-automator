import Foundation
import Speech
import SwiftUI
import AVFoundation

/// Speech recognition manager for voice commands
class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var isAuthorized = false
    @Published var errorMessage = ""
    @Published var isFinalResult = false
    
    // Callback for when final result is received
    var onFinalResult: ((String) -> Void)?
    
    // Track the last sent text to avoid duplicates
    private var lastSentText = ""
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    /// Request microphone and speech recognition permissions
    private func requestAuthorization() {
        print("SpeechRecognizer: Checking initial authorization status...")
        
        // Just check the current status, don't request permissions yet
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        print("SpeechRecognizer: Initial microphone status: \(microphoneStatus.rawValue)")
        print("SpeechRecognizer: Initial speech recognition status: \(speechStatus.rawValue)")
        
        DispatchQueue.main.async {
            // Only set as authorized if both permissions are already granted
            if microphoneStatus == .authorized && speechStatus == .authorized {
                self.isAuthorized = true
                self.errorMessage = ""
                print("SpeechRecognizer: Both permissions already granted")
            } else {
                self.isAuthorized = false
                self.errorMessage = "Permissions will be requested when you start recording"
                print("SpeechRecognizer: Permissions not yet granted")
            }
        }
    }
    
    // MARK: - Recording Control
    
    /// Start recording and recognizing speech
    func startRecording() async {
        print("SpeechRecognizer: Starting recording...")
        
        // Create a fresh audio engine to avoid format mismatch issues
        audioEngine = AVAudioEngine()
        print("SpeechRecognizer: Created fresh audio engine")
        
        // Reset state for new recording session
        lastSentText = ""
        recognizedText = ""
        
        // Clear the text field immediately when starting new recording
        DispatchQueue.main.async {
            self.onFinalResult?("")
        }
        
        // Add a small delay to ensure audio engine is fully initialized
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        } catch {
            print("SpeechRecognizer: Error during sleep: \(error.localizedDescription)")
        }
        
        // Check microphone permission status
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("SpeechRecognizer: Microphone status: \(microphoneStatus.rawValue)")
        
        switch microphoneStatus {
        case .notDetermined:
            print("SpeechRecognizer: Requesting microphone permission...")
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone permission denied. Please enable in System Preferences > Security & Privacy > Microphone"
                }
                print("SpeechRecognizer: Microphone permission denied")
                return
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Microphone permission denied. Please enable in System Preferences > Security & Privacy > Microphone"
            }
            print("SpeechRecognizer: Microphone permission denied or restricted")
            return
            
        case .authorized:
            print("SpeechRecognizer: Microphone permission granted")
            
        @unknown default:
            DispatchQueue.main.async {
                self.errorMessage = "Unknown microphone permission status"
            }
            print("SpeechRecognizer: Unknown microphone permission status")
            return
        }
        
        // Check speech recognition permission status
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        print("SpeechRecognizer: Speech recognition status: \(speechStatus.rawValue)")
        
        switch speechStatus {
        case .notDetermined:
            print("SpeechRecognizer: Requesting speech recognition permission...")
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            if status != .authorized {
                DispatchQueue.main.async {
                    self.errorMessage = "Speech recognition permission denied. Please enable in System Preferences > Security & Privacy > Speech Recognition"
                }
                print("SpeechRecognizer: Speech recognition permission denied")
                return
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition permission denied. Please enable in System Preferences > Security & Privacy > Speech Recognition"
            }
            print("SpeechRecognizer: Speech recognition permission denied or restricted")
            return
            
        case .authorized:
            print("SpeechRecognizer: Speech recognition permission granted")
            
        @unknown default:
            DispatchQueue.main.async {
                self.errorMessage = "Unknown speech recognition permission status"
            }
            print("SpeechRecognizer: Unknown speech recognition permission status")
            return
        }
        
        // Update authorization status
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.errorMessage = ""
        }
        
        guard !isRecording else { 
            print("SpeechRecognizer: Already recording")
            return 
        }
        
        // Reset state
        DispatchQueue.main.async {
            self.recognizedText = ""
            self.errorMessage = ""
            self.isFinalResult = false
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognizer not initialized"
            }
            print("SpeechRecognizer: Speech recognizer not initialized")
            return
        }
        
        guard speechRecognizer.isAvailable else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition not available"
            }
            print("SpeechRecognizer: Speech recognition not available")
            return
        }
        
        print("SpeechRecognizer: Speech recognizer is available and ready")
        
        print("SpeechRecognizer: Creating recognition request...")
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create recognition request"
            }
            print("SpeechRecognizer: Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        print("SpeechRecognizer: Starting recognition task...")
        
        // Start recognition task with better error handling
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("SpeechRecognizer: Recognition error: \(error.localizedDescription)")
                    
                    // Handle different types of errors
                    if let result = result, result.isFinal {
                        let transcription = result.bestTranscription.formattedString
                        if !transcription.isEmpty {
                            self.recognizedText = transcription
                            print("SpeechRecognizer: Final result with error: \(transcription)")
                            self.isFinalResult = true
                            self.stopRecording()
                        } else {
                            self.stopRecording()
                        }
                    } else {
                        // For non-final errors, just stop recording
                        self.stopRecording()
                    }
                    return
                }
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    print("SpeechRecognizer: Recognition result - text: '\(transcription)', isFinal: \(result.isFinal)")
                    
                    if !transcription.isEmpty {
                        // Only process text that's longer than what we started with
                        // This helps avoid processing accumulated text from previous sessions
                        if transcription.count > self.recognizedText.count || self.recognizedText.isEmpty {
                            // Calculate the new text (increment)
                            let newText: String
                            if self.recognizedText.isEmpty {
                                newText = transcription
                            } else {
                                // Get only the new part that was added
                                let startIndex = transcription.index(transcription.startIndex, offsetBy: self.recognizedText.count)
                                newText = String(transcription[startIndex...])
                            }
                            
                            self.recognizedText = transcription
                            
                            // Send only the new text (increment)
                            print("SpeechRecognizer: Sending new text increment: '\(newText)'")
                            self.onFinalResult?(newText)
                        }
                        
                        // If this is the final result, we can stop recording
                        if result.isFinal {
                            print("SpeechRecognizer: Final result received, stopping recording")
                            self.isFinalResult = true
                            self.stopRecording()
                        } else {
                            self.isFinalResult = false
                        }
                    } else if result.isFinal {
                        // Empty final result means no speech was detected
                        print("SpeechRecognizer: Empty final result - no speech detected")
                        self.stopRecording()
                    }
                }
            }
        }
        
        print("SpeechRecognizer: Configuring audio input...")
        
        // Configure audio input with error handling
        let inputNode = audioEngine.inputNode
        
        // Get the current format and ensure it's compatible
        let currentFormat = inputNode.outputFormat(forBus: 0)
        print("SpeechRecognizer: Current audio format - sample rate: \(currentFormat.sampleRate), channels: \(currentFormat.channelCount)")
        
        // Use a standard format that's more likely to be compatible
        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: currentFormat.sampleRate, channels: 1)
        let recordingFormat = standardFormat ?? currentFormat
        
        print("SpeechRecognizer: Using recording format - sample rate: \(recordingFormat.sampleRate), channels: \(recordingFormat.channelCount)")
        
        // Install tap with the recording format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        print("SpeechRecognizer: Audio tap installed successfully")
        
        print("SpeechRecognizer: Starting audio engine...")
        
        // Start audio engine with better error handling
        do {
            audioEngine.prepare()
            print("SpeechRecognizer: Audio engine prepared")
            
            // Add a small delay before starting
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            try audioEngine.start()
            print("SpeechRecognizer: Audio engine started")
            
            // Add a delay to ensure audio engine is fully started
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
            print("SpeechRecognizer: Recording started successfully")
            
            // Verify that audio engine is actually running
            if audioEngine.isRunning {
                print("SpeechRecognizer: Audio engine is running successfully")
            } else {
                print("SpeechRecognizer: Warning - Audio engine is not running")
                DispatchQueue.main.async {
                    self.errorMessage = "Audio engine failed to start properly"
                }
                return
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            }
            print("SpeechRecognizer: Failed to start audio engine: \(error.localizedDescription)")
            
            // Clean up on error
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            if audioEngine.inputNode.numberOfInputs > 0 {
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            return
        }
    }
    
    /// Stop recording and recognition
    func stopRecording() {
        print("SpeechRecognizer: Stopping recording...")
        
        guard isRecording else { 
            print("SpeechRecognizer: Not recording")
            return 
        }
        
        // Set recording to false first to prevent multiple calls
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // End recognition request first
        recognitionRequest?.endAudio()
        print("SpeechRecognizer: Recognition request ended")
        
        // Cancel recognition task
        recognitionTask?.cancel()
        print("SpeechRecognizer: Recognition task cancelled")
        
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
            print("SpeechRecognizer: Audio engine stopped")
        }
        
        // Remove tap safely
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
            print("SpeechRecognizer: Audio tap removed")
        }
        
        // Clean up references
        recognitionRequest = nil
        recognitionTask = nil
        
        // Reset audio engine to nil to force fresh creation next time
        audioEngine = AVAudioEngine()
        
        print("SpeechRecognizer: Recording stopped successfully")
        
        // Reset tracking state for next recording session
        lastSentText = ""
        recognizedText = ""
    }
    
    /// Clear recognized text
    func clearText() {
        DispatchQueue.main.async {
            self.recognizedText = ""
            self.errorMessage = ""
            self.isFinalResult = false
            self.lastSentText = ""
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if speech recognition is available
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false
    }
    
    /// Get current authorization status
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }
    
    /// Check and update authorization status
    func checkAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        print("SpeechRecognizer: Speech recognition status: \(speechStatus.rawValue)")
        print("SpeechRecognizer: Microphone status: \(microphoneStatus.rawValue)")
        
        DispatchQueue.main.async {
            // Check both permissions
            let speechAuthorized = speechStatus == .authorized
            let microphoneAuthorized = microphoneStatus == .authorized
            
            if speechAuthorized && microphoneAuthorized {
                self.isAuthorized = true
                self.errorMessage = ""
            } else if !microphoneAuthorized {
                self.isAuthorized = false
                self.errorMessage = "Microphone permission denied"
            } else if !speechAuthorized {
                self.isAuthorized = false
                self.errorMessage = "Speech recognition permission denied"
            } else {
                self.isAuthorized = false
                self.errorMessage = "Permissions not granted"
            }
        }
    }
    
    /// Manually request permissions
    func requestPermissions() async {
        print("SpeechRecognizer: Manually requesting permissions...")
        
        // First, try to trigger system recognition by attempting to access audio
        print("SpeechRecognizer: Attempting to access audio input to trigger system recognition...")
        do {
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            print("SpeechRecognizer: Successfully accessed audio input - format: \(format.sampleRate)Hz, \(format.channelCount) channels")
        } catch {
            print("SpeechRecognizer: Audio input access error: \(error.localizedDescription)")
        }
        
        // Check microphone permission status first
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("SpeechRecognizer: Current microphone status: \(microphoneStatus.rawValue)")
        
        switch microphoneStatus {
        case .notDetermined:
            print("SpeechRecognizer: Requesting microphone permission...")
            
            // Try to start audio engine to trigger permission request
            do {
                audioEngine.prepare()
                try audioEngine.start()
                print("SpeechRecognizer: Audio engine started successfully")
                audioEngine.stop()
            } catch {
                print("SpeechRecognizer: Audio engine start error (this may trigger permission request): \(error.localizedDescription)")
            }
            
            // Request microphone access - this should trigger the system permission dialog
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            print("SpeechRecognizer: Microphone permission result: \(granted)")
            
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone permission denied. Please enable in System Preferences > Security & Privacy > Microphone"
                }
                print("SpeechRecognizer: Microphone permission denied")
                return
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Microphone permission denied. Please enable in System Preferences > Security & Privacy > Microphone"
            }
            print("SpeechRecognizer: Microphone permission denied or restricted")
            return
            
        case .authorized:
            print("SpeechRecognizer: Microphone permission already granted")
            
        @unknown default:
            DispatchQueue.main.async {
                self.errorMessage = "Unknown microphone permission status"
            }
            print("SpeechRecognizer: Unknown microphone permission status")
            return
        }
        
        // Request speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        print("SpeechRecognizer: Current speech recognition status: \(speechStatus.rawValue)")
        
        if speechStatus == .notDetermined {
            print("SpeechRecognizer: Requesting speech recognition permission...")
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            print("SpeechRecognizer: Speech recognition permission result: \(status.rawValue)")
            
            if status != .authorized {
                DispatchQueue.main.async {
                    self.errorMessage = "Speech recognition permission denied. Please enable in System Preferences > Security & Privacy > Speech Recognition"
                }
                print("SpeechRecognizer: Speech recognition permission denied")
                return
            }
        } else if speechStatus != .authorized {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition not authorized"
            }
            print("SpeechRecognizer: Speech recognition not authorized")
            return
        }
        
        // Update status
        DispatchQueue.main.async {
            self.isAuthorized = true
            self.errorMessage = ""
        }
        
        print("SpeechRecognizer: All permissions granted")
    }
    
    /// Open System Preferences to microphone settings
    func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    /// Open System Preferences to speech recognition settings
    func openSpeechRecognitionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }
    
    /// Open System Preferences to screen recording settings
    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    /// Check if screen recording permission is needed
    func checkScreenRecordingPermission() -> Bool {
        // In macOS, screen recording permission is often required for speech recognition
        // This is a simplified check - in practice, you might need to test actual functionality
        return true // Assume it's needed for now
    }
    

}
