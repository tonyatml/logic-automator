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
    
    // Callback for logging
    var logCallback: ((String) -> Void)?
    
    init() {
        setupLogicApp()
    }
    
    // MARK: - Logging
    
    /// Log message with callback support
    private func log(_ message: String) {
        print(message)
        logCallback?(message)
    }
    
    // MARK: - Initialization
    
    /// Setup Logic Pro application reference
    private func setupLogicApp() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            self.logicApp = AXUIElementCreateApplication(logicApp.processIdentifier)
            isConnected = true
            currentStatus = "Connected to Logic Pro"
            log("Logic Pro connected with PID: \(logicApp.processIdentifier)")
        } else {
            self.logicApp = nil
            isConnected = false
            currentStatus = "Logic Pro not running"
            log("Logic Pro not found in running applications")
        }
    }
    
    /// Check Accessibility permissions
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Application Control
    
    /// Launch Logic Pro using multiple methods for better reliability
    func launchLogicPro() async throws {
        guard !isConnected else { return }
        
        await MainActor.run {
            currentStatus = "Launching Logic Pro..."
            isWorking = true
        }
        
        log("Launching Logic Pro using enhanced launch methods...")
        
        // Method 1: Use NSWorkspace with new API
        await launchWithNSWorkspace()
        
        // Method 2: Use System Events as fallback if needed
        if !isConnected {
            await launchWithSystemEvents()
        }
        
        // Wait for Logic Pro to launch with enhanced detection
        await waitForLogicProToLaunch()
        
        await MainActor.run {
            isWorking = false
        }
        
        if !isConnected {
            throw LogicError.timeout("Logic Pro failed to launch within 30 seconds")
        }
    }
    
    /// Launch Logic Pro using NSWorkspace
    private func launchWithNSWorkspace() async {
        log("Attempting launch with NSWorkspace...")
        
        let url = URL(fileURLWithPath: "/Applications/Logic Pro.app")
        let config = NSWorkspace.OpenConfiguration()
        
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            log("NSWorkspace launch successful")
        } catch {
            log("NSWorkspace launch failed, trying fallback method...")
            // Fallback to old method
            NSWorkspace.shared.launchApplication("Logic Pro")
        }
    }
    
    /// Launch Logic Pro using System Events
    private func launchWithSystemEvents() async {
        log("Attempting launch with System Events...")
        
        let script = """
        tell application "Logic Pro" to activate
        """
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                log("System Events launch successful: \(output)")
            } else {
                log("System Events launch failed with status \(process.terminationStatus): \(output)")
            }
        } catch {
            log("System Events launch error: \(error.localizedDescription)")
        }
    }
    
    /// Wait for Logic Pro to launch with enhanced detection
    private func waitForLogicProToLaunch() async {
        log("Waiting for Logic Pro to launch...")
        
        for attempt in 1...60 { // Increased timeout to 30 seconds
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            setupLogicApp()
            
            if isConnected {
                await MainActor.run {
                    currentStatus = "Logic Pro launched and connected"
                }
                log("Logic Pro successfully launched and connected (attempt \(attempt))")
                return
            }
            
            if attempt % 10 == 0 {
                log("Still waiting for Logic Pro to launch... (attempt \(attempt)/60)")
            }
        }
        
        log("Logic Pro launch timeout reached")
    }
    
    /// Activate Logic Pro using multiple methods for better reliability
    func activateLogic() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        log("Activating Logic Pro using enhanced activation methods...")
        
        // Method 1: Use NSWorkspace activation (primary method)
        await activateWithNSWorkspace()
        
        // Method 2: Use System Events for additional reliability
        await activateWithSystemEvents()
        
        // Method 3: Use Accessibility API as fallback
        await activateWithAccessibilityAPI()
        
        // Wait for the activation to take effect
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Verify activation was successful
        // await verifyActivation()
        
        await MainActor.run {
            currentStatus = "Logic Pro activated"
        }
        
        log("Logic Pro activation completed using enhanced methods")
    }
    
    /// Activate Logic Pro using NSWorkspace
    private func activateWithNSWorkspace() async {
        log("Attempting activation with NSWorkspace...")
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            logicApp.activate()
            log("NSWorkspace activation requested )")
        }
    }
    
    /// Activate Logic Pro using System Events
    private func activateWithSystemEvents() async {
        log("Attempting activation with System Events...")
        
        // Enhanced AppleScript with multiple activation methods
        let script = """
        tell application "Logic Pro" to activate
        """
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                log("System Events activation successful: \(output)")
            } else {
                log("System Events activation failed with status \(process.terminationStatus): \(output)")
            }
        } catch {
            log("System Events activation error: \(error.localizedDescription)")
        }
    }
    
    /// Activate Logic Pro using Accessibility API as fallback
    private func activateWithAccessibilityAPI() async {
        log("Attempting activation with Accessibility API...")
        
        guard let logicApp = logicApp else {
            log("No Logic Pro app reference available for Accessibility API activation")
            return
        }
        
        // Use Accessibility API to bring window to front
        let value = kCFBooleanTrue as CFTypeRef
        let result = AXUIElementSetAttributeValue(logicApp, kAXMainWindowAttribute as CFString, value)
        
        if result == .success {
            log("Accessibility API activation successful")
        } else {
            log("Accessibility API activation failed with error: \(result)")
        }
    }
    
    /// Verify that Logic Pro is actually activated
    private func verifyActivation() async {
        log("Verifying Logic Pro activation...")
        
        // Check if Logic Pro is frontmost using System Events
        let verificationScript = """
        tell application "System Events"
            try
                set frontmostApp to name of first application process whose frontmost is true
                return frontmostApp is "Logic Pro"
            on error
                return false
            end try
        end tell
        """
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", verificationScript]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                // Parse the output to check if Logic Pro is frontmost
                let isFrontmost = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
                if isFrontmost {
                    log("✅ Logic Pro activation verified - app is frontmost")
                } else {
                    log("⚠️ Logic Pro activation verification failed - app is not frontmost")
                    // Try one more activation attempt
                    await activateWithSystemEvents()
                }
            } else {
                log("Activation verification failed with status \(process.terminationStatus): \(output)")
            }
        } catch {
            log("Activation verification error: \(error.localizedDescription)")
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
        log("Setting tempo to \(bpm) BPM...")
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
        log("Setting key to \(key)...")
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
        
        try await startPlayback()
    }
    
    // MARK: - Advanced Region Operations
    
    /// Replace region at specific bar with new audio file
    func replaceRegionAtBar(_ bar: Int, withAudioFile audioPath: String, onTrack trackName: String? = nil, trackIndex: Int? = nil) async throws {
        log("Replacing region at bar \(bar) with audio file: \(audioPath)")
        currentStatus = "Replacing region at bar \(bar)..."
        
        // 1. Navigate to the specific bar
        try await navigateToBar(bar)
        
        // 2. Select the target track (if specified)
        if let trackIndex = trackIndex {
            try await selectTrackByIndex(trackIndex)
        } else if let trackName = trackName {
            try await selectTrackByName(trackName)
        }
        
        // 3. Delete existing region at that position
        // try await deleteRegionAtCurrentPosition()
        
        // 4. Import the new audio file
        //try await importAudioFile(audioPath)
        // try await importMIDI(audioPath)
        
        // 5. Place the audio at the correct bar position
        // try await placeAudioAtBar(bar)
        
        currentStatus = "Region replaced successfully at bar \(bar)"
    }
    
    /// Navigate to a specific bar in the timeline
    func navigateToBar(_ bar: Int) async throws {
        log("Navigating to bar \(bar)")
        
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        // Activate Logic Pro first
        try await activateLogic()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Use Cmd+L to open "Go to Position" dialog
        log("Opening Go to Position dialog with Cmd+L...")
        try await sendKeysWithModifiers("l", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Type the bar number
        let barString = String(bar)
        log("Typing bar number: \(barString)")
        for char in barString {
            try await sendKeys(String(char))
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Press Enter to confirm
        log("Pressing Enter to confirm...")
        try await sendKeys("\n")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        log("Navigation to bar \(bar) completed")
    }
    
    /// Select a track by index number
    func selectTrackByIndex(_ index: Int) async throws {
        print("Selecting track by index: \(index)")
        
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        // Activate Logic Pro first
        try await activateLogic()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // First, go to the top of the track list
        print("Going to top of track list...")
        try await sendKeysWithModifiers("home", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then move down to the target track index
        print("Moving down to track index \(index)...")
        for i in 1..<index {
            try await sendKeys("down")
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        print("Track selection by index completed")
    }
    
    /// Select a track by name
    func selectTrackByName(_ trackName: String) async throws {
        print("Selecting track by name: \(trackName)")
        
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        // Activate Logic Pro first
        try await activateLogic()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Use Cmd+F to open find dialog
        print("Opening find dialog with Cmd+F...")
        try await sendKeysWithModifiers("f", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Type the track name
        print("Typing track name: \(trackName)")
        for char in trackName {
            try await sendKeys(String(char))
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Press Enter to select
        print("Pressing Enter to select track...")
        try await sendKeys("\n")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        print("Track selection by name completed")
    }
    
    /// Delete region at current position
    private func deleteRegionAtCurrentPosition() async throws {
        print("Deleting region at current position")
        
        // Select the region at current position
        try await sendKeysWithModifiers("a", modifiers: ["cmd"]) // Select all
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Delete the selected region
        try await sendKeysWithModifiers("delete", modifiers: [])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Import audio file using menu navigation
    private func importAudioFile(_ audioPath: String) async throws {
        print("Importing audio file: \(audioPath)")
        
        // Use menu: File -> Import -> Audio Files...
        try await clickMenuItem("File", "Import", "Other…")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Navigate to folder and select file
        try await navigateToFolder(audioPath)
        
        // Confirm import
        try await confirmImport()
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
    
    /// Place audio at specific bar position
    private func placeAudioAtBar(_ bar: Int) async throws {
        print("Placing audio at bar \(bar)")
        
        // Navigate to the bar again to ensure we're at the right position
        try await navigateToBar(bar)
        
        // Select the imported audio region
        try await sendKeysWithModifiers("a", modifiers: ["cmd"]) // Select all
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Use Cmd+J to snap to grid (ensures proper alignment)
        try await sendKeysWithModifiers("j", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Select last track (like Python implementation)
    private func selectLastTrack() async throws {
        print("Selecting last track...")
        
        // Like Python: logic.sendGlobalKey("down") for 5 times
        for i in 0..<5 {
            try await sendKeys("down")
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("Last track selection completed")
    }
    
    /// Open Import MIDI File dialog
    private func openImportDialog() async throws {
        log("Opening Import MIDI File dialog...")
        
        // Use Accessibility API to find and click menu item
        // Like Python: logic.menuItem("File", "Import", "MIDI File…").Press()
        try await clickMenuItem("File", "Import", "MIDI File…")
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds to wait for dialog
    }
    
    /// Click menu item using Accessibility API (simplified version)
    private func clickMenuItem(_ menuName: String, _ submenuName: String, _ itemName: String) async throws {
        log("Clicking menu item: \(menuName) -> \(submenuName) -> \(itemName)")
        
        // Try multiple times with reconnection
        for attempt in 1...3 {
            log("Attempt \(attempt) to access menu bar...")
            
            // Ensure Logic Pro is still connected
            setupLogicApp()
            
            guard let logicApp = logicApp else {
                log("Logic Pro not running, attempt \(attempt)")
                if attempt == 3 {
                    throw LogicError.appNotRunning
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }
            
            // Get menu bar
            var menuBar: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(logicApp, kAXMenuBarAttribute as CFString, &menuBar)
            
            if result == .success, let menuBar = menuBar {
                log("Successfully got menu bar on attempt \(attempt)")
                // Find and click the menu item
                try await findAndClickMenuItem(menuBar as! AXUIElement, [menuName, submenuName, itemName])
                log("Menu item clicked successfully")
                return
            } else {
                log("Failed to get menu bar on attempt \(attempt), result: \(result)")
                if attempt == 3 {
                    throw LogicError.menuOperationFailed("Could not access menu bar after 3 attempts")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    /// Recursively find and click menu item
    private func findAndClickMenuItem(_ element: AXUIElement, _ menuPath: [String]) async throws {
        guard !menuPath.isEmpty else { return }
        
        let currentMenuName = menuPath[0]
        let remainingPath = Array(menuPath.dropFirst())
        
        log("Looking for menu item: '\(currentMenuName)' in current element")
        
        // Get children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            throw LogicError.menuOperationFailed("Could not get menu children")
        }
        
        let childrenArray = children as! [AXUIElement]
        log("Found \(childrenArray.count) children in current element")
        
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
        print("filename is \(fileName)")
        for char in fileName {
            try await sendKeys(String(char))
            log("send: \(char)")
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await sendKeys("\n") // Press Enter
        try await Task.sleep(nanoseconds: 5000_000_000) // 0.5 seconds
    }
    
    /// Click Import button
    private func confirmImport() async throws {
        log("Pressing import...")
        
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
        
        // Ensure Logic Pro is active and ready
        try await activateLogic()
        log("Starting playback...")
        
        // Wait for Logic Pro to be ready
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Send space key to start playback
        log("Sending space key to start playback...")
        log("Space key code: \(getKeyCode(for: " "))")
        try await sendKeys(" ")
        
        log("Space key sent successfully")
        
        // Add a small delay after sending space key to ensure it's processed
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
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
        
        // Ensure Logic Pro is active and ready
        try await activateLogic()
        log("Stopping playback...")
        
        // Wait for Logic Pro to be ready
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Send space key to stop playback
        log("Sending space key to stop playback...")
        log("Space key code: \(getKeyCode(for: " "))")
        try await sendKeys(" ")
        
        log("Space key sent successfully")
        
        // Add a small delay after sending space key to ensure it's processed
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
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
        log("Creating new track with Cmd+T...")
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
        log("Creating new \(type) track...")
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
    
    // MARK: - Protocol Support Methods
    
    /// Select track by index (for protocol execution)
    func selectTrack(byIndex index: Int) async throws {
        try await selectTrackByIndex(index)
    }
    
    /// Create region with specified type and length
    func createRegion(type: String, length: Int) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Creating \(type) region with \(length) bars..."
        }
        
        try await activateLogic()
        
        // Use Cmd+R to create new region
        log("Creating \(type) region...")
        try await sendKeysWithModifiers("r", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Set region length if needed
        if length != 4 { // Default is 4 bars
            try await sendKeys(String(length))
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            try await sendKeys("\n")
        }
        
        await MainActor.run {
            currentStatus = "\(type) region created"
        }
    }
    
    /// Quantize region with specified grid and strength
    func quantizeRegion(grid: String, strength: Int) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Quantizing region with grid \(grid) and strength \(strength)%..."
        }
        
        try await activateLogic()
        
        // Use Cmd+Q to open quantize dialog
        log("Opening quantize dialog...")
        try await sendKeysWithModifiers("q", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Set grid value
        try await sendKeys(grid)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Set strength value
        try await sendKeys(String(strength))
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Apply quantization
        try await sendKeys("\n")
        
        await MainActor.run {
            currentStatus = "Region quantized"
        }
    }
    
    /// Move region to specified position
    func moveRegion(to position: CGPoint) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Moving region to position (\(position.x), \(position.y))..."
        }
        
        try await activateLogic()
        
        // Select region first
        try await sendKeysWithModifiers("a", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Move region (this would need more sophisticated implementation)
        log("Moving region to position (\(position.x), \(position.y))")
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Region moved"
        }
    }
    
    /// Resize region to specified size
    func resizeRegion(to size: CGSize) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Resizing region to size (\(size.width), \(size.height))..."
        }
        
        try await activateLogic()
        
        // Select region first
        try await sendKeysWithModifiers("a", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Resize region (this would need more sophisticated implementation)
        log("Resizing region to size (\(size.width), \(size.height))")
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Region resized"
        }
    }
    
    /// Import chords from specified folder
    func importChords(fromFolder folder: String, random: Bool) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Importing chords from folder '\(folder)'..."
        }
        
        try await activateLogic()
        
        // Use File > Import to open import dialog
        log("Opening import dialog...")
        try await sendKeysWithModifiers("i", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Navigate to folder (this would need more sophisticated implementation)
        log("Importing chords from folder '\(folder)', random: \(random)")
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Chords imported"
        }
    }
    
    /// Import MIDI file with optional track number
    func importMidi(filename: String, trackNumber: Int?) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Importing MIDI file '\(filename)'..."
        }
        
        try await activateLogic()
        
        // Use File > Import to open import dialog
        log("Opening import dialog...")
        try await sendKeysWithModifiers("i", modifiers: ["cmd"])
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Navigate to and select MIDI file (this would need more sophisticated implementation)
        log("Importing MIDI file '\(filename)'" + (trackNumber != nil ? " to track \(trackNumber!)" : ""))
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "MIDI file imported"
        }
    }
    
    /// Start playback from specific bar
    func startPlayback(fromBar bar: Int) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Starting playback from bar \(bar)..."
        }
        
        try await activateLogic()
        
        // Navigate to bar first
        try await navigateToBar(bar)
        
        // Start playback
        try await startPlayback()
        
        await MainActor.run {
            currentStatus = "Playback started from bar \(bar)"
        }
    }
    
    /// Start recording with optional track number
    func startRecording(trackNumber: Int? = nil) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Starting recording..."
        }
        
        try await activateLogic()
        
        // Select track if specified
        if let trackNumber = trackNumber {
            try await selectTrackByIndex(trackNumber)
        }
        
        // Start recording with R key
        log("Starting recording...")
        try await sendKeys("r")
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            currentStatus = "Recording started"
        }
    }
    
    /// Set region property
    func setRegionProperty(property: String, value: Any) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Setting region property '\(property)' to '\(value)'..."
        }
        
        try await activateLogic()
        
        // This would need more sophisticated implementation based on the property
        log("Setting region property '\(property)' to '\(value)'")
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Region property set"
        }
    }
    
    /// Apply effect to track
    func applyEffect(effect: String, trackNumber: Int?, preset: String?) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Applying effect '\(effect)'..."
        }
        
        try await activateLogic()
        
        // Select track if specified
        if let trackNumber = trackNumber {
            try await selectTrackByIndex(trackNumber)
        }
        
        // Apply effect (this would need more sophisticated implementation)
        log("Applying effect '\(effect)'" + (preset != nil ? " with preset '\(preset!)'" : ""))
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Effect applied"
        }
    }
    
    /// Set track property
    func setTrackProperty(property: String, value: Any, trackNumber: Int?) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Setting track property '\(property)' to '\(value)'..."
        }
        
        try await activateLogic()
        
        // Select track if specified
        if let trackNumber = trackNumber {
            try await selectTrackByIndex(trackNumber)
        }
        
        // Set property (this would need more sophisticated implementation)
        log("Setting track property '\(property)' to '\(value)'")
        // For now, just log the action
        
        await MainActor.run {
            currentStatus = "Track property set"
        }
    }
    
    /// Save project with optional filename
    func saveProject(as filename: String? = nil) async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Saving project..."
        }
        
        try await activateLogic()
        
        if let filename = filename {
            // Save as new file
            log("Saving project as '\(filename)'...")
            try await sendKeysWithModifiers("s", modifiers: ["cmd", "shift"])
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Type filename
            try await sendKeys(filename)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            try await sendKeys("\n")
        } else {
            // Save existing file
            log("Saving project...")
            try await sendKeysWithModifiers("s", modifiers: ["cmd"])
        }
        
        await MainActor.run {
            currentStatus = "Project saved"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Send keyboard input using CGEvent
    private func sendKeys(_ keys: String) async throws {
        log("Sending keys: '\(keys)' (length: \(keys.count))")
        
        for (index, char) in keys.enumerated() {
            let charString = String(char)
            let keyCode = getKeyCode(for: charString)
            log("Character \(index): '\(charString)' -> keyCode: \(keyCode)")
            
            if keyCode != 0 {
                // Key down
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                keyDownEvent?.post(tap: .cghidEventTap)
                log("Key down sent for '\(charString)'")
                
                // Delay for key down
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Key up
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                keyUpEvent?.post(tap: .cghidEventTap)
                log("Key up sent for '\(charString)'")
                
                // Delay between characters
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } else {
                log("Unknown key code for character '\(charString)'")
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
