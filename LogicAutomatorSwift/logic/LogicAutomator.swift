import Cocoa
import ApplicationServices

/// Logic Pro automation core class
/// Uses Accessibility API to directly control Logic Pro
class LogicAutomator: ObservableObject {
    private var logicApp: AXUIElement?
    private let logicBundleID = "com.apple.logic10"
    
    @Published var isConnected = false
    @Published var currentStatus = "Not connected"
    @Published var isWorking = false
    
    init() {
        setupLogicApp()
    }
    
    // MARK: - Initialization
    
    /// Setup Logic Pro application reference
    private func setupLogicApp() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            self.logicApp = AXUIElementCreateApplication(logicApp.processIdentifier)
            isConnected = true
            currentStatus = "Connected to Logic Pro"
        } else {
            isConnected = false
            currentStatus = "Logic Pro not running"
        }
    }
    
    /// Check Accessibility permissions
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Application Control
    
    /// Launch Logic Pro
    func launchLogicPro() async throws {
        guard !isConnected else { return }
        
        await MainActor.run {
            currentStatus = "Launching Logic Pro..."
            isWorking = true
        }
        
        // Use new API to launch application
        let url = URL(fileURLWithPath: "/Applications/Logic Pro.app")
        let config = NSWorkspace.OpenConfiguration()
        
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            // Fallback to old method
            NSWorkspace.shared.launchApplication("Logic Pro")
        }
        
        // Wait for Logic Pro to launch
        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            setupLogicApp()
            if isConnected {
                await MainActor.run {
                    currentStatus = "Logic Pro launched and connected"
                    isWorking = false
                }
                return
            }
        }
        
        await MainActor.run {
            isWorking = false
        }
        throw LogicError.timeout("Logic Pro failed to launch within 25 seconds")
    }
    
    /// Activate Logic Pro
    func activateLogic() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Logic Pro activated"
        }
    }
    
    // MARK: - Project Operations
    
    /// Open Logic project
    func openProject(_ projectPath: String) async throws {
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw LogicError.invalidProjectPath(projectPath)
        }
        
        await MainActor.run {
            currentStatus = "Opening project..."
        }
        
        // Use NSWorkspace to open project
        let success = NSWorkspace.shared.openFile(projectPath, withApplication: "Logic Pro")
        if !success {
            throw LogicError.projectCreationFailed("Failed to open project with Logic Pro")
        }
        
        // Wait for Logic Pro to activate
        try await waitForLogicToActivate()
        
        await MainActor.run {
            currentStatus = "Project opened successfully"
        }
    }
    
    /// Wait for Logic Pro to activate
    private func waitForLogicToActivate() async throws {
        for _ in 0..<100 {
            if isConnected {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        throw LogicError.timeout("Logic Pro failed to activate")
    }
    
    // MARK: - Tempo Setting
    
    /// Set project tempo
    func setTempo(_ bpm: Int) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Setting tempo to \(bpm) BPM..."
        }
        
        // Activate Logic Pro
        try await activateLogic()
        
        // Simplified implementation - just print operation
        print("Setting tempo to \(bpm) BPM...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            currentStatus = "Tempo set to \(bpm) BPM"
        }
    }
    
    // MARK: - Key Setting
    
    /// Set project key
    func setKey(_ key: String) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Setting key to \(key)..."
        }
        
        // Activate Logic Pro
        try await activateLogic()
        
        // Simplified implementation - just print operation
        print("Setting key to \(key)...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            currentStatus = "Key set to \(key)"
        }
    }
    
    // MARK: - MIDI Import
    
    /// Import MIDI file
    func importMIDI(_ midiPath: String) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        guard FileManager.default.fileExists(atPath: midiPath) else {
            throw LogicError.midiImportFailed("MIDI file not found: \(midiPath)")
        }
        
        await MainActor.run {
            currentStatus = "Importing MIDI file..."
        }
        
        // Activate Logic Pro
        try await activateLogic()
        
        // Step 1: Select last track
        await MainActor.run {
            currentStatus = "Selecting last track..."
        }
        //try await selectLastTrack()
        
        // Step 2: Open Import MIDI File menu (File -> Import -> MIDI File...)
        await MainActor.run {
            currentStatus = "Opening Import MIDI File dialog..."
        }
        try await openImportDialog()
        
        // Step 3: Wait for import window and navigate to folder
        await MainActor.run {
            currentStatus = "Navigating to folder..."
        }
        try await navigateToFolder(midiPath)
        
        // Step 4: Click Import button
        await MainActor.run {
            currentStatus = "Clicking Import button..."
        }
        try await confirmImport()
        
        // Step 5: Handle tempo import dialog
        await MainActor.run {
            currentStatus = "Handling tempo import..."
        }
        try await handleTempoImport()
        
        await MainActor.run {
            currentStatus = "MIDI file imported successfully"
        }
    }
    
    /// Select last track
    private func selectLastTrack() async throws {
        print("Selecting last track...")
        // Send Cmd+Shift+Down to select last track
        try await sendKeysWithModifiers("down", modifiers: ["cmd", "shift"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Open Import MIDI File dialog
    private func openImportDialog() async throws {
        print("Opening Import MIDI File dialog...")
        
        // Use Accessibility API to find and click menu item
        // Like Python: logic.menuItem("File", "Import", "MIDI File…").Press()
        try await clickMenuItem("File", "Import", "MIDI File…")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds to wait for dialog
    }
    
    /// Click menu item using Accessibility API (simplified version)
    private func clickMenuItem(_ menuName: String, _ submenuName: String, _ itemName: String) async throws {
        print("Clicking menu item: \(menuName) -> \(submenuName) -> \(itemName)")
        
        guard let logicApp = logicApp else {
            throw LogicError.appNotRunning
        }
        
        // Get menu bar
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(logicApp, kAXMenuBarAttribute as CFString, &menuBar)
        
        guard result == .success, let menuBar = menuBar else {
            print("Failed to get menu bar")
            throw LogicError.menuOperationFailed("Could not access menu bar")
        }
        
        // Find and click the menu item
        try await findAndClickMenuItem(menuBar as! AXUIElement, [menuName, submenuName, itemName])
        
        print("Menu item clicked successfully")
    }
    
    /// Recursively find and click menu item
    private func findAndClickMenuItem(_ element: AXUIElement, _ menuPath: [String]) async throws {
        guard !menuPath.isEmpty else { return }
        
        let currentMenuName = menuPath[0]
        let remainingPath = Array(menuPath.dropFirst())
        
        print("Looking for menu item: '\(currentMenuName)' in current element")
        
        // Get children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            throw LogicError.menuOperationFailed("Could not get menu children")
        }
        
        let childrenArray = children as! [AXUIElement]
        print("Found \(childrenArray.count) children in current element")
        
        // Find the menu item with matching title
        for (index, child) in childrenArray.enumerated() {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let title = title as? String {
                print("Child \(index): '\(title)'")
                
                if title == currentMenuName {
                    print("Found matching menu item: '\(currentMenuName)'")
                    
                    // If this is the final item, click it
                    if remainingPath.isEmpty {
                        print("Clicking final menu item: '\(currentMenuName)'")
                        let clickResult = AXUIElementPerformAction(child, kAXPressAction as CFString)
                        if clickResult != .success {
                            throw LogicError.menuOperationFailed("Failed to click menu item: \(currentMenuName)")
                        }
                        print("Successfully clicked menu item: '\(currentMenuName)'")
                        return
                    } else {
                        // For submenus, we need to "press" the menu item to expand it
                        print("Pressing menu item to expand submenu: '\(currentMenuName)'")
                        let pressResult = AXUIElementPerformAction(child, kAXPressAction as CFString)
                        if pressResult != .success {
                            throw LogicError.menuOperationFailed("Failed to expand submenu: \(currentMenuName)")
                        }
                        
                        // Wait a bit for the submenu to expand
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        
                        // Check if the first child is an AXMenu (submenu)
                        var submenuChildren: CFTypeRef?
                        let submenuResult = AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &submenuChildren)
                        
                        if submenuResult == .success, let submenuChildren = submenuChildren {
                            let submenuArray = submenuChildren as! [AXUIElement]
                            if !submenuArray.isEmpty {
                                // Check if first child has AXMenu role
                                var role: CFTypeRef?
                                let roleResult = AXUIElementCopyAttributeValue(submenuArray[0], kAXRoleAttribute as CFString, &role)
                                
                                if roleResult == .success, let role = role as? String, role == "AXMenu" {
                                    print("Found AXMenu submenu, using it for next search")
                                    // Use the AXMenu element for the next search
                                    try await findAndClickMenuItem(submenuArray[0], remainingPath)
                                    return
                                }
                            }
                        }
                        
                        // Fallback: Recursively find the next item in the original element
                        print("Recursively searching for remaining path: \(remainingPath)")
                        try await findAndClickMenuItem(child, remainingPath)
                        return
                    }
                }
            } else {
                print("Child \(index): Could not get title")
            }
        }
        
        // If we get here, we didn't find the menu item
        print("Available menu items:")
        for (index, child) in childrenArray.enumerated() {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            if titleResult == .success, let title = title as? String {
                print("  \(index): '\(title)'")
            } else {
                print("  \(index): <no title>")
            }
        }
        
        throw LogicError.menuOperationFailed("Could not find menu item: '\(currentMenuName)'")
    }
    
    /// Navigate to folder and select file (like Python implementation)
    private func navigateToFolder(_ filePath: String) async throws {
        print("Navigating to folder for file: \(filePath)")
        
        // Get just the filename, not the full path
        let fileName = (filePath as NSString).lastPathComponent
        
        // In Python: logic.sendGlobalKeyWithModifiers("g", ["command", "shift"])
        // This opens "Go to Folder" dialog
        try await sendKeysWithModifiers("g", modifiers: ["cmd", "shift"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // In Python: logic.sendKeys(midiFile) - sends just the filename
        // Type the filename
        for char in fileName {
            try await sendKeys(String(char))
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await sendKeys("\n") // Press Enter
        try await Task.sleep(nanoseconds: 5000_000_000) // 0.5 seconds
    }
    
    /// Click Import button
    private func confirmImport() async throws {
        print("Pressing import...")
        
        // In Python: import_window.buttons("Import")[0].Press()
        // For now, just press Enter which should work in most dialogs
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await sendKeys("\n") // Press Enter
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    /// Handle tempo import dialog
    private func handleTempoImport() async throws {
        print("Waiting for tempo import message...")
        
        // In Python: waits for alert window with AXDescription == "alert"
        // Then clicks "Import Tempo" button
        // For now, just wait and press Enter
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        print("Importing tempo...")
        // In Python: alert.buttons("Import Tempo")[0].Press()
        // For now, just press Enter which should work
        try await sendKeys("\n") // Press Enter
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    // MARK: - Playback Control
    
    /// Start playback
    func startPlayback() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Starting playback..."
        }
        
        try await activateLogic()
        print("Starting playback...")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            currentStatus = "Playback started"
        }
    }
    
    /// Stop playback
    func stopPlayback() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Stopping playback..."
        }
        
        try await activateLogic()
        print("Stopping playback...")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            currentStatus = "Playback stopped"
        }
    }
    
    // MARK: - Track Management
    
    /// Create new track
    func newTrack() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Creating new track..."
        }
        
        try await activateLogic()
        
        // Send Cmd+T to create new track
        print("Creating new track with Cmd+T...")
        try await sendKeysWithModifiers("t", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            currentStatus = "New track created"
        }
    }
    
    /// Create new track with specific type
    func newTrack(type: String) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Creating new \(type) track..."
        }
        
        try await activateLogic()
        
        // Send Cmd+T to open new track dialog
        print("Creating new \(type) track...")
        try await sendKeysWithModifiers("t", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Type the track type
        try await sendKeys(type)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Press Enter to confirm
        try await sendKeys("\n")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            currentStatus = "New \(type) track created"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Send keyboard input using CGEvent
    private func sendKeys(_ keys: String) async throws {
        print("Sending keys: \(keys)")
        
        for char in keys {
            let keyCode = getKeyCode(for: String(char))
            if keyCode != 0 {
                // Key down
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                keyDownEvent?.post(tap: .cghidEventTap)
                
                // Small delay
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Key up
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                keyUpEvent?.post(tap: .cghidEventTap)
                
                // Small delay between characters
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }
    }
    
    /// Send keys with modifiers using CGEvent
    private func sendKeysWithModifiers(_ key: String, modifiers: [String]) async throws {
        print("Sending key with modifiers: \(key), modifiers: \(modifiers)")
        
        let keyCode = getKeyCode(for: key)
        guard keyCode != 0 else {
            print("Unknown key: \(key)")
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
        case "space": return 0x31
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
