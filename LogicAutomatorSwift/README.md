# Logic Automator Swift

A modern Swift-based automation tool for Logic Pro X with a beautiful graphical interface.

## 🎯 Project Overview

This project is a complete rewrite of the original Python-based Logic Pro automation tool, now using native Swift and Accessibility API for direct macOS integration. It provides a modern, user-friendly graphical interface for automating Logic Pro X workflows.

### Key Features

- **Native Swift Implementation**: Direct use of Accessibility API, no Python dependencies
- **Modern SwiftUI Interface**: Beautiful, responsive graphical user interface
- **Real-time Status Updates**: Live progress tracking and status indicators
- **Preset Configurations**: Quick setup for common dance music genres
- **MIDI File Support**: Optional MIDI file import functionality
- **Permission Management**: Automatic Accessibility permission checking
- **Error Handling**: Comprehensive error handling with user-friendly messages

## 🏗️ Project Structure

```
LogicAutomatorSwift/
├── logic.xcodeproj/              # Xcode project configuration
├── logic/                        # Main application source
│   ├── logicApp.swift           # App entry point
│   ├── ContentView.swift        # Main UI interface
│   ├── LogicAutomator.swift     # Core automation engine
│   ├── LogicError.swift         # Error handling
│   ├── DanceGoAutomator.swift   # High-level automation interface
│   ├── Assets.xcassets/         # App icons and assets
│   └── logic.entitlements       # App permissions
├── python resources/             # Legacy Python resources (for reference)
│   ├── dance_go_automator.py    # Original Python script
│   ├── logic.py                 # Original Python module
│   ├── templates/               # Logic Pro templates
│   └── test.midi               # Test MIDI file
└── README.md                    # This file
```

### Core Components

1. **LogicAutomator**: Low-level Accessibility API wrapper for Logic Pro control
2. **DanceGoAutomator**: High-level automation interface for dance project creation
3. **ContentView**: Modern SwiftUI interface with real-time status updates
4. **LogicError**: Comprehensive error handling system

## 🚀 Quick Start

### System Requirements

- macOS 14.0+
- Xcode 15.0+
- Logic Pro X (for full functionality)

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
   - Add Logic Automator application

2. **Automation Permissions**
   - System Preferences > Security & Privacy > Privacy > Automation
   - Ensure Logic Automator can control Logic Pro X

## 📖 Usage Guide

### Basic Usage

1. **Launch the app**: The app will automatically check permissions and Logic Pro status
2. **Enter project details**: 
   - Project name
   - Tempo (BPM) - adjustable with slider
   - Key signature - select from dropdown
   - MIDI file (optional) - browse and select
3. **Use presets**: Click on genre presets for quick setup
4. **Create project**: Click "Create Dance Project" to start automation

### Features

- ✅ **Real-time Status**: Live progress tracking and status updates
- ✅ **Permission Checking**: Automatic Accessibility permission verification
- ✅ **Logic Pro Detection**: Automatic detection of Logic Pro running status
- ✅ **Project Configuration**: Comprehensive project setup options
- ✅ **Preset Templates**: Quick setup for House, Techno, Trance, Dubstep
- ✅ **MIDI Import**: Optional MIDI file import functionality
- ✅ **Error Handling**: User-friendly error messages and recovery suggestions

### Preset Configurations

- **House**: 128 BPM, A minor
- **Techno**: 130 BPM, D minor  
- **Trance**: 138 BPM, E major
- **Dubstep**: 140 BPM, F minor
- **EDM**: 128 BPM, C major

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

### SwiftUI Interface

Modern, responsive interface with real-time updates:

```swift
@StateObject private var danceAutomator = DanceGoAutomator()
@Published var isWorking = false
@Published var currentStep = ""
@Published var progress: Double = 0.0
```

### Error Handling

Comprehensive error handling with user-friendly messages:

```swift
enum LogicError: Error, LocalizedError {
    case appNotRunning
    case accessibilityNotEnabled
    case timeout(String)
    case elementNotFound(String)
    // ... more error cases
}
```

## 🆚 Comparison with Python Version

| Feature | Python Version | Swift Version |
|---------|----------------|---------------|
| Interface | Command line | Graphical UI |
| Performance | Medium | Excellent |
| Dependencies | Python + automacos | No external dependencies |
| Build System | Manual | Xcode project |
| Error Handling | Basic | Comprehensive |
| Permission Management | Manual | Automatic detection |
| Real-time Updates | No | Yes |
| User Experience | Technical | User-friendly |

## 🧪 Testing

The app includes comprehensive testing and validation:

- **Permission Testing**: Automatic Accessibility permission verification
- **Logic Pro Detection**: Real-time Logic Pro status monitoring
- **Error Handling**: Comprehensive error scenarios
- **UI Testing**: SwiftUI interface validation

## 🐛 Troubleshooting

### Common Issues

1. **App won't launch**
   - Ensure Xcode is properly installed
   - Check macOS version compatibility

2. **Permission denied**
   - Check System Preferences > Security & Privacy > Privacy > Accessibility
   - Re-grant Accessibility permissions

3. **Logic Pro not detected**
   - Ensure Logic Pro X is installed
   - Check if Logic Pro is running

4. **Build errors**
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

- Thanks to Apple for providing the Accessibility API and SwiftUI
- Thanks to the Logic Pro X team
- Thanks to all contributors and test users

## 🚧 Development Status

**Current Status**: 🟢 Production Ready

- ✅ Core functionality implemented
- ✅ SwiftUI interface completed
- ✅ Accessibility API integration
- ✅ Error handling system
- ✅ Real-time status updates
- ✅ Preset configurations
- ✅ MIDI file support
- ✅ Permission management

---

**Note**: This is a production-ready application. The Swift implementation provides a much better user experience compared to the original Python version, with native macOS integration and a modern graphical interface.

## 🎵 Next Steps

Future enhancements could include:
- Advanced Logic Pro automation features
- Batch project creation
- Custom template support
- Integration with other DAWs
- Cloud project synchronization
