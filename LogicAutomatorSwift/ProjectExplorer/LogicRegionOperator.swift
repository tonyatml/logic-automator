import Cocoa
import ApplicationServices

/// Logic area operator 
/// Based on macOS Accessibility API implementation
class LogicRegionOperator: ObservableObject {
    private var logicApp: AXUIElement?
    private let logicBundleID = "com.apple.logic10"
    
    @Published var isConnected = false
    @Published var currentStatus = "Not connected"
    
    // Callback functions
    var logCallback: ((String) -> Void)?
    
    init() {
        setupLogicApp()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        print(message)
        logCallback?(message)
    }
    
    // MARK: - Initialization
    
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
    
    // MARK: - Region Value Retrieval
    
    /// Get all region value attributes
    func getRegionValues(_ element: AXUIElement) async throws -> [String: Any] {
        log("Getting values for region element...")
        
        var values: [String: Any] = [:]
        
        // Get basic region properties
        values["volume"] = try await getRegionVolume(element)
        values["pan"] = try await getRegionPan(element)
        values["startTime"] = try await getRegionStartTime(element)
        values["endTime"] = try await getRegionEndTime(element)
        
        // Get MIDI-specific properties if applicable
        values["velocity"] = try await getRegionVelocity(element)
        values["pitch"] = try await getRegionPitch(element)
        
        // Get all other properties
        values["properties"] = try await getAllRegionProperties(element)
        
        log("Region values retrieval complete")
        return values
    }
    
    /// Get region volume
    private func getRegionVolume(_ element: AXUIElement) async throws -> Float {
        // Try multiple methods to get volume
        
        // Method 1: Get volume attribute directly
        if let volume = try await getAttributeValue(element, attribute: "AXValue") as? Float {
            return volume
        }
        
        // Method 2: Find volume slider in sub-elements
        if let volumeSlider = try await findVolumeSlider(in: element) {
            if let volume = try await getAttributeValue(volumeSlider, attribute: "AXValue") as? Float {
                return volume
            }
        }
        
        // Method 3: Get volume information from description
        if let volume = try await extractVolumeFromDescription(element) {
            return volume
        }
        
        return 0.0 // Default volume
    }
    
    /// Get region pan
    private func getRegionPan(_ element: AXUIElement) async throws -> Float {
        // Try multiple methods to get pan
        
        // Method 1: Get pan attribute directly
        if let pan = try await getAttributeValue(element, attribute: "AXValue") as? Float {
            return pan
        }
        
        // Method 2: Find pan slider in sub-elements
        if let panSlider = try await findPanSlider(in: element) {
            if let pan = try await getAttributeValue(panSlider, attribute: "AXValue") as? Float {
                return pan
            }
        }
        
        return 0.0 // Default pan (center)
    }
    
    /// Get region start time
    private func getRegionStartTime(_ element: AXUIElement) async throws -> TimeInterval {
        // Calculate start time based on position
        let position = try await getElementPosition(element)
        
        // Assume time axis ratio (adjust based on actual Logic Pro interface)
        let timePerPixel = 0.1 // 0.1 seconds per pixel
        return TimeInterval(position.x * timePerPixel)
    }
    
    /// Get region end time
    private func getRegionEndTime(_ element: AXUIElement) async throws -> TimeInterval {
        let startTime = try await getRegionStartTime(element)
        let size = try await getElementSize(element)
        
        // Calculate end time based on size
        let timePerPixel = 0.1 // 0.1 seconds per pixel
        return startTime + TimeInterval(size.width * timePerPixel)
    }
    
    /// Get region velocity
    private func getRegionVelocity(_ element: AXUIElement) async throws -> Int {
        // Try to get velocity attribute
        if let velocity = try await getAttributeValue(element, attribute: "AXValue") as? Int {
            return velocity
        }
        
        // Find velocity control in sub-elements
        if let velocityControl = try await findVelocityControl(in: element) {
            if let velocity = try await getAttributeValue(velocityControl, attribute: "AXValue") as? Int {
                return velocity
            }
        }
        
        return 64 // Default velocity (MIDI standard)
    }
    
    /// Get region pitch
    private func getRegionPitch(_ element: AXUIElement) async throws -> Int {
        // Try to get pitch attribute
        if let pitch = try await getAttributeValue(element, attribute: "AXValue") as? Int {
            return pitch
        }
        
        // Find pitch control in sub-elements
        if let pitchControl = try await findPitchControl(in: element) {
            if let pitch = try await getAttributeValue(pitchControl, attribute: "AXValue") as? Int {
                return pitch
            }
        }
        
        return 0 // Default pitch (no change)
    }
    
    /// Get all region properties
    private func getAllRegionProperties(_ element: AXUIElement) async throws -> [String: Any] {
        var properties: [String: Any] = [:]
        
        // Get all supported attributes
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let attributeNames = attributeNames {
            let namesArray = attributeNames as! [String]
            
            for attributeName in namesArray {
                if let value = try await getAttributeValue(element, attribute: attributeName) {
                    properties[attributeName] = value
                }
            }
        }
        
        return properties
    }
    
    // MARK: - Region Value Modification
    
    /// Set region volume
    func setRegionVolume(_ element: AXUIElement, volume: Float) async throws {
        log("Set region volume to \(volume)")
        
        // Method 1: Set volume attribute directly
        if try await setAttributeValue(element, attribute: "AXValue", value: volume) {
            log("Volume set successfully")
            return
        }
        
        // Method 2: Set volume by volume slider
        if let volumeSlider = try await findVolumeSlider(in: element) {
            if try await setAttributeValue(volumeSlider, attribute: "AXValue", value: volume) {
                log("Volume set successfully by volume slider")
                return
            }
        }
        
        // Method 3: Set volume by keyboard input
        try await setVolumeByKeyboard(element, volume: volume)
    }
    
    /// Set region pan
    func setRegionPan(_ element: AXUIElement, pan: Float) async throws {
        log("Set region pan to \(pan)")
        
        // Method 1: Set pan attribute directly
        if try await setAttributeValue(element, attribute: "AXValue", value: pan) {
            log("Pan set successfully")
            return
        }
        
        // Method 2: Set pan by pan slider
        if let panSlider = try await findPanSlider(in: element) {
            if try await setAttributeValue(panSlider, attribute: "AXValue", value: pan) {
                log("Pan set successfully by pan slider")
                return
            }
        }
        
        // Method 3: Set pan by keyboard input
        try await setPanByKeyboard(element, pan: pan)
    }
    
    /// Set region velocity
    func setRegionVelocity(_ element: AXUIElement, velocity: Int) async throws {
        log("Set region velocity to \(velocity)")
        
        // Method 1: Set velocity attribute directly
        if try await setAttributeValue(element, attribute: "AXValue", value: velocity) {
            log("Velocity set successfully")
            return
        }
        
        // Method 2: Set velocity by velocity control
        if let velocityControl = try await findVelocityControl(in: element) {
            if try await setAttributeValue(velocityControl, attribute: "AXValue", value: velocity) {
                log("Velocity set successfully by velocity control")
                return
            }
        }
        
        // Method 3: Set velocity by keyboard input
        try await setVelocityByKeyboard(element, velocity: velocity)
    }
    
    /// Set region pitch
    func setRegionPitch(_ element: AXUIElement, pitch: Int) async throws {
        log("Set region pitch to \(pitch)")
        
        // Method 1: Set pitch attribute directly
        if try await setAttributeValue(element, attribute: "AXValue", value: pitch) {
            log("Pitch set successfully")
            return
        }
        
        // Method 2: Set pitch by pitch control
        if let pitchControl = try await findPitchControl(in: element) {
            if try await setAttributeValue(pitchControl, attribute: "AXValue", value: pitch) {
                log("Pitch set successfully by pitch control")
                return
            }
        }
        
        // Method 3: Set pitch by keyboard input
        try await setPitchByKeyboard(element, pitch: pitch)
    }
    
    /// Move region to specified position
    func moveRegion(_ element: AXUIElement, to position: CGPoint) async throws {
        log("Move region to position \(position)")
        
        // Method 1: Set position attribute directly
        if try await setAttributeValue(element, attribute: "AXPosition", value: position) {
            log("Position set successfully")
            return
        }
        
        // Method 2: Drag operation
        try await dragRegion(element, to: position)
    }
    
    /// Resize region
    func resizeRegion(_ element: AXUIElement, to size: CGSize) async throws {
        log("Resize region to size \(size)")
        
        // Method 1: Set size attribute directly
        if try await setAttributeValue(element, attribute: "AXSize", value: size) {
            log("Size set successfully")
            return
        }
        
        // Method 2: Drag operation
        try await resizeRegionByDrag(element, to: size)
    }
    
    // MARK: - Helper Methods
    
    /// Get attribute value
    private func getAttributeValue(_ element: AXUIElement, attribute: String) async throws -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if result == .success, let value = value {
            return value
        }
        
        return nil
    }
    
    /// Set attribute value
    private func setAttributeValue(_ element: AXUIElement, attribute: String, value: Any) async throws -> Bool {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)
        return result == .success
    }
    
    /// Get element position
    private func getElementPosition(_ element: AXUIElement) async throws -> CGPoint {
        var position: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        
        if result == .success, let position = position {
            // Here we need to parse the actual AXValue structure
            // Simplified implementation
            return CGPoint.zero
        }
        
        return CGPoint.zero
    }
    
    /// Get element size
    private func getElementSize(_ element: AXUIElement) async throws -> CGSize {
        var size: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        if result == .success, let size = size {
            // Here we need to parse the actual AXValue structure
            // Simplified implementation
            return CGSize.zero
        }
        
        return CGSize.zero
    }
    
    /// Find volume slider
    private func findVolumeSlider(in element: AXUIElement) async throws -> AXUIElement? {
        return try await findElementWithDescription(in: element, description: "volume")
    }
    
    /// Find pan slider
    private func findPanSlider(in element: AXUIElement) async throws -> AXUIElement? {
        return try await findElementWithDescription(in: element, description: "pan")
    }
    
    /// Find velocity control
    private func findVelocityControl(in element: AXUIElement) async throws -> AXUIElement? {
        return try await findElementWithDescription(in: element, description: "velocity")
    }
    
    /// Find pitch control
    private func findPitchControl(in element: AXUIElement) async throws -> AXUIElement? {
        return try await findElementWithDescription(in: element, description: "pitch")
    }
    
    /// Find element with description
    private func findElementWithDescription(in element: AXUIElement, description: String) async throws -> AXUIElement? {
        // Recursive search for element with specific description
        return try await searchForElementWithDescription(in: element, description: description, maxDepth: 5)
    }
    
    /// Recursive search for element with specific description
    private func searchForElementWithDescription(in element: AXUIElement, description: String, maxDepth: Int) async throws -> AXUIElement? {
        guard maxDepth > 0 else { return nil }
        
        // Check current element's description
        var elementDescription: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &elementDescription)
        
        if descResult == .success, let elementDescription = elementDescription as? String {
            if elementDescription.lowercased().contains(description.lowercased()) {
                return element
            }
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                if let found = try await searchForElementWithDescription(in: child, description: description, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    /// Extract volume from description
    private func extractVolumeFromDescription(_ element: AXUIElement) async throws -> Float? {
        var description: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        if result == .success, let description = description as? String {
            // Try to extract volume value from description
            let pattern = "volume[\\s:]*([0-9.]+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: description.count)
                if let match = regex.firstMatch(in: description, options: [], range: range) {
                    let volumeString = (description as NSString).substring(with: match.range(at: 1))
                    return Float(volumeString)
                }
            }
        }
        
        return nil
    }
    
    /// Set volume by keyboard
    private func setVolumeByKeyboard(_ element: AXUIElement, volume: Float) async throws {
        // Double click element to activate
        try await doubleClickElement(element)
        
        // Wait for a while
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // Input volume value
        let volumeString = String(volume)
        try await sendKeys(volumeString)
        
        // Press Enter to confirm
        try await sendKeys("\n")
    }
    
    /// Set pan by keyboard
    private func setPanByKeyboard(_ element: AXUIElement, pan: Float) async throws {
        // Double click element to activate
        try await doubleClickElement(element)
        
        // Wait for a while
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Input pan value
        let panString = String(pan)
        try await sendKeys(panString)
        
        // Press Enter to confirm
        try await sendKeys("\n")
    }
    
    /// Set velocity by keyboard
    private func setVelocityByKeyboard(_ element: AXUIElement, velocity: Int) async throws {
        // Double click element to activate
        try await doubleClickElement(element)
        
        // Wait for a while
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // Input velocity value
        let velocityString = String(velocity)
        try await sendKeys(velocityString)
        
        // Press Enter to confirm
        try await sendKeys("\n")
    }
    
    /// Set pitch by keyboard
    private func setPitchByKeyboard(_ element: AXUIElement, pitch: Int) async throws {
        // Double click element to activate
        try await doubleClickElement(element)
        
        // Wait for a while
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // Input pitch value
        let pitchString = String(pitch)
        try await sendKeys(pitchString)
        
        // Press Enter to confirm
        try await sendKeys("\n")
    }
    
    /// Double click element
    private func doubleClickElement(_ element: AXUIElement) async throws {
        // Get element position
        let position = try await getElementPosition(element)
        
        // Create mouse event
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: position, mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: position, mouseButton: .left)
        
        // Send mouse event
        mouseDownEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        mouseUpEvent?.post(tap: .cghidEventTap)
        
        // Wait for a while
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        // Double click
        mouseDownEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
        mouseUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Drag region to specified position
    private func dragRegion(_ element: AXUIElement, to position: CGPoint) async throws {
        // Get element current position
        let currentPosition = try await getElementPosition(element)
        
        // Create drag event sequence
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPosition, mouseButton: .left)
        let mouseDragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: position, mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: position, mouseButton: .left)
        
        // Send drag event
        mouseDownEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        mouseDragEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        mouseUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Resize region by drag
    private func resizeRegionByDrag(_ element: AXUIElement, to size: CGSize) async throws {
        // Get element current position and size
        let currentPosition = try await getElementPosition(element)
        let currentSize = try await getElementSize(element)
        
        // Calculate drag target position (bottom right)
        let targetPosition = CGPoint(x: currentPosition.x + size.width, y: currentPosition.y + size.height)
        
        // Create drag event sequence
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: currentPosition.x + currentSize.width, y: currentPosition.y + currentSize.height), mouseButton: .left)
        let mouseDragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: targetPosition, mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: targetPosition, mouseButton: .left)
        
        // Send drag event
        mouseDownEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        mouseDragEvent?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        mouseUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Send keyboard input
    private func sendKeys(_ keys: String) async throws {
        for char in keys {
            let keyCode = getKeyCode(for: String(char))
            if keyCode != 0 {
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                
                keyDownEvent?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
                keyUpEvent?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
            }
        }
    }
    
    /// Get key code
    private func getKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        case "g": return 0x05
        case "h": return 0x04
        case "i": return 0x22
        case "j": return 0x26
        case "k": return 0x28
        case "l": return 0x25
        case "m": return 0x2E
        case "n": return 0x2D
        case "o": return 0x1F
        case "p": return 0x23
        case "q": return 0x0C
        case "r": return 0x0F
        case "s": return 0x01
        case "t": return 0x11
        case "u": return 0x20
        case "v": return 0x09
        case "w": return 0x0D
        case "x": return 0x07
        case "y": return 0x10
        case "z": return 0x06
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
        case ".": return 0x2F
        case "-": return 0x1B
        case "+": return 0x18
        case "return", "\n": return 0x24
        case "space", " ": return 0x31
        default: return 0
        }
    }
}

// MARK: - Data Model

/// Logic Pro region values
struct LogicRegionValues {
    var name: String = ""
    var type: LogicRegionType = .unknown
    var position: CGPoint = .zero
    var size: CGSize = .zero
    var volume: Float = 0.0
    var pan: Float = 0.0
    var startTime: TimeInterval = 0.0
    var endTime: TimeInterval = 0.0
    var length: TimeInterval = 0.0
    var velocity: Int = 64
    var pitch: Int = 0
    var properties: [String: Any] = [:]
}
