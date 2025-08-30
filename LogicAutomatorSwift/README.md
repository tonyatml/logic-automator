# Logic Maestro

A modern Swift-based automation tool for Logic Pro X with voice commands and a beautiful graphical interface.

## 🎯 Project Overview

This project is a complete rewrite of the original Python-based Logic Pro automation tool, now using native Swift and Accessibility API for direct macOS integration. It provides a modern, user-friendly graphical interface with voice command support for automating Logic Pro X workflows.

### Key Features

- **Native Swift Implementation**: Direct use of Accessibility API, no Python dependencies
- **Modern SwiftUI Interface**: Beautiful, responsive graphical user interface with dark theme
- **Voice Command Support**: Speech recognition for hands-free Logic Pro control
- **Real-time Status Updates**: Live progress tracking and status indicators
- **Natural Language Commands**: Process commands in plain English
- **Permission Management**: Automatic Accessibility and microphone permission checking
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Command History**: Built-in logging and command history

## 🏗️ Project Structure

```
LogicAutomatorSwift/
├── logic.xcodeproj/              # Xcode project configuration
├── logic/                        # Main application source
│   ├── logicApp.swift           # App entry point
│   ├── ContentView.swift        # Main UI interface with voice commands
│   ├── LogicAutomator.swift     # Core automation engine
│   ├── CommandAutomator.swift   # High-level command processing
│   ├── SpeechRecognizer.swift   # Voice command recognition
│   ├── LogicError.swift         # Error handling
│   ├── Assets.xcassets/         # App icons and assets
│   ├── logic.entitlements       # App permissions
│   └── templates/               # Logic Pro templates
└── README.md                    # This file
```

### Core Components

1. **LogicAutomator**: Low-level Accessibility API wrapper for Logic Pro control
2. **CommandAutomator**: High-level command processing and automation interface
3. **SpeechRecognizer**: Voice command recognition and processing
4. **ContentView**: Modern SwiftUI interface with voice input and real-time status
5. **LogicError**: Comprehensive error handling system

## 🚀 Quick Start

### System Requirements

- macOS 14.0+
- Xcode 15.0+
- Logic Pro X (for full functionality)
- Microphone (for voice commands)

### Installation Steps

1. **Clone the project**
   ```bash
   git clone <repository-url>
   cd LogicAutomatorSwift
   ```

2. **Open in Xcode**
   ```bash
   open logic.xcodeproj
   ```

3. **Build and Run**
   - Press `Cmd+R` in Xcode, or
   - Use the command line: `xcodebuild -project logic.xcodeproj -scheme logic -configuration Debug build`

4. **Run the app**
   ```bash
   open /Users/tonyniu/Library/Developer/Xcode/DerivedData/logic-*/Build/Products/Debug/logic.app
   ```

### Permission Setup

1. **Accessibility Permissions**
   - System Preferences > Security & Privacy > Privacy > Accessibility
   - Add Logic Maestro application

2. **Microphone Permissions**
   - System Preferences > Security & Privacy > Privacy > Microphone
   - Add Logic Maestro application

3. **Speech Recognition Permissions**
   - System Preferences > Security & Privacy > Privacy > Speech Recognition
   - Add Logic Maestro application

## 📖 Usage Guide

### Basic Usage

1. **Launch the app**: The app will automatically check permissions and Logic Pro status
2. **Enter commands**: 
   - Type commands in the text field, or
   - Use voice commands by clicking the microphone button
3. **Send commands**: Click "Send" or press Enter to execute commands
4. **Monitor status**: Watch the real-time status indicators and progress

### Voice Commands

The app supports voice commands for hands-free operation:

- **"Open Logic Pro"** - Launches Logic Pro X
- **"Create new project"** - Creates a new Logic Pro project
- **"Navigate to tracks"** - Opens the tracks view
- **"Select track 1"** - Selects the first track
- **"Set tempo 120"** - Sets the project tempo to 120 BPM
- **"Import MIDI file"** - Opens MIDI import dialog
- **"Play"** - Starts playback
- **"Stop"** - Stops playback

### Text Commands

You can also type commands directly:

- `open logic pro`
- `create new project`
- `navigate to tracks`
- `select track 1`
- `set tempo 120`
- `set key C major`
- `import midi file`
- `new track`
- `replace region`
- `play`
- `stop`
- `help`

### Features

- ✅ **Voice Commands**: Speech recognition for hands-free operation
- ✅ **Real-time Status**: Live progress tracking and status updates
- ✅ **Permission Checking**: Automatic Accessibility and microphone permission verification
- ✅ **Logic Pro Detection**: Automatic detection of Logic Pro running status
- ✅ **Natural Language**: Process commands in plain English
- ✅ **Command History**: Built-in logging and command history
- ✅ **Error Handling**: User-friendly error messages and recovery suggestions
- ✅ **Dark Theme**: Modern dark interface design

## 🔧 Technical Implementation

### Accessibility API Integration

The app uses macOS Accessibility API for direct Logic Pro control:

```swift
// Check permissions
func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}

// Get Logic Pro application reference
private func setupLogicApp() {
    let runningApps = NSWorkspace.shared.runningApplications
    if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
        self.logicApp = AXUIElementCreateApplication(logicApp.processIdentifier)
    }
}
```

### Speech Recognition

Voice command processing using Speech framework:

```swift
class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var isAuthorized = false
}
```

### SwiftUI Interface

Modern, responsive interface with real-time updates:

```swift
@StateObject private var automator = CommandAutomator()
@StateObject private var speechRecognizer = SpeechRecognizer()
@Published var isWorking = false
@Published var currentStep = ""
@Published var progress: Double = 0.0
```

### Command Processing

Natural language command processing:

```swift
func processCommand(_ command: String) async {
    let lowerCommand = command.lowercased()
    
    if lowerCommand.contains("open") {
        try await handleOpenCommand(command)
    } else if lowerCommand.contains("create") {
        try await handleCreateCommand(command)
    } else if lowerCommand.contains("navigate") {
        try await handleNavigationCommand(command)
    }
    // ... more command handlers
}
```

### Error Handling

Comprehensive error handling with user-friendly messages:

```swift
enum LogicError: Error, LocalizedError {
    case appNotRunning
    case accessibilityNotEnabled
    case timeout(String)
    case elementNotFound(String)
    case speechRecognitionFailed(String)
    // ... more error cases
}
```

## 🆚 Comparison with Python Version

| Feature | Python Version | Swift Version |
|---------|----------------|---------------|
| Interface | Command line | Graphical UI with voice |
| Performance | Medium | Excellent |
| Dependencies | Python + automacos | No external dependencies |
| Build System | Manual | Xcode project |
| Error Handling | Basic | Comprehensive |
| Permission Management | Manual | Automatic detection |
| Real-time Updates | No | Yes |
| Voice Commands | No | Yes |
| User Experience | Technical | User-friendly |
| Command Processing | Fixed commands | Natural language |

## 🧪 Testing

The app includes comprehensive testing and validation:

- **Permission Testing**: Automatic Accessibility and microphone permission verification
- **Logic Pro Detection**: Real-time Logic Pro status monitoring
- **Speech Recognition**: Voice command processing and validation
- **Error Handling**: Comprehensive error scenarios
- **UI Testing**: SwiftUI interface validation

## 🐛 Troubleshooting

### Common Issues

1. **App won't launch**
   - Ensure Xcode is properly installed
   - Check macOS version compatibility

2. **Permission denied**
   - Check System Preferences > Security & Privacy > Privacy > Accessibility
   - Check System Preferences > Security & Privacy > Privacy > Microphone
   - Check System Preferences > Security & Privacy > Privacy > Speech Recognition
   - Re-grant permissions as needed

3. **Logic Pro not detected**
   - Ensure Logic Pro X is installed
   - Check if Logic Pro is running

4. **Voice commands not working**
   - Ensure microphone permissions are granted
   - Check speech recognition permissions
   - Verify microphone is working in other apps

5. **Build errors**
   - Ensure Xcode 15.0+ is installed
   - Check macOS version (14.0+ required)

### Debug Mode

Enable detailed logging by checking the console output in Xcode.

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Environment Setup

```bash
# Clone the project
git clone <repository-url>
cd LogicAutomatorSwift

# Open in Xcode
open logic.xcodeproj

# Build the project
xcodebuild -project logic.xcodeproj -scheme logic -configuration Debug build
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Thanks to Apple for providing the Accessibility API, Speech framework, and SwiftUI
- Thanks to the Logic Pro X team
- Thanks to all contributors and test users

## 🚧 Development Status

**Current Status**: 🟢 Production Ready

- ✅ Core functionality implemented
- ✅ SwiftUI interface completed
- ✅ Voice command support
- ✅ Accessibility API integration
- ✅ Speech recognition
- ✅ Error handling system
- ✅ Real-time status updates
- ✅ Natural language command processing
- ✅ Permission management
- ✅ Dark theme interface

---

**Note**: This is a production-ready application. The Swift implementation provides a much better user experience compared to the original Python version, with native macOS integration, voice commands, and a modern graphical interface.

## 🎵 Next Steps

Future enhancements could include:
- Advanced Logic Pro automation features
- Custom voice command training
- Batch command processing
- Integration with other DAWs
- Cloud project synchronization
- Advanced speech recognition with context awareness
- Plugin automation support
