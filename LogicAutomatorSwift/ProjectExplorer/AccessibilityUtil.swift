import Cocoa
import ApplicationServices

/// Utility class for common accessibility operations
class AccessibilityUtil {
    
    // MARK: - Element Finding and Traversal
    
    /// Generic function to find elements by description or subrole
    static func findElementByDescriptionOrSubrole(in element: AXUIElement, 
                                                descriptionKeywords: [String] = [], 
                                                subroleKeywords: [String] = [], 
                                                elementName: String, 
                                                maxDepth: Int,
                                                logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        guard maxDepth > 0 else {
            throw AccessibilityError.elementNotFound("\(elementName) element not found")
        }
        
        // Check current element by description
        if !descriptionKeywords.isEmpty {
            var description: CFTypeRef?
            let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
            
            if descResult == .success, let description = description as? String {
                for keyword in descriptionKeywords {
                    if description.contains(keyword) {
                        logCallback?("Found \(elementName) element by description '\(keyword)' with maxDepth: \(maxDepth)")
                        return element
                    }
                }
            }
        }
        
        // Check current element by subrole
        if !subroleKeywords.isEmpty {
            var subrole: CFTypeRef?
            let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
            
            if subroleResult == .success, let subrole = subrole as? String {
                for keyword in subroleKeywords {
                    if subrole.contains(keyword) {
                        logCallback?("Found \(elementName) element by subrole '\(keyword)'")
                        return element
                    }
                }
            }
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                do {
                    return try await findElementByDescriptionOrSubrole(in: child, 
                                                                      descriptionKeywords: descriptionKeywords, 
                                                                      subroleKeywords: subroleKeywords, 
                                                                      elementName: elementName, 
                                                                      maxDepth: maxDepth - 1,
                                                                      logCallback: logCallback)
                } catch {
                    continue
                }
            }
        }
        
        throw AccessibilityError.elementNotFound("\(elementName) element not found")
    }
    
    /// Recursively find element with specific role
    static func findElementWithRole(in element: AXUIElement, role: String, maxDepth: Int, logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        guard maxDepth > 0 else {
            throw AccessibilityError.elementNotFound("Element with role \(role) not found")
        }
        
        // Check current element
        var currentRole: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &currentRole)
        
        if roleResult == .success, let currentRole = currentRole as? String, currentRole == role {
            return element
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                do {
                    return try await findElementWithRole(in: child, role: role, maxDepth: maxDepth - 1, logCallback: logCallback)
                } catch {
                    continue
                }
            }
        }
        
        throw AccessibilityError.elementNotFound("Element with role \(role) not found")
    }
    
    /// Find all child elements recursively
    static func findAllChildElements(in element: AXUIElement, maxDepth: Int) async throws -> [AXUIElement] {
        var allElements: [AXUIElement] = []
        
        if maxDepth <= 0 {
            return allElements
        }
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                allElements.append(child)
                let childElements = try await findAllChildElements(in: child, maxDepth: maxDepth - 1)
                allElements.append(contentsOf: childElements)
            }
        }
        
        return allElements
    }
    
    // MARK: - Element Properties
    
    /// Get element role
    static func getElementRole(_ element: AXUIElement) async throws -> String? {
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if roleResult == .success, let role = role as? String {
            return role
        }
        
        return nil
    }
    
    /// Get element role description
    static func getElementRoleDescription(_ element: AXUIElement) async throws -> String? {
        var roleDescription: CFTypeRef?
        let roleDescResult = AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        
        if roleDescResult == .success, let roleDescription = roleDescription as? String {
            return roleDescription
        }
        
        return nil
    }
    
    /// Get element description
    static func getElementDescription(_ element: AXUIElement) async throws -> String? {
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        if descResult == .success, let description = description as? String {
            return description
        }
        
        return nil
    }
    
    /// Get element title
    static func getElementTitle(_ element: AXUIElement) async throws -> String? {
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        if titleResult == .success, let title = title as? String {
            return title
        }
        
        return nil
    }
    
    /// Get element identifier
    static func getElementIdentifier(_ element: AXUIElement) async throws -> String? {
        var identifier: CFTypeRef?
        let idResult = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        
        if idResult == .success, let identifier = identifier as? String {
            return identifier
        }
        
        return nil
    }
    
    /// Get element subrole
    static func getElementSubrole(_ element: AXUIElement) async throws -> String? {
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        
        if subroleResult == .success, let subrole = subrole as? String {
            return subrole
        }
        
        return nil
    }
    
    /// Get element index
    static func getElementIndex(_ element: AXUIElement) async throws -> Int {
        var index: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXIndexAttribute as CFString, &index)
        
        if result == .success, let index = index as? Int {
            return index
        }
        
        return 0
    }
    
    /// Get all element attributes
    static func getAllElementAttributes(_ element: AXUIElement) async throws -> [String: Any] {
        var properties: [String: Any] = [:]
        
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let attributeNames = attributeNames {
            let namesArray = attributeNames as! [String]
            
            for attributeName in namesArray {
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, attributeName as CFString, &value)
                
                if valueResult == .success, let value = value {
                    properties[attributeName] = value
                }
            }
        }
        
        return properties
    }
    
    // MARK: - Element Geometry
    
    /// Get element position
    static func getElementPosition(_ element: AXUIElement) async throws -> CGPoint {
        var position: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        
        if result == .success, let position = position {
            if let point = try await extractPointFromAXValue(position) {
                return point
            }
        }
        
        return CGPoint.zero
    }
    
    /// Get element size
    static func getElementSize(_ element: AXUIElement) async throws -> CGSize {
        var size: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        if result == .success, let size = size {
            if let sizeValue = try await extractSizeFromAXValue(size) {
                return sizeValue
            }
        }
        
        return CGSize.zero
    }
    
    /// Extract point from AXValue
    private static func extractPointFromAXValue(_ value: CFTypeRef) async throws -> CGPoint? {
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            var point = CGPoint.zero
            let success = AXValueGetValue(axValue, .cgPoint, &point)
            if success {
                return point
            }
        }
        
        if let dict = value as? [String: Any] {
            if let x = dict["x"] as? CGFloat, let y = dict["y"] as? CGFloat {
                return CGPoint(x: x, y: y)
            }
        }
        
        if let description = value as? String {
            let pattern = #"\(([0-9.-]+),\s*([0-9.-]+)\)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                let xRange = Range(match.range(at: 1), in: description)!
                let yRange = Range(match.range(at: 2), in: description)!
                let x = CGFloat(Double(description[xRange]) ?? 0)
                let y = CGFloat(Double(description[yRange]) ?? 0)
                return CGPoint(x: x, y: y)
            }
        }
        
        return nil
    }
    
    /// Extract size from AXValue
    private static func extractSizeFromAXValue(_ value: CFTypeRef) async throws -> CGSize? {
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            var size = CGSize.zero
            let success = AXValueGetValue(axValue, .cgSize, &size)
            if success {
                return size
            }
        }
        
        if let dict = value as? [String: Any] {
            if let width = dict["width"] as? CGFloat, let height = dict["height"] as? CGFloat {
                return CGSize(width: width, height: height)
            }
        }
        
        if let description = value as? String {
            let pattern = #"\(([0-9.-]+),\s*([0-9.-]+)\)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                let widthRange = Range(match.range(at: 1), in: description)!
                let heightRange = Range(match.range(at: 2), in: description)!
                let width = CGFloat(Double(description[widthRange]) ?? 0)
                let height = CGFloat(Double(description[heightRange]) ?? 0)
                return CGSize(width: width, height: height)
            }
        }
        
        return nil
    }
    
    // MARK: - Element Actions
    
    /// Get available actions for an element
    static func getAvailableActions(_ element: AXUIElement) async throws -> [String] {
        var actions: CFArray?
        let actionsResult = AXUIElementCopyActionNames(element, &actions)
        
        if actionsResult == .success, let actions = actions {
            return actions as! [String]
        }
        
        return []
    }
    
    /// Perform action on element
    static func performAction(_ element: AXUIElement, action: String) async throws -> Bool {
        let result = AXUIElementPerformAction(element, action as CFString)
        return result == .success
    }
    
    /// Test all available actions on an element
    static func testAllActionsOnElement(_ element: AXUIElement, elementName: String, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("=== Testing all actions on \(elementName) ===")
        
        let actions = try await getAvailableActions(element)
        logCallback?("\(elementName) available actions: \(actions)")
        
        for action in actions {
            logCallback?("Trying \(elementName) action: \(action)")
            let result = try await performAction(element, action: action)
            logCallback?("\(elementName) action '\(action)' result: \(result)")
            
            if action == "AXShowMenu" {
                logCallback?("\(elementName) action '\(action)' might show menu/popup, attempting to dismiss...")
                try await dismissMenuOrPopup(logCallback: logCallback)
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    // MARK: - Text Finding
    
    /// Find text in child elements
    static func findTextInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                if let role = try await getElementRole(child), role == "AXStaticText" {
                    if let title = try await getElementTitle(child), !title.isEmpty {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find text in child elements recursively
    static func findTextInChildrenRecursively(_ element: AXUIElement, maxDepth: Int) async throws -> String? {
        if maxDepth <= 0 {
            return nil
        }
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                if let role = try await getElementRole(child) {
                    if role == "AXStaticText" || role == "AXTextField" {
                        if let title = try await getElementTitle(child), !title.isEmpty {
                            return title
                        }
                    }
                }
                
                if let childText = try await findTextInChildrenRecursively(child, maxDepth: maxDepth - 1) {
                    return childText
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Application and Window Management
    
    /// Get main window of an application
    static func getMainWindow(of app: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws -> AXUIElement {
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        
        guard result == .success, let windows = windows else {
            throw AccessibilityError.failedToGetWindows
        }
        
        let windowsArray = windows as! [AXUIElement]
        logCallback?("Found \(windowsArray.count) windows")
        
        for window in windowsArray {
            if let title = try await getElementTitle(window) {
                logCallback?("Window title: \(title)")
                if !title.contains("Untitled") && !title.contains("Logic Pro") && title.contains(".logicx") {
                    logCallback?("Found main project window: \(title)")
                    return window
                }
            }
        }
        
        if let firstWindow = windowsArray.first {
            logCallback?("Using first window as main window")
            return firstWindow
        }
        
        throw AccessibilityError.failedToGetWindows
    }
    
    /// Activate application
    static func activateApplication(_ app: AXUIElement, bundleID: String, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Activating application...")
        
        let result = AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, true as CFBoolean)
        logCallback?("AXUIElementSetAttributeValue frontmost result: \(result)")
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            let activateResult = targetApp.activate(options: [.activateIgnoringOtherApps])
            logCallback?("NSWorkspace activate result: \(activateResult)")
        }
    }
    
    /// Focus window
    static func focusWindow(_ window: AXUIElement, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Focusing window...")
        
        let mainResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, true as CFBoolean)
        logCallback?("Set main window result: \(mainResult)")
        
        let focusResult = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, true as CFBoolean)
        logCallback?("Set window focused result: \(focusResult)")
        
        let frontResult = AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, true as CFBoolean)
        logCallback?("Set window frontmost result: \(frontResult)")
    }
    
    // MARK: - Mouse and Keyboard Events
    
    /// Click at element position using mouse coordinates
    static func clickAtElementPosition(_ element: AXUIElement, elementName: String, logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Attempting to click at element position for: \(elementName)")
        
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        logCallback?("Element position: \(position), size: \(size)")
        
        if size.width > 10000 || size.height > 10000 || size.width < 0 || size.height < 0 {
            logCallback?("Element size appears corrupted, skipping mouse click")
            return
        }
        
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        
        logCallback?("Clicking at center point: (\(centerX), \(centerY))")
        
        if centerX < 0 || centerY < 0 || centerX > 10000 || centerY > 10000 {
            logCallback?("Calculated coordinates appear invalid, skipping mouse click")
            return
        }
        
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        
        mouseDownEvent?.flags = []
        mouseUpEvent?.flags = []
        
        mouseDownEvent?.post(tap: .cghidEventTap)
        mouseUpEvent?.post(tap: .cghidEventTap)
        
        logCallback?("Posted mouse click events at (\(centerX), \(centerY))")
    }
    
    /// Dismiss any open menus or popups
    static func dismissMenuOrPopup(logCallback: ((String) -> Void)? = nil) async throws {
        logCallback?("Attempting to dismiss any open menus or popups...")
        
        if let escapeEvent = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true) {
            escapeEvent.post(tap: .cghidEventTap)
            
            if let escapeUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) {
                escapeUpEvent.post(tap: .cghidEventTap)
            }
            
            logCallback?("Posted Escape key events")
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Debugging and Logging
    
    /// Print element role information
    static func printElementRoleInfo(_ element: AXUIElement, elementName: String, logCallback: ((String) -> Void)? = nil) async throws {
        let role = try await getElementRole(element) ?? "nil"
        let roleDescription = try await getElementRoleDescription(element) ?? "nil"
        let description = try await getElementDescription(element) ?? "nil"
        
        logCallback?("\(elementName) - AXRole: \(role), AXRoleDescription: \(roleDescription), AXDescription: \(description)")
    }
    
    /// Print all element attributes
    static func printElementAttributes(_ element: AXUIElement, prefix: String = "", logCallback: ((String) -> Void)? = nil) async throws {
        let attributes = try await getAllElementAttributes(element)
        
        for (attributeName, value) in attributes {
            let valueString = String(describing: value)
            logCallback?("\(prefix)\(attributeName): \(valueString)")
        }
        
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if childrenResult == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            logCallback?("\(prefix)Children count: \(childrenArray.count)")
        }
    }
}

// MARK: - Accessibility Errors

enum AccessibilityError: Error {
    case elementNotFound(String)
    case failedToGetWindows
    case invalidElement
    case actionFailed(String)
}
