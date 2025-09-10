//
//  AXElementDebugger.swift
//  ProjectExplorer
//
//  Utility class for debugging AXUIElement attributes
//

import Foundation
import ApplicationServices

class AXElementDebugger {
    
    /// Print all attributes of an AXUIElement for debugging
    static func printAllElementAttributes(_ element: AXUIElement, title: String = "AXUIElement") {
        print("🔍 === \(title) Attributes Debug ===")
        
        // Get all attribute names
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let names = attributeNames as? [String] {
            print("📋 Available attributes (\(names.count)):")
            for (index, name) in names.enumerated() {
                print("  \(index + 1). \(name)")
                
                // Try to get the value for each attribute
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &value)
                
                if valueResult == .success {
                    if let stringValue = value as? String {
                        print("     Value: \"\(stringValue)\"")
                    } else if let numberValue = value as? NSNumber {
                        print("     Value: \(numberValue)")
                    } else if let boolValue = value as? Bool {
                        print("     Value: \(boolValue)")
                    } else if let arrayValue = value as? [Any] {
                        print("     Value: Array with \(arrayValue.count) items")
                    } else if let dictValue = value as? [String: Any] {
                        print("     Value: Dictionary with \(dictValue.count) keys")
                    } else {
                        print("     Value: \(type(of: value)) - \(String(describing: value))")
                    }
                } else {
                    print("     Value: Failed to get value (error: \(valueResult.rawValue))")
                }
            }
        } else {
            print("❌ Failed to get attribute names: \(result.rawValue)")
        }
        
        print("🔍 === End \(title) Attributes Debug ===")
    }
    
    /// Get all attributes as a dictionary for analysis
    static func getAllElementAttributes(_ element: AXUIElement) -> [String: Any] {
        // Get all attribute names
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        guard result == .success, let names = attributeNames as? [String] else {
            return [:]
        }
        
        var attributesDict: [String: Any] = [:]
        
        // Get values for all attributes
        for name in names {
            var value: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            
            if valueResult == .success {
                // Convert CFTypeRef to JSON-serializable types
                if let convertedValue = convertCFTypeToJSONSerializable(value) {
                    attributesDict[name] = convertedValue
                } else {
                    attributesDict[name] = "Unsupported type: \(type(of: value))"
                }
            } else {
                attributesDict[name] = "Error: \(valueResult.rawValue)"
            }
        }
        
        return attributesDict
    }
    
    /// Convert CFTypeRef to JSON-serializable types to avoid NSObject warnings
    private static func convertCFTypeToJSONSerializable(_ value: CFTypeRef?) -> Any? {
        guard let value = value else { return nil }
        
        // Handle basic types
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            // Convert NSNumber to basic types to avoid NSObject
            if CFNumberIsFloatType(numberValue) {
                return numberValue.doubleValue
            } else {
                return numberValue.int64Value
            }
        } else if let boolValue = value as? Bool {
            return boolValue
        } else if CFGetTypeID(value) == CFArrayGetTypeID() {
            // Convert CFArray to Swift Array
            let arrayValue = value as! CFArray
            let count = CFArrayGetCount(arrayValue)
            var swiftArray: [Any] = []
            for i in 0..<count {
                let item = CFArrayGetValueAtIndex(arrayValue, i)
                if let convertedItem = convertCFTypeToJSONSerializable(item as CFTypeRef) {
                    swiftArray.append(convertedItem)
                }
            }
            return swiftArray
        } else if CFGetTypeID(value) == CFDictionaryGetTypeID() {
            // Convert CFDictionary to Swift Dictionary
            let dictValue = value as! CFDictionary
            var swiftDict: [String: Any] = [:]
            let keyCount = CFDictionaryGetCount(dictValue)
            
            // Allocate arrays for keys and values
            let keys = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: keyCount)
            let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: keyCount)
            defer {
                keys.deallocate()
                values.deallocate()
            }
            
            CFDictionaryGetKeysAndValues(dictValue, keys, values)
            
            for i in 0..<keyCount {
                if let keyPtr = keys[i],
                   let valuePtr = values[i],
                   let key = Unmanaged<CFString>.fromOpaque(keyPtr).takeUnretainedValue() as String?,
                   let convertedValue = convertCFTypeToJSONSerializable(valuePtr as CFTypeRef) {
                    swiftDict[key] = convertedValue
                }
            }
            return swiftDict
        } else {
            // For other types, convert to string description
            return String(describing: value)
        }
    }
    
    /// Print attributes of a specific element with custom title
    static func debugElement(_ element: AXUIElement, title: String) {
        printAllElementAttributes(element, title: title)
    }
    
    /// Print attributes of title element if it exists
    static func debugTitleElement(_ element: AXUIElement) {
        var titleElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleUIElementAttribute as CFString, &titleElement)
        
        if result == .success, let titleElementRef = titleElement {
            printAllElementAttributes(titleElementRef as! AXUIElement, title: "Title Element")
        } else {
            print("❌ No title element found")
        }
    }
    
    /// Debug selected children elements
    static func debugSelectedChildren(_ element: AXUIElement) {
        var selectedChildren: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedChildrenAttribute as CFString, &selectedChildren)
        
        if result == .success, let childrenArray = selectedChildren as? [AXUIElement] {
            print("🔍 === Selected Children Debug ===")
            print("📊 Found \(childrenArray.count) selected children")
            
            for (index, child) in childrenArray.enumerated() {
                print("🔍 === Selected Child \(index + 1) ===")
                printAllElementAttributes(child, title: "Selected Child \(index + 1)")
            }
            
            print("🔍 === End Selected Children Debug ===")
        } else {
            print("❌ No selected children found or failed to get selected children (error: \(result.rawValue))")
        }
    }
    
    /// Get selected child information as string (recursive)
    static func getSelectedChild(_ element: AXUIElement, maxDepth: Int = 5, currentDepth: Int = 0) -> [String] {
        var selectedElements: [String] = []
        
        // Add indentation based on depth
        // let indent = String(repeating: "  ", count: currentDepth)
        
        // Get basic element information
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        var roleDescription: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        let roleDescriptionString = roleDescription as? String ?? "Unknown"
        
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String ?? "No Title"
        
        var description: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        let descriptionString = description as? String ?? "No Description"
        
        var isSelected: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedAttribute as CFString, &isSelected)
        let selectedString = isSelected as? Bool ?? false ? "Yes" : "No"
        
        // If this element is selected, add it to the results
        if selectedString == "Yes" {
            let elementInfo = "depth: \(currentDepth)📋 Role: \(roleString) | RoleDesc: \(roleDescriptionString) | Title: \(titleString) | Desc: \(descriptionString) | Selected: \(selectedString)"
            selectedElements.append(elementInfo)
        }
        
        // Recursively check children if we haven't reached max depth
        if currentDepth < maxDepth {
            var children: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            
            if result == .success, let childrenArray = children as? [AXUIElement] {
                for child in childrenArray {
                    let childSelectedElements = getSelectedChild(child, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                    selectedElements.append(contentsOf: childSelectedElements)
                }
            }
        }
        
        return selectedElements
    }
    
    /// Print attributes of parent element if it exists
    static func debugParentElement(_ element: AXUIElement) {
        var parentElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentElement)
        
        if result == .success, let parentElementRef = parentElement {
            printAllElementAttributes(parentElementRef as! AXUIElement, title: "Parent Element")
        } else {
            print("❌ No parent element found")
        }
    }
    
    /// Print attributes of top level element if it exists
    static func debugTopLevelElement(_ element: AXUIElement) {
        var topLevelElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTopLevelUIElementAttribute as CFString, &topLevelElement)
        
        if result == .success, let topLevelElementRef = topLevelElement {
            printAllElementAttributes(topLevelElementRef as! AXUIElement, title: "Top Level Element")
        } else {
            print("❌ No top level element found")
        }
    }
    
    /// Recursively print all children elements that are AXUIElement
    static func debugAllChildrenRecursively(_ element: AXUIElement, title: String = "Element", maxDepth: Int = 1, currentDepth: Int = 0) {
        // Add indentation based on depth
        let indent = String(repeating: "  ", count: currentDepth)
        
        // print("\(indent)🔍 === \(title) (Depth: \(currentDepth)) ===")
        
        // Get role information for display
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"
        
        // Get role description
        var roleDescription: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        let roleDescriptionString = roleDescription as? String ?? "Unknown"
        
        // Get additional element information for better debugging
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String ?? "No Title"
        
        var description: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        let descriptionString = description as? String ?? "No Description"
        
        var isSelected: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedAttribute as CFString, &isSelected)
        let selectedString = isSelected as? Bool ?? false ? "Yes" : "No"
        
        //if roleDescriptionString == "Track Background" {
            print("\(indent)📋 Role: \(roleString) | RoleDesc: \(roleDescriptionString) | Title: \(titleString) | Desc: \(descriptionString) | Selected: \(selectedString)")
        //}
        
        // printAllElementAttributes(element)
        // Get children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if descriptionString.starts(with: "Track 68") {
            //printAllElementAttributes(element)
        }
        
        if descriptionString.starts(with: "Track 69") {
            //printAllElementAttributes(element)
        }
        
        if result == .success, let childrenArray = children as? [AXUIElement] {
            //print("\(indent)👶 Children count: \(childrenArray.count)")
            
            // Recursively process children if we haven't reached max depth
            if currentDepth < maxDepth {
                for (index, child) in childrenArray.enumerated() {
                    let childTitle = "Child \(index + 1)"
                    debugAllChildrenRecursively(child, title: childTitle, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                }
            } else {
                //print("\(indent)⏹️ Max depth reached, not processing children further")
            }
        } else {
            //print("\(indent)❌ No children found or failed to get children")
        }
        
        //print("\(indent)🔍 === End \(title) (Depth: \(currentDepth)) ===")
    }
    
    /// Print all children elements with their attributes (non-recursive)
    static func debugAllChildren(_ element: AXUIElement, title: String = "Element") {
        print("🔍 === \(title) Children Debug ===")
        
        // Get children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let childrenArray = children as? [AXUIElement] {
            print("📋 Children count: \(childrenArray.count)")
            
            for (index, child) in childrenArray.enumerated() {
                print("\n👶 === Child \(index + 1) ===")
                printAllElementAttributes(child, title: "Child \(index + 1)")
            }
        } else {
            print("❌ No children found or failed to get children")
        }
        
        print("🔍 === End \(title) Children Debug ===")
    }
    
    /// Debug selected children if they exist
    static func getSelectedChildren(_ notification: String, _ element: AXUIElement) -> [String: Any]? {
        var selectedChildren: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedChildrenAttribute as CFString, &selectedChildren)
        
        var selected: [String] = []
        
        if result == .success, let childrenArray = selectedChildren as? [AXUIElement] {
            
            for (_, child) in childrenArray.enumerated() {
                var title: CFTypeRef?
                
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                
                let titleString = title as? String ?? "No Title"
                
                selected.append(titleString)
            }
            return ["selectedChildren": selected, "command": notification]
        } else {
            return nil
        }
    }
}
