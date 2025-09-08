//
//  AXMenuItemSelectedParser.swift
//  ProjectExplorer
//
//  Parser for AXMenuItemSelected events to extract selected menu item information
//

import Foundation
import ApplicationServices

struct MenuItemInfo {
    let title: String?
    let role: String?
    let roleDescription: String?
    let parentMenu: String?
    let position: CGPoint?
    let size: CGSize?
}

class AXMenuItemSelectedParser {
    
    /// Parse AXMenuItemSelected event to extract selected menu item information
    static func parse(_ event: [String: Any], element: AXUIElement? = nil) -> MenuItemInfo? {
        guard event["command"] as? String == "AXMenuItemSelected" else { return nil }
        
        // Debug: Print all element attributes for menu item selection
        if let element = element {
            print("🔍 Debugging Selected Menu Item:")
            AXElementDebugger.printAllElementAttributes(element, title: "Selected Menu Item")
        }
        
        // Extract basic information from event
        let title = event["AXTitle"] as? String
        let role = event["AXRole"] as? String
        let roleDescription = event["AXRoleDescription"] as? String
        
        // Parse position and size if available
        let position = parsePosition(from: event)
        let size = parseSize(from: event)
        
        // Try to get parent menu information
        let parentMenu = extractParentMenuInfo(from: event, element: element)
        
        return MenuItemInfo(
            title: title,
            role: role,
            roleDescription: roleDescription,
            parentMenu: parentMenu,
            position: position,
            size: size
        )
    }
    
    /// Generate human-readable description of the selected menu item
    static func generateDescription(_ menuItemInfo: MenuItemInfo) -> String {
        var description = "Selected menu item"
        
        if let title = menuItemInfo.title, !title.isEmpty {
            description += ": \(title)"
        } else {
            description += " (no title)"
        }
        
        if let parentMenu = menuItemInfo.parentMenu, !parentMenu.isEmpty {
            description += " from \(parentMenu)"
        }
        
        return description
    }
    
    // MARK: - Private Methods
    
    private static func parsePosition(from event: [String: Any]) -> CGPoint? {
        guard let positionString = event["AXPosition"] as? String else {
            return nil
        }
        
        // Parse: "<AXValue 0x6000010dc900> {value = x:327.000000 y:946.000000 type = kAXValueCGPointType}"
        let components = positionString.components(separatedBy: " ")
        let xComponent = components.first { $0.hasPrefix("x:") }
        let yComponent = components.first { $0.hasPrefix("y:") }
        
        let x = Double(xComponent?.dropFirst(2) ?? "0") ?? 0
        let y = Double(yComponent?.dropFirst(2) ?? "0") ?? 0
        
        return CGPoint(x: x, y: y)
    }
    
    private static func parseSize(from event: [String: Any]) -> CGSize? {
        guard let frameString = event["AXFrame"] as? String else {
            return nil
        }
        
        // Parse: "<AXValue 0x600000b96040> {value = x:327.000000 y:946.000000 w:250.000000 h:283.000000 type = kAXValueCGRectType}"
        let components = frameString.components(separatedBy: " ")
        let wComponent = components.first { $0.hasPrefix("w:") }
        let hComponent = components.first { $0.hasPrefix("h:") }
        
        let width = Double(wComponent?.dropFirst(2) ?? "0") ?? 0
        let height = Double(hComponent?.dropFirst(2) ?? "0") ?? 0
        
        return CGSize(width: width, height: height)
    }
    
    private static func extractParentMenuInfo(from event: [String: Any], element: AXUIElement?) -> String? {
        // Try to get parent menu information from the element
        if let element = element {
            var parentElement: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentElement)
            
            if result == .success, let parentElementRef = parentElement {
                // Try to get parent's title or description
                var parentTitle: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(parentElementRef as! AXUIElement, kAXTitleAttribute as CFString, &parentTitle)
                
                if titleResult == .success, let titleString = parentTitle as? String, !titleString.isEmpty {
                    return titleString
                }
                
                // Try to get parent's description
                var parentDescription: CFTypeRef?
                let descResult = AXUIElementCopyAttributeValue(parentElementRef as! AXUIElement, kAXDescriptionAttribute as CFString, &parentDescription)
                
                if descResult == .success, let descString = parentDescription as? String, !descString.isEmpty {
                    return descString
                }
            }
        }
        
        return nil
    }
}
