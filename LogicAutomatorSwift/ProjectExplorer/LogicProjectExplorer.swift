import Cocoa
import ApplicationServices

/// Logic Pro Project Explorer - For traversing and operating Logic Pro projects
/// Based on macOS Accessibility API implementation
class LogicProjectExplorer: ObservableObject {
    private var logicApp: AXUIElement?
    private let logicBundleID = "com.apple.logic10"
    
    @Published var isConnected = false
    @Published var currentStatus = "Not connected"
    @Published var tracks: [LogicTrack] = []
    @Published var regions: [LogicRegion] = []
    
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
    
    // MARK: - Project Exploration Core Functions
    
    /// Explore entire Logic Pro project
    func exploreProject() async throws {
        guard logicApp != nil else {
            throw LogicError.appNotRunning
        }
        
        await MainActor.run {
            currentStatus = "Exploring project..."
            tracks.removeAll()
            regions.removeAll()
        }
        
        log("Starting Logic Pro project exploration...")
        
        // 1. Get main window
        let mainWindow = try await getMainWindow()
        log("1. Found main window")
        
        // 2. Explore track list
        let trackList = try await findTrackList(in: mainWindow)
        log("2. Found track list: \(trackList)")
        
        // 3. Traverse all tracks
        let discoveredTracks = try await exploreTracks(in: trackList, mainWindow: mainWindow)
        await MainActor.run {
            self.tracks = discoveredTracks
        }
        log("Discovered \(discoveredTracks.count) tracks")
        tracks.forEach { print($0) }
        
        // Test: Click all tracks one by one
        if !discoveredTracks.isEmpty {
            log("Testing: Clicking all \(discoveredTracks.count) tracks...")
            
            // First, make sure Logic Pro is active
            try await activateLogicPro()
            
            // Wait a moment for the window to become active
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Click each track
            for (index, track) in discoveredTracks.enumerated() {
                log("=== Testing Track \(index + 1)/\(discoveredTracks.count): \(track.name) ===")
                try await clickTrack(track)
                
                // Rest for 1 second between tracks
                if index < discoveredTracks.count - 1 {
                    log("Resting for 1 second before next track...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
            
            log("Finished testing all tracks")
        }
        
        // 3. Explore ALL region lists in the window
        // log("=== Starting comprehensive Region exploration ===")
        // let allRegionLists = try await findAllRegionListElements(in: mainWindow, maxDepth: 15)
        
        var allDiscoveredRegions: [LogicRegion] = []
        
//        for (index, regionList) in allRegionLists.enumerated() {
//            log("=== Exploring Region List \(index + 1) ===")
//            
//            // First, print the attributes of this Region List element itself
//            log("Region List \(index + 1) attributes:")
//            try await printElementAttributes(regionList, prefix: "  ")
//            
//            // Then explore it for regions
//            let discoveredRegions = try await exploreRegionsFromList(regionList)
//            allDiscoveredRegions.append(contentsOf: discoveredRegions)
//            log("Region List \(index + 1) contained \(discoveredRegions.count) regions")
//        }
        
        await MainActor.run {
            self.regions = allDiscoveredRegions
        }
        log("Total regions discovered from all lists: \(allDiscoveredRegions.count)")
        
        // 4. Traverse all tracks
        //let discoveredTracks = try await exploreTracks(in: trackList, mainWindow: mainWindow)
        await MainActor.run {
        //    self.tracks = discoveredTracks
        }
        //log("Discovered \(discoveredTracks.count) tracks")
        
        // 5. Explore regions in each track (currently disabled)
        // var allRegions: [LogicRegion] = []
        // for track in discoveredTracks {
        //     let trackRegions = try await exploreRegions(in: track)
        //     allRegions.append(contentsOf: trackRegions)
        // }
        
        // Update status with discovered regions
        await MainActor.run {
            self.currentStatus = "Project exploration complete - 0 tracks, \(self.regions.count) regions"
        }
        
        log("Project exploration complete")
    }
    
    /// Get Logic Pro main window
    private func getMainWindow() async throws -> AXUIElement {
        guard let logicApp = logicApp else {
            throw LogicError.appNotRunning
        }
        
        // Get all windows
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(logicApp, kAXWindowsAttribute as CFString, &windows)
        
        guard result == .success, let windows = windows else {
            throw LogicError.failedToGetWindows
        }
        
        let windowsArray = windows as! [AXUIElement]
        log("Found \(windowsArray.count) windows")
        
        // Find main project window (usually title contains project name)
        for window in windowsArray {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let title = title as? String {
                log("Window title: \(title)")
                // Main project window usually doesn't contain "Untitled" or "Logic Pro"
                if !title.contains("Untitled") && !title.contains("Logic Pro") && title.contains(".logicx") {
                    log("Found main project window: \(title)")
                    return window
                }
            }
        }
        
        // If no specific window found, return first window
        if let firstWindow = windowsArray.first {
            log("Using first window as main window")
            return firstWindow
        }
        
        throw LogicError.failedToGetWindows
    }
    
    /// Find track list in window
    private func findTrackList(in window: AXUIElement) async throws -> AXUIElement {
        log("Finding track list in window...")
        
        // Based on Accessibility Inspector, look for the "Tracks contents (group)" element
        // which contains the actual track elements
        return try await findTracksContentsElement(in: window, maxDepth: 10)
    }
    
    /// Find region list in window
    private func findRegionList(in window: AXUIElement) async throws -> AXUIElement? {
        log("Finding region list in window...")
        
        // Based on Accessibility Inspector, look for region-related elements
        // Regions might be in a different container than tracks
        let regionList = try await findRegionListElement(in: window, maxDepth: 10)
        
        if regionList != nil {
            log("Found region list element")
        } else {
            log("No dedicated region list found, regions might be mixed with tracks")
        }
        
        return regionList
    }
    
    /// Find the "Tracks contents" element that contains the actual tracks
    private func findTracksContentsElement(in element: AXUIElement, maxDepth: Int) async throws -> AXUIElement {
        guard maxDepth > 0 else {
            throw LogicError.elementNotFound("Tracks contents element not found")
        }
        
        // Check current element
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        if descResult == .success, let description = description as? String {
            if description.contains("Tracks contents") {
                log("Found Tracks contents element with maxDepth: \(maxDepth)")
                return element
            }
        }
        
        // Also check for the specific class name from Accessibility Inspector
        var className: CFTypeRef?
        let classResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &className)
        
        if classResult == .success, let className = className as? String {
            if className.contains("ArrangeContentsSectionView") {
                log("Found ArrangeContentsSectionView element")
                return element
            }
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                do {
                    return try await findTracksContentsElement(in: child, maxDepth: maxDepth - 1)
                } catch {
                    continue
                }
            }
        }
        
        throw LogicError.elementNotFound("Tracks contents element not found")
    }
    
    /// Find the region list element that contains regions
    private func findRegionListElement(in element: AXUIElement, maxDepth: Int) async throws -> AXUIElement? {
        if maxDepth <= 0 {
            return nil
        }
        
        // Check if this element is a region list element
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        if descResult == .success, let description = description as? String, !description.isEmpty {
            // Look for region-related descriptions
            if description.contains("Regions") || description.contains("Region") || description.contains("Arrangement") {
                log("Found potential region list: '\(description)'")
                return element
            }
        }
        
        // Check role for region-related containers
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if roleResult == .success, let role = role as? String {
            if role == "AXGroup" || role == "AXList" || role == "AXLayoutArea" {
                // Check if this group contains regions
                var children: CFTypeRef?
                let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
                
                if childrenResult == .success, let children = children {
                    let childrenArray = children as! [AXUIElement]
                    // Check if any child looks like a region
                    for child in childrenArray {
                        if try await isIndependentRegion(child) {
                            log("Found region list element with regions")
                            return element
                        }
                    }
                }
            }
        }
        
        // Get children and recursively search
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            for child in childrenArray {
                if let regionList = try await findRegionListElement(in: child, maxDepth: maxDepth - 1) {
                    return regionList
                }
            }
        }
        
        return nil
    }
    
    /// Find ALL region list elements in the window
    private func findAllRegionListElements(in window: AXUIElement, maxDepth: Int) async throws -> [AXUIElement] {
        var regionLists: [AXUIElement] = []
        
        // First, try to find the parent of the "Tracks contents" element
        let tracksContents = try await findTracksContentsElement(in: window, maxDepth: 10)
        
        // Get the parent of Tracks contents
        var parent: CFTypeRef?
        let parentResult = AXUIElementCopyAttributeValue(tracksContents, kAXParentAttribute as CFString, &parent)
        
        if parentResult == .success, let parent = parent {
            let parentElement = parent as! AXUIElement
            log("Found parent of Tracks contents, searching for ALL region-related elements...")
            
            // Search for ALL region containers in the parent's children
            let allRegionContainers = try await findAllRegionContainersInSiblings(parentElement, tracksContents)
            regionLists.append(contentsOf: allRegionContainers)
        }
        
        // Also search the entire window for any other region containers
        let windowRegionContainers = try await findRegionContainersInElement(window, maxDepth: maxDepth)
        regionLists.append(contentsOf: windowRegionContainers)
        
        log("Found \(regionLists.count) total region list elements")
        return regionLists
    }
    
    /// Find all region containers in sibling elements of Tracks contents
    private func findAllRegionContainersInSiblings(_ parent: AXUIElement, _ tracksContents: AXUIElement) async throws -> [AXUIElement] {
        var regionContainers: [AXUIElement] = []
        
        // Get all children of the parent
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            log("Parent has \(childrenArray.count) children, searching for ALL region-related elements...")
            
            for (index, child) in childrenArray.enumerated() {
                // Skip the Tracks contents element itself
                if child == tracksContents {
                    log("Skipping Tracks contents element (index \(index))")
                    continue
                }
                
                // Check if this sibling element contains regions
                log("Analyzing sibling element \(index)...")
                let childRegions = try await findRegionElementsInElement(child, maxDepth: 8)
                if !childRegions.isEmpty {
                    log("Sibling element \(index) contains \(childRegions.count) regions - adding as region container")
                    regionContainers.append(child)
                }
            }
        }
        
        return regionContainers
    }
    
    /// Find region containers recursively in a specific element
    private func findRegionContainersInElement(_ element: AXUIElement, maxDepth: Int) async throws -> [AXUIElement] {
        var containers: [AXUIElement] = []
        
        if maxDepth <= 0 {
            return containers
        }
        
        // Check if this element contains regions
        let regions = try await findRegionElementsInElement(element, maxDepth: 3)
        if !regions.isEmpty {
            containers.append(element)
        }
        
        // Get children and recursively search
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            for child in childrenArray {
                let childContainers = try await findRegionContainersInElement(child, maxDepth: maxDepth - 1)
                containers.append(contentsOf: childContainers)
                }
            }
        
        return containers
    }
    
    /// Print all attributes of an element for debugging
    private func printElementAttributes(_ element: AXUIElement, prefix: String = "") async throws {
        // Get all supported attributes
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributeNames)
        
        if result == .success, let attributeNames = attributeNames {
            let namesArray = attributeNames as! [String]
            
            for attributeName in namesArray {
                var value: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(element, attributeName as CFString, &value)
                
                if valueResult == .success, let value = value {
                    let valueString = String(describing: value)
                    log("\(prefix)\(attributeName): \(valueString)")
                } else {
                    log("\(prefix)\(attributeName): <error>")
                }
            }
        } else {
            log("\(prefix)<unable to get attribute names>")
        }
        
        // Also print children count
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if childrenResult == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            log("\(prefix)Children count: \(childrenArray.count)")
        }
    }
    
    /// Explore regions from a dedicated region list
    private func exploreRegionsFromList(_ regionList: AXUIElement) async throws -> [LogicRegion] {
        log("Exploring regions from region list...")
        
        var regions: [LogicRegion] = []
        
        // Get all children of the region list
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(regionList, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            log("Unable to get children of region list")
            return regions
        }
        
        let childrenArray = children as! [AXUIElement]
        log("Region list contains \(childrenArray.count) child elements")
        
        // Analyze each child element to find regions
        for (index, child) in childrenArray.enumerated() {
            if let region = try await analyzeRegionElement(child, index: index) {
                regions.append(region)
                log("Discovered region \(index): \(region.name)")
            } else {
                log("Element \(index) not recognized as region")
            }
        }
        
        log("Total regions discovered: \(regions.count)")
        return regions
    }
    
    /// Analyze a single region element
    private func analyzeRegionElement(_ element: AXUIElement, index: Int) async throws -> LogicRegion? {
        // Check if this element is actually a region
        if !(try await isIndependentRegion(element)) {
            return nil
        }
        
        // Get region name
        let name = try await getRegionName(from: element)
        
        // Get region type
        let regionType = try await getRegionType(from: element)
        
        // Get region properties
        let properties = try await getRegionProperties(from: element)
        
        // Get region position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        return LogicRegion(
            trackIndex: 0, // Default track index for independent regions
            regionIndex: index,
            name: name,
            type: regionType,
            properties: properties,
            position: position,
            size: size,
            element: element
        )
    }
    
    /// Get region name from element
    private func getRegionName(from element: AXUIElement) async throws -> String {
        // Try multiple methods to get region name
        
        // Method 1: Get title directly
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        if titleResult == .success, let title = title as? String, !title.isEmpty {
            return title
        }
        
        // Method 2: Get description
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        if descResult == .success, let description = description as? String, !description.isEmpty {
            return description
        }
        
        // Method 3: Default name
        return "Region"
    }
    
    /// Get region type from element
    private func getRegionType(from element: AXUIElement) async throws -> LogicRegionType {
        // For now, return a default type
        // TODO: Implement actual region type detection
        return .audio
    }
    
    /// Get region properties from element
    private func getRegionProperties(from element: AXUIElement) async throws -> [String: String] {
        var properties: [String: String] = [:]
        
        // Get basic attributes
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if roleResult == .success, let role = role as? String {
            properties["role"] = role
        }
        
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        if subroleResult == .success, let subrole = subrole as? String {
            properties["subrole"] = subrole
        }
        
        var identifier: CFTypeRef?
        let idResult = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        if idResult == .success, let identifier = identifier as? String {
            properties["identifier"] = identifier
        }
        
        return properties
    }
    
    /// Explore all tracks in track list
    private func exploreTracks(in trackList: AXUIElement, mainWindow: AXUIElement) async throws -> [LogicTrack] {
        log("Exploring track list...")
        
        var tracks: [LogicTrack] = []
        
        // Get child elements of track list
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(trackList, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let children = children else {
            log("Unable to get child elements of track list")
            return tracks
        }
        
        let childrenArray = children as! [AXUIElement]
        log("Track list contains \(childrenArray.count) child elements")
        
        // Debug: Print detailed information about each child element
        log("=== DEBUG: Analyzing all child elements ===")
        for (index, child) in childrenArray.enumerated() {
            // await printElementDetails(child, index: index)
        }
        log("=== End of child element analysis ===")
        
        // Now independently explore for regions in the entire window
        log("=== Starting independent Region exploration ===")
        try await exploreRegionsIndependently(in: mainWindow)
        
        // Traverse each child element, look for tracks
        for (index, child) in childrenArray.enumerated() {
            if let track = try await analyzeTrackElement(child, index: index) {
                tracks.append(track)
                log("Discovered track \(index): \(track.name) (Type: \(track.type.rawValue))")
            } else {
                log("Element \(index) not recognized as track")
            }
        }
        
        return tracks
    }
    
    /// Print detailed information about an element for debugging
    private func printElementDetails(_ element: AXUIElement, index: Int) async {
        log("=== Element \(index) - All Attributes ===")
        do {
            try await printElementAttributes(element, prefix: "  ")
        } catch {
            log("  Error printing element attributes: \(error)")
        }
        log("=== End Element \(index) ===")
    }
    

    
    /// Explore regions independently in the entire window
    private func exploreRegionsIndependently(in window: AXUIElement) async throws {
        log("Searching for regions in entire window...")
        
        // First, try to find the "Tracks contents" element's siblings that might contain regions
        log("Looking for Tracks contents element and its siblings...")
        let tracksContents = try await findTracksContentsElement(in: window, maxDepth: 10)
        
        // Get the parent of Tracks contents to find its siblings
        var parent: CFTypeRef?
        let parentResult = AXUIElementCopyAttributeValue(tracksContents, kAXParentAttribute as CFString, &parent)
        
        if parentResult == .success, let parent = parent {
            let parentElement = parent as! AXUIElement
            log("Found parent of Tracks contents, searching for region-related siblings...")
            
            // Search for regions in the parent's children (siblings of Tracks contents)
            let regions = try await findRegionElementsInSiblings(parentElement, tracksContents)
            
            log("Found \(regions.count) regions in sibling elements:")
            for (index, region) in regions.enumerated() {
                try await analyzeIndependentRegion(region, index: index)
            }
        } else {
            log("Could not find parent of Tracks contents, falling back to full window search...")
            // Fallback: search for elements with CLgViewAccessibilityRegion class or (Region) in description
            let regions = try await findRegionElements(in: window, maxDepth: 15)
            
            log("Found \(regions.count) regions independently:")
            for (index, region) in regions.enumerated() {
                try await analyzeIndependentRegion(region, index: index)
            }
        }
    }
    
    /// Find region elements in sibling elements of Tracks contents
    private func findRegionElementsInSiblings(_ parent: AXUIElement, _ tracksContents: AXUIElement) async throws -> [AXUIElement] {
        var regions: [AXUIElement] = []
        
        // Get all children of the parent
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            log("Parent has \(childrenArray.count) children, searching for region-related elements...")
            
            for (index, child) in childrenArray.enumerated() {
                // Skip the Tracks contents element itself
                if child == tracksContents {
                    log("Skipping Tracks contents element (index \(index))")
                    continue
                }
                
                // Check if this sibling element contains regions
                log("Analyzing sibling element \(index)...")
                let childRegions = try await findRegionElementsInElement(child, maxDepth: 8)
                regions.append(contentsOf: childRegions)
            }
        }
        
        return regions
    }
    
    /// Find region elements recursively in a specific element
    private func findRegionElementsInElement(_ element: AXUIElement, maxDepth: Int) async throws -> [AXUIElement] {
        var regions: [AXUIElement] = []
        
        if maxDepth <= 0 {
            return regions
        }
        
        // Check if this element is a region
        if try await isIndependentRegion(element) {
            regions.append(element)
        }
        
        // Get children and recursively search
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            for child in childrenArray {
                let childRegions = try await findRegionElementsInElement(child, maxDepth: maxDepth - 1)
                regions.append(contentsOf: childRegions)
            }
        }
        
        return regions
    }
    
    /// Find region elements recursively in the window
    private func findRegionElements(in element: AXUIElement, maxDepth: Int) async throws -> [AXUIElement] {
        var regions: [AXUIElement] = []
        
        if maxDepth <= 0 {
            return regions
        }
        
        // Check if this element is a region
        if try await isIndependentRegion(element) {
            regions.append(element)
        }
        
        // Get children and recursively search
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            for child in childrenArray {
                let childRegions = try await findRegionElements(in: child, maxDepth: maxDepth - 1)
                regions.append(contentsOf: childRegions)
            }
        }
        
        return regions
    }
    
    /// Check if an element is an independent region
    private func isIndependentRegion(_ element: AXUIElement) async throws -> Bool {
        // Check AXRoleDescription for "Region" identifier
        var roleDescription: CFTypeRef?
        let roleDescResult = AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute as CFString, &roleDescription)
        
        if roleDescResult == .success, let roleDescription = roleDescription as? String, !roleDescription.isEmpty {
            if roleDescription == "Region" {
                log("DEBUG: Found region by AXRoleDescription: '\(roleDescription)'")
                return true
            }
        }
        
        return false
    }
    
    /// Analyze an independently found region
    private func analyzeIndependentRegion(_ element: AXUIElement, index: Int) async throws {
        // Get basic attributes
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleString = (roleResult == .success && role != nil) ? (role as? String ?? "nil") : "nil"
        
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let titleString = (titleResult == .success && title != nil) ? (title as? String ?? "nil") : "nil"
        
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        let descString = (descResult == .success && description != nil) ? (description as? String ?? "nil") : "nil"
        
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        let subroleString = (subroleResult == .success && subrole != nil) ? (subrole as? String ?? "nil") : "nil"
        
        var identifier: CFTypeRef?
        let idResult = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        let idString = (idResult == .success && identifier != nil) ? (identifier as? String ?? "nil") : "nil"
        
        log("  Independent Region \(index):")
        log("    Role: \(roleString)")
        log("    Title: \(titleString)")
        log("    Description: \(descString)")
        log("    Subrole: \(subroleString)")
        log("    Identifier: \(idString)")
        log("    ---")
    }
    
    
    

    

    
    /// Check if an element appears to be a region
    private func isRegionElement(role: String, description: String, title: String) -> Bool {
        // Common region indicators
        let regionRoles = ["AXGroup", "AXLayoutArea", "AXStaticText"]
        let regionKeywords = ["region", "audio", "midi", "sample", "loop", "clip"]
        
        // Check role
        if regionRoles.contains(role) {
            return true
        }
        
        // Check description and title for region-related keywords
        let allText = "\(description) \(title)".lowercased()
        for keyword in regionKeywords {
            if allText.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    /// Analyze track element
    private func analyzeTrackElement(_ element: AXUIElement, index: Int) async throws -> LogicTrack? {
        // First check if this element is actually a track using our new detection method
        if !(try await isTrackElement(element)) {
            return nil
        }
        
        // Get track role for additional validation
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard roleResult == .success, let role = role as? String else {
            return nil
        }
        
        // Additional role validation
        if !isTrackRelatedRole(role) {
            return nil
        }
        
        // Get track name
        let name = try await getTrackName(from: element)
        
        // Get track type
        let trackType = try await getTrackType(from: element)
        
        // Get track properties
        let properties = try await getTrackProperties(from: element)
        
        // Get track position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        return LogicTrack(
            index: index,
            name: name,
            type: trackType,
            properties: properties,
            position: position,
            size: size,
            element: element
        )
    }
    
    /// Check if role is track-related
    private func isTrackRelatedRole(_ role: String) -> Bool {
        // More precise track identification based on Accessibility Inspector
        let trackRoles = [
            "AXRow",           // Track row
            "AXGroup",         // Track group
            "AXStaticText",    // Track name text
            "AXLayoutArea"     // Track layout area (actual role found in Logic Pro)
        ]
        return trackRoles.contains(role)
    }
    
    /// Check if element is a track based on description and other attributes
    private func isTrackElement(_ element: AXUIElement) async throws -> Bool {
        // Check description for track pattern: "Track X "Name""
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        if descResult == .success, let description = description as? String, !description.isEmpty {
            // Simple approach: if description starts with "Track", it's a track
            if description.hasPrefix("Track") {
                log("DEBUG: Track found by simple prefix check: '\(description)'")
                return true
            }
        }
        
        // Check if it has track-related accessibility identifier
        var identifier: CFTypeRef?
        let idResult = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        
        if idResult == .success, let identifier = identifier as? String {
            if identifier.contains("CLgViewAccessibilityTrac") {
                return true
            }
        }
        
        return false
    }
    
    /// Get track name
    private func getTrackName(from element: AXUIElement) async throws -> String {
        // Try multiple methods to get track name
        
        // Method 1: Get title directly
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        if titleResult == .success, let title = title as? String, !title.isEmpty {
            // Clean up the title - remove "Track Background" and extract just the name
            let cleanTitle = title.replacingOccurrences(of: "Track Background", with: "").trimmingCharacters(in: .whitespaces)
            if !cleanTitle.isEmpty {
                return cleanTitle
            }
        }
        
        // Method 2: Get description and extract track name from it
        var description: CFTypeRef?
        let descResult = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        if descResult == .success, let description = description as? String, !description.isEmpty {
            // Look for quoted track names like "Lead Vocal", "Chorus Vocal"
            if let range = description.range(of: "\"[^\"]+\"") {
                let quotedName = String(description[range])
                let cleanName = quotedName.replacingOccurrences(of: "\"", with: "")
                if !cleanName.isEmpty {
                    return cleanName
                }
            }
            
            // If no quoted name, try to extract from description
            let cleanDesc = description.replacingOccurrences(of: "Track Background", with: "").trimmingCharacters(in: .whitespaces)
            if !cleanDesc.isEmpty && cleanDesc != "Track Background" {
                return cleanDesc
            }
        }
        
        // Method 3: Find text in child elements (more precise search)
        if let childName = try await findTrackNameInChildren(element) {
            return childName
        }
        
        // Method 4: Try to get track index
        let index = try await getElementIndex(element)
        return "Track \(index)"
    }
    
    /// Get track type
    private func getTrackType(from element: AXUIElement) async throws -> LogicTrackType {
        // Determine track type by analyzing child elements and properties
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            // Find specific child elements to determine track type
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    switch role {
                    case "AXButton" where try await hasAudioIcon(child):
                        return .audio
                    case "AXButton" where try await hasMIDIIcon(child):
                        return .midi
                    case "AXButton" where try await hasSoftwareInstrumentIcon(child):
                        return .softwareInstrument
                    default:
                        continue
                    }
                }
            }
        }
        
        return .unknown
    }
    
    /// Get track properties
    private func getTrackProperties(from element: AXUIElement) async throws -> [String: Any] {
        var properties: [String: Any] = [:]
        
        // Get all supported properties
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
    
    /// Explore regions in track
    private func exploreRegions(in track: LogicTrack) async throws -> [LogicRegion] {
        log("Exploring regions in track '\(track.name)'...")
        
        var regions: [LogicRegion] = []
        
        // Find regions in track element
        let trackRegions = try await findRegionsInElement(track.element)
        
        for (index, regionElement) in trackRegions.enumerated() {
            if let region = try await analyzeRegionElement(regionElement, trackIndex: track.index, regionIndex: index) {
                regions.append(region)
                log("Discovered region \(index): \(region.name)")
            }
        }
        
        return regions
    }
    
    /// Find regions in element
    private func findRegionsInElement(_ element: AXUIElement) async throws -> [AXUIElement] {
        var regions: [AXUIElement] = []
        
        // Recursively search for region elements
        try await searchForRegions(in: element, foundRegions: &regions, maxDepth: 5)
        
        return regions
    }
    
    /// Recursively search for regions
    private func searchForRegions(in element: AXUIElement, foundRegions: inout [AXUIElement], maxDepth: Int) async throws {
        guard maxDepth > 0 else { return }
        
        // Check if current element is a region
        if try await isRegionElement(element) {
            foundRegions.append(element)
            return
        }
        
        // Search child elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                try await searchForRegions(in: child, foundRegions: &foundRegions, maxDepth: maxDepth - 1)
            }
        }
    }
    
    /// Check if element is a region
    private func isRegionElement(_ element: AXUIElement) async throws -> Bool {
        // Use the same logic as isIndependentRegion for consistency
        return try await isIndependentRegion(element)
    }
    
    /// Analyze region element
    private func analyzeRegionElement(_ element: AXUIElement, trackIndex: Int, regionIndex: Int) async throws -> LogicRegion? {
        // Get region name
        let name = try await getRegionName(from: element)
        
        // Get region type
        let regionType = try await getRegionType(from: element)
        
        // Get region properties
        let properties = try await getRegionProperties(from: element)
        
        // Get region position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        return LogicRegion(
            trackIndex: trackIndex,
            regionIndex: regionIndex,
            name: name,
            type: regionType,
            properties: properties,
            position: position,
            size: size,
            element: element
        )
    }
    
    // MARK: - Helper Methods
    
    /// Recursively find element with specific role
    private func findElementWithRole(in element: AXUIElement, role: String, maxDepth: Int) async throws -> AXUIElement {
        guard maxDepth > 0 else {
            throw LogicError.elementNotFound("Element with role \(role) not found")
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
                    return try await findElementWithRole(in: child, role: role, maxDepth: maxDepth - 1)
                } catch {
                    continue
                }
            }
        }
        
        throw LogicError.elementNotFound("Element with role \(role) not found")
    }
    
    /// Find track name in child elements (more precise search)
    private func findTrackNameInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            // First look for track name labels
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    // Find track name text elements
                    if role == "AXStaticText" || role == "AXTextField" {
                        var title: CFTypeRef?
                        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                        
                        if titleResult == .success, let title = title as? String, !title.isEmpty {
                            // Look for quoted track names first
                            if let range = title.range(of: "\"[^\"]+\"") {
                                let quotedName = String(title[range])
                                let cleanName = quotedName.replacingOccurrences(of: "\"", with: "")
                                if !cleanName.isEmpty {
                                    return cleanName
                                }
                            }
                            
                            // Filter out some common non-name text
                            if !title.contains("M") && !title.contains("S") && !title.contains("R") && 
                               !title.contains("I") && !title.contains("dB") && !title.contains("%") &&
                               !title.contains("Track Background") {
                                return title
                            }
                        }
                    }
                    
                    // Recursively search child elements
                    if let childName = try await findTrackNameInChildren(child) {
                        return childName
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find region name in child elements
    private func findRegionNameInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String {
                    // Find region name text elements
                    if role == "AXStaticText" || role == "AXTextField" {
                        var title: CFTypeRef?
                        let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                        
                        if titleResult == .success, let title = title as? String, !title.isEmpty {
                            // Filter out some common non-name text
                            if !title.contains("M") && !title.contains("S") && !title.contains("R") && 
                               !title.contains("I") && !title.contains("dB") && !title.contains("%") &&
                               !title.contains("Track") {
                                return title
                            }
                        }
                    }
                    
                    // Recursively search child elements
                    if let childName = try await findRegionNameInChildren(child) {
                        return childName
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Find text in child elements
    private func findTextInChildren(_ element: AXUIElement) async throws -> String? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            
            for child in childrenArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let role = role as? String, role == "AXStaticText" {
                    var title: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                    if titleResult == .success, let title = title as? String, !title.isEmpty {
                        return title
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Get element position
    private func getElementPosition(_ element: AXUIElement) async throws -> CGPoint {
        var position: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        
        if result == .success, let position = position {
            // Position is usually an AXValue
            if let point = try await extractPointFromAXValue(position) {
                return point
            }
        }
        
        return CGPoint.zero
    }
    
    /// Get element size
    private func getElementSize(_ element: AXUIElement) async throws -> CGSize {
        var size: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        if result == .success, let size = size {
            // Size is usually an AXValue
            if let sizeValue = try await extractSizeFromAXValue(size) {
                return sizeValue
            }
        }
        
        return CGSize.zero
    }
    
    /// Extract point from AXValue
    private func extractPointFromAXValue(_ value: CFTypeRef) async throws -> CGPoint? {
        // Try to extract point from AXValue
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            var point = CGPoint.zero
            let success = AXValueGetValue(axValue, .cgPoint, &point)
            if success {
                return point
            }
        }
        
        // Fallback: try to parse as dictionary or array
        if let dict = value as? [String: Any] {
            if let x = dict["x"] as? CGFloat, let y = dict["y"] as? CGFloat {
                return CGPoint(x: x, y: y)
            }
        }
        
        // Try to get from description if it contains position info
        if let description = value as? String {
            // Look for patterns like "position: (100, 200)" or "at (100, 200)"
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
    private func extractSizeFromAXValue(_ value: CFTypeRef) async throws -> CGSize? {
        // Try to extract size from AXValue
        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            var size = CGSize.zero
            let success = AXValueGetValue(axValue, .cgSize, &size)
            if success {
                return size
            }
        }
        
        // Fallback: try to parse as dictionary
        if let dict = value as? [String: Any] {
            if let width = dict["width"] as? CGFloat, let height = dict["height"] as? CGFloat {
                return CGSize(width: width, height: height)
            }
        }
        
        // Try to get from description if it contains size info
        if let description = value as? String {
            // Look for patterns like "size: (100, 200)" or "dimensions (100, 200)"
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
    
    /// Get element index
    private func getElementIndex(_ element: AXUIElement) async throws -> Int {
        var index: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXIndexAttribute as CFString, &index)
        
        if result == .success, let index = index as? Int {
            return index
        }
        
        return 0
    }
    
    /// Check if has audio icon
    private func hasAudioIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
    }
    
    /// Check if has MIDI icon
    private func hasMIDIIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
    }
    
    /// Check if has software instrument icon
    private func hasSoftwareInstrumentIcon(_ element: AXUIElement) async throws -> Bool {
        // Simplified implementation - actually need to check icon or description
        return false
    }
    
    // MARK: - Track Operations
    
    /// Activate Logic Pro application
    private func activateLogicPro() async throws {
        log("Activating Logic Pro application...")
        
        guard let logicApp = logicApp else {
            throw LogicError.appNotRunning
        }
        
        // Method 1: Try to bring the app to front using AXUIElement
        let result = AXUIElementSetAttributeValue(logicApp, kAXFrontmostAttribute as CFString, true as CFBoolean)
        log("AXUIElementSetAttributeValue frontmost result: \(result)")
        
        // Method 2: Use NSWorkspace to activate the app
        let runningApps = NSWorkspace.shared.runningApplications
        if let logicApp = runningApps.first(where: { $0.bundleIdentifier == logicBundleID }) {
            let activateResult = logicApp.activate(options: [.activateIgnoringOtherApps])
            log("NSWorkspace activate result: \(activateResult)")
        }
        
        // Method 3: Try to focus the main window
        try await focusMainWindow()
    }
    
    /// Focus the main window of Logic Pro
    private func focusMainWindow() async throws {
        log("Focusing Logic Pro main window...")
        
        let mainWindow = try await getMainWindow()
        
        // Try to set the window as the main window
        let mainResult = AXUIElementSetAttributeValue(mainWindow, kAXMainAttribute as CFString, true as CFBoolean)
        log("Set main window result: \(mainResult)")
        
        // Try to set the window as focused
        let focusResult = AXUIElementSetAttributeValue(mainWindow, kAXFocusedAttribute as CFString, true as CFBoolean)
        log("Set window focused result: \(focusResult)")
        
        // Try to bring window to front
        let frontResult = AXUIElementSetAttributeValue(mainWindow, kAXFrontmostAttribute as CFString, true as CFBoolean)
        log("Set window frontmost result: \(frontResult)")
    }
    
    /// Click on a track element
    private func clickTrack(_ track: LogicTrack) async throws {
        log("Attempting to click track: \(track.name)")
        
        // First, let's check what actions are available for this element
        var actions: CFArray?
        let actionsResult = AXUIElementCopyActionNames(track.element, &actions)
        
        if actionsResult == .success, let actions = actions {
            let actionsArray = actions as! [String]
            log("Available actions for track '\(track.name)': \(actionsArray)")
            
            // Try ALL available actions
            for action in actionsArray {
                log("Trying action: \(action)")
                let result = AXUIElementPerformAction(track.element, action as CFString)
                log("Action '\(action)' result: \(result)")
                
                // If this action might show a menu or popup, try to dismiss it
                if action == "AXShowMenu" {
                    log("Action '\(action)' might show menu/popup, attempting to dismiss...")
                    try await dismissMenuOrPopup()
                }
                
                // Add a 1 second delay between actions
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        } else {
            log("Could not get actions for track '\(track.name)'")
        }
        
        // Try different approaches to select/click the track
        
        
        // Method: Try to find a clickable child element
        try await findAndClickClickableChild(in: track.element, trackName: track.name)
        
    }
    
    /// Find and click a clickable child element
    private func findAndClickClickableChild(in element: AXUIElement, trackName: String) async throws {
        log("Searching for clickable child elements in track: \(trackName)")
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let children = children {
            let childrenArray = children as! [AXUIElement]
            log("Track '\(trackName)' has \(childrenArray.count) child elements")
            
            for (index, child) in childrenArray.enumerated() {
                // Check if this child is clickable
                var actions: CFArray?
                let actionsResult = AXUIElementCopyActionNames(child, &actions)
                
                if actionsResult == .success, let actions = actions {
                    let actionsArray = actions as! [String]
                    if !actionsArray.isEmpty {
                        log("Found child \(index) with actions: \(actionsArray)")
                        
                        // Try ALL actions for this child
                        for action in actionsArray {
                            log("Trying child \(index) action: \(action)")
                            let actionResult = AXUIElementPerformAction(child, action as CFString)
                            log("Child \(index) action '\(action)' result: \(actionResult)")
                            
                            // If this action might show a menu or popup, try to dismiss it
                            if action == "AXShowMenu" {
                                log("Child \(index) action '\(action)' might show menu/popup, attempting to dismiss...")
                                try await dismissMenuOrPopup()
                            }
                            
                            // Add a 1 second delay between actions
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        }
                        
                        // Add a longer delay after trying all actions on this child
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    }
                }
            }
        }
    }
    
    /// Click at the element's position using mouse coordinates
    private func clickAtElementPosition(_ element: AXUIElement, trackName: String) async throws {
        log("Attempting to click at element position for track: \(trackName)")
        
        // Get element position and size
        let position = try await getElementPosition(element)
        let size = try await getElementSize(element)
        
        log("Element position: \(position), size: \(size)")
        
        // Check if size values are reasonable (not corrupted)
        if size.width > 10000 || size.height > 10000 || size.width < 0 || size.height < 0 {
            log("Element size appears corrupted, skipping mouse click")
            return
        }
        
        // Calculate center point
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        
        log("Clicking at center point: (\(centerX), \(centerY))")
        
        // Validate coordinates are reasonable
        if centerX < 0 || centerY < 0 || centerX > 10000 || centerY > 10000 {
            log("Calculated coordinates appear invalid, skipping mouse click")
            return
        }
        
        // Create mouse event at the center of the element
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        
        // Set flags to ensure the event is delivered to the active application
        mouseDownEvent?.flags = []
        mouseUpEvent?.flags = []
        
        mouseDownEvent?.post(tap: .cghidEventTap)
        mouseUpEvent?.post(tap: .cghidEventTap)
        
        log("Posted mouse click events at (\(centerX), \(centerY))")
    }
    
    /// Click at a reasonable position based on track index
    private func clickAtReasonablePosition(track: LogicTrack) async throws {
        log("Attempting to click at reasonable position for track: \(track.name)")
        
        // Get element position (this seems to work correctly)
        let position = try await getElementPosition(track.element)
        log("Track position: \(position)")
        
        // Use a reasonable track height (typically around 16-50 pixels)
        let reasonableHeight: CGFloat = 30
        let reasonableWidth: CGFloat = 200
        
        // Calculate center point with reasonable dimensions
        let centerX = position.x + reasonableWidth / 2
        let centerY = position.y + reasonableHeight / 2
        
        log("Clicking at reasonable center point: (\(centerX), \(centerY))")
        
        // Validate coordinates
        if centerX < 0 || centerY < 0 || centerX > 10000 || centerY > 10000 {
            log("Calculated coordinates appear invalid, skipping reasonable position click")
            return
        }
        
        // Create mouse event with proper flags to ensure it reaches the active app
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left)
        
        // Set flags to ensure the event is delivered to the active application
        mouseDownEvent?.flags = []
        mouseUpEvent?.flags = []
        
        mouseDownEvent?.post(tap: .cghidEventTap)
        mouseUpEvent?.post(tap: .cghidEventTap)
        
        log("Posted reasonable position mouse click events at (\(centerX), \(centerY))")
    }
    
    /// Dismiss any open menus or popups
    private func dismissMenuOrPopup() async throws {
        log("Attempting to dismiss any open menus or popups...")
        
        // Use a simple and clean Escape key method
        // Create a single keyboard event and post it
        if let escapeEvent = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true) {
            // Post the key down event
            escapeEvent.post(tap: .cghidEventTap)
            
            // Create and post the key up event immediately
            if let escapeUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) {
                escapeUpEvent.post(tap: .cghidEventTap)
            }
            
            log("Posted Escape key events")
        }
        
        // Wait a moment for the dismiss to take effect
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds (reduced)
    }
}

// MARK: - Data Models

/// Logic Pro Track
struct LogicTrack {
    let index: Int
    let name: String
    let type: LogicTrackType
    let properties: [String: Any]
    let position: CGPoint
    let size: CGSize
    let element: AXUIElement
}

/// Logic Pro Track Type
enum LogicTrackType: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case softwareInstrument = "Software Instrument"
    case unknown = "Unknown"
}

/// Logic Pro Region
struct LogicRegion {
    let trackIndex: Int
    let regionIndex: Int
    let name: String
    let type: LogicRegionType
    let properties: [String: Any]
    let position: CGPoint
    let size: CGSize
    let element: AXUIElement
}

/// Logic Pro Region Type
enum LogicRegionType: String, CaseIterable {
    case audio = "Audio"
    case midi = "MIDI"
    case unknown = "Unknown"
}

