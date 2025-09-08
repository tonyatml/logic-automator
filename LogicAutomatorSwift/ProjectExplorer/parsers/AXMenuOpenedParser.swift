//
//  AXMenuOpenedParser.swift
//  ProjectExplorer
//
//  Parser for AXMenuOpened events to extract menu title and parent context
//

import Foundation
import ApplicationServices

struct MenuInfo {
    let title: String?
    let parentTitle: String?
    let itemCount: Int
    let visibleItemCount: Int
    let position: CGPoint
    let size: CGSize
    let menuType: String
}

class AXMenuOpenedParser {
    
    /// Parse AXMenuOpened event to extract high-level menu information
    static func parse(_ event: [String: Any], element: AXUIElement? = nil) -> MenuInfo? {
        guard event["command"] as? String == "AXMenuOpened" else { return nil }
        
        // Debug: Print title element attributes if we have the element
        if let element = element {
            //print("🔍 Debugging Title Element:")
            //AXElementDebugger.debugTitleElement(element)
            
            //print("🔍 Debugging Top Level Element:")
            //AXElementDebugger.debugTopLevelElement(element)
        }
        
        // Extract basic information
        let children = event["AXChildren"] as? [String] ?? []
        let visibleChildren = event["AXVisibleChildren"] as? [String] ?? []
        let itemCount = children.count
        let visibleItemCount = visibleChildren.count
        
        // Parse position and size
        let position = parsePosition(from: event)
        let size = parseSize(from: event)
        
        // Determine menu type based on size and item count
        let menuType = determineMenuType(size: size, itemCount: itemCount)
        
        // Try to get menu title and parent title
        let title = extractMenuTitle(from: event, element: element)
        let parentTitle = extractParentTitle(from: event)
        
        return MenuInfo(
            title: title,
            parentTitle: parentTitle,
            itemCount: itemCount,
            visibleItemCount: visibleItemCount,
            position: position,
            size: size,
            menuType: menuType
        )
    }
    
    /// Generate human-readable description of the menu
    static func generateDescription(_ menuInfo: MenuInfo) -> String {
        var description = "Opened "
        
        // Add menu type
        description += menuInfo.menuType
        
        // Add title if available
        if let title = menuInfo.title, !title.isEmpty {
            description += ": \(title)"
        }
        
        // Add item count
        if menuInfo.itemCount > 0 {
            description += " (\(menuInfo.itemCount) items"
            if menuInfo.visibleItemCount != menuInfo.itemCount {
                description += ", \(menuInfo.visibleItemCount) visible"
            }
            description += ")"
        }
        
        // Add parent context if available
        if let parentTitle = menuInfo.parentTitle, !parentTitle.isEmpty {
            description += " from \(parentTitle)"
        }
        
        return description
    }
    
    // MARK: - Private Methods
    
    private static func parsePosition(from event: [String: Any]) -> CGPoint {
        guard let positionString = event["AXPosition"] as? String else {
            return CGPoint.zero
        }
        
        // Parse: "<AXValue 0x6000010dc900> {value = x:327.000000 y:946.000000 type = kAXValueCGPointType}"
        let components = positionString.components(separatedBy: " ")
        let xComponent = components.first { $0.hasPrefix("x:") }
        let yComponent = components.first { $0.hasPrefix("y:") }
        
        let x = Double(xComponent?.dropFirst(2) ?? "0") ?? 0
        let y = Double(yComponent?.dropFirst(2) ?? "0") ?? 0
        
        return CGPoint(x: x, y: y)
    }
    
    private static func parseSize(from event: [String: Any]) -> CGSize {
        guard let frameString = event["AXFrame"] as? String else {
            return CGSize.zero
        }
        
        // Parse: "<AXValue 0x600000b96040> {value = x:327.000000 y:946.000000 w:250.000000 h:283.000000 type = kAXValueCGRectType}"
        let components = frameString.components(separatedBy: " ")
        let wComponent = components.first { $0.hasPrefix("w:") }
        let hComponent = components.first { $0.hasPrefix("h:") }
        
        let width = Double(wComponent?.dropFirst(2) ?? "0") ?? 0
        let height = Double(hComponent?.dropFirst(2) ?? "0") ?? 0
        
        return CGSize(width: width, height: height)
    }
    
    private static func determineMenuType(size: CGSize, itemCount: Int) -> String {
        if size.width > 300 && size.height > 300 {
            return "Large Context Menu"
        } else if size.width < 150 && size.height < 150 {
            return "Small Menu"
        } else if itemCount > 15 {
            return "Large Menu"
        } else if itemCount > 8 {
            return "Context Menu"
        } else {
            return "Menu"
        }
    }
    
    private static func extractMenuTitle(from event: [String: Any], element: AXUIElement? = nil) -> String? {
        
        // Try to get description from AXDescription attribute
        if let description = event["AXDescription"] as? String, !description.isEmpty {
            return description
        }
        
        // Try to query the title element directly if we have the AXUIElement
        if let element = element {
            if let titleFromElement = queryTitleFromElement(element) {
                return titleFromElement
            }
        }
        
        // Try to extract title from AXTitleUIElement reference
        if let titleFromElement = extractMenuTitleFromElement(event) {
            return titleFromElement
        }
        
        // Fallback to generic title
        return "Context Menu"
    }
    
    /// Query the title element directly from the menu element
    private static func queryTitleFromElement(_ element: AXUIElement) -> String? {
        // Try to get the title element reference
        var titleElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleUIElementAttribute as CFString, &titleElement)
        
        if result == .success, let titleElementRef = titleElement {
            
            // Query the title element for its title
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(titleElementRef as! AXUIElement, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let titleString = title as? String, !titleString.isEmpty {
                print("🔍 Found menu title from element: \(titleString)")
                return titleString
            }
            
            // Try to get description if title is not available
            var description: CFTypeRef?
            let descResult = AXUIElementCopyAttributeValue(titleElementRef as! AXUIElement, kAXDescriptionAttribute as CFString, &description)
            
            if descResult == .success, let descString = description as? String, !descString.isEmpty {
                print("🔍 Found menu description from element: \(descString)")
                return descString
            }
        }
        
        return nil
    }
    
    /// Extract menu title by querying the AXTitleUIElement reference
    private static func extractMenuTitleFromElement(_ event: [String: Any]) -> String? {
        // Check if there's a title element reference
        guard let titleElementString = event["AXTitleUIElement"] as? String else {
            return nil
        }
        
        // Parse the element reference to get the memory address
        // Format: "<AXUIElement 0x600003f807e0> {pid=14064}"
        if let addressRange = titleElementString.range(of: "0x") {
            let addressString = String(titleElementString[addressRange.lowerBound...])
            if let addressEnd = addressString.firstIndex(of: ">") {
                let address = String(addressString[..<addressEnd])
                print("🔍 Found title element address: \(address)")
                
                // Note: In a real implementation, we would need to:
                // 1. Convert the address string back to an AXUIElement
                // 2. Query the element for its AXTitle or AXDescription
                // 3. Return the actual title
                
                // For now, we'll return a placeholder indicating we found the reference
                return "Title Element Found"
            }
        }
        
        return nil
    }
    
    private static func extractParentTitle(from event: [String: Any]) -> String? {
        // Check if there's a parent element reference
        if let parentElement = event["AXParent"] as? String {
            // This is a reference to the parent element
            // We could potentially query this element to get its title
            // For now, we'll use the position to infer context
            
            let position = parsePosition(from: event)
            
            // Infer parent context based on position
            if position.y > 800 {
                return "Bottom Area"
            } else if position.y < 200 {
                return "Top Area"
            } else if position.x < 200 {
                return "Left Side"
            } else if position.x > 1000 {
                return "Right Side"
            } else {
                return "Main Area"
            }
        }
        
        return nil
    }
}

// MARK: - Test Data

/*
 Test data from user:
 {
   "AXEnabled" : 1,
   "sessionTimestamp" : 1757310566.2104311,
   "AXChildren" : [
     "0x00006000010dc930",
     "0x00006000010dc8d0",
     "0x00006000010dc990",
     "0x00006000010dcb70",
     "0x00006000010dcea0",
     "0x00006000010dcae0",
     "0x00006000010dd110",
     "0x00006000010dcc90",
     "0x00006000010dd140",
     "0x00006000010dd050",
     "0x00006000010dcb10",
     "0x00006000010dcd80",
     "0x00006000010dcdb0",
     "0x00006000010dce40",
     "0x00006000010dcd50",
     "0x00006000010dcd20"
   ],
   "AXVisibleChildren" : [
     "0x00006000010dcd20",
     "0x00006000010dcd50",
     "0x00006000010dce40",
     "0x00006000010dcdb0",
     "0x00006000010dcd80",
     "0x00006000010dd050",
     "0x00006000010dd140",
     "0x00006000010dcb10",
     "0x00006000010dcc90",
     "0x00006000010dd110",
     "0x00006000010dcae0",
     "0x00006000010dcea0",
     "0x00006000010dcb70",
     "0x00006000010dc990",
     "0x00006000010dc8d0"
   ],
   "AXParent" : "<AXUIElement 0x6000010dc900> {pid=14064}",
   "AXSelectedChildren" : [],
   "AXTopLevelUIElement" : "<AXUIElement 0x6000010dc900> {pid=14064}",
   "AXTitleUIElement" : "<AXUIElement 0x6000010dc900> {pid=14064}",
   "AXPosition" : "<AXValue 0x6000010dc900> {value = x:327.000000 y:946.000000 type = kAXValueCGPointType}",
   "AXFrame" : "<AXValue 0x600000b96040> {value = x:327.000000 y:946.000000 w:250.000000 h:283.000000 type = kAXValueCGRectType}",
   "command" : "AXMenuOpened",
   "relativeTime" : 7.5980241298675537,
   "AXSize" : "<AXValue 0x6000010dc900> {value = w:250.000000 h:283.000000 type = kAXValueCGSizeType}",
   "AXRole" : "AXMenu"
 }
 
 Expected output: "Opened Context Menu (16 items) from Bottom Area"
 */
