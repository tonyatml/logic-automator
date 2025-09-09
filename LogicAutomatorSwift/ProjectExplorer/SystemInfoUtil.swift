//
//  SystemInfoUtil.swift
//  Logic Pro System Information Utility
//
//  Collects system information for reporting purposes
//

import Foundation
import AppKit
import IOKit

class SystemInfoUtil {
    
    // MARK: - System Information
    
    /// Get macOS version information
    static func getMacOSVersion() -> [String: Any] {
        let processInfo = ProcessInfo.processInfo
        let version = processInfo.operatingSystemVersion
        
        return [
            "name": "macOS",
            "version": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            "major": version.majorVersion,
            "minor": version.minorVersion,
            "patch": version.patchVersion,
            "build": processInfo.operatingSystemVersionString
        ]
    }
    
    /// Get Logic Pro version information
    static func getLogicProVersion() -> [String: Any] {
        let bundleID = "com.apple.logic10"
        
        // Try to get Logic Pro version from running application
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            if let bundleURL = runningApp.bundleURL,
               let bundle = Bundle(url: bundleURL) {
                let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
                let name = bundle.infoDictionary?["CFBundleName"] as? String ?? 
                          bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? 
                          runningApp.localizedName ?? "Logic Pro"
                
                return [
                    "name": name,
                    "version": version,
                    "build": build,
                    "bundle_id": bundleID,
                    "is_running": true
                ]
            }
        }
        
        // Try to get Logic Pro version from installed application
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL) {
            let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? 
                      bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? 
                      "Logic Pro"
            
            return [
                "name": name,
                "version": version,
                "build": build,
                "bundle_id": bundleID,
                "is_running": false
            ]
        }
        
        return [
            "name": "Logic Pro",
            "version": "Not Installed",
            "build": "Unknown",
            "bundle_id": bundleID,
            "is_running": false
        ]
    }
    
    // MARK: - Hardware Information
    
    /// Get CPU information
    static func getCPUInfo() -> [String: Any] {
        var cpuInfo: [String: Any] = [:]
        
        // Get CPU usage
        let host = mach_host_self()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = Double(cpuLoadInfo.cpu_ticks.0)
            let system = Double(cpuLoadInfo.cpu_ticks.1)
            let idle = Double(cpuLoadInfo.cpu_ticks.2)
            let nice = Double(cpuLoadInfo.cpu_ticks.3)
            
            let total = user + system + idle + nice
            let usage = total > 0 ? ((user + system + nice) / total) * 100.0 : 0.0
            
            cpuInfo["usage_percent"] = round(usage * 100) / 100
            cpuInfo["user_ticks"] = cpuLoadInfo.cpu_ticks.0
            cpuInfo["system_ticks"] = cpuLoadInfo.cpu_ticks.1
            cpuInfo["idle_ticks"] = cpuLoadInfo.cpu_ticks.2
            cpuInfo["nice_ticks"] = cpuLoadInfo.cpu_ticks.3
        }
        
        // Get CPU model
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuBrand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuBrand, &size, nil, 0)
        cpuInfo["model"] = String(cString: cpuBrand)
        
        // Get CPU core count
        var coreCount = 0
        size = MemoryLayout<Int>.size
        sysctlbyname("hw.ncpu", &coreCount, &size, nil, 0)
        cpuInfo["core_count"] = coreCount
        
        return cpuInfo
    }
    
    /// Get memory information
    static func getMemoryInfo() -> [String: Any] {
        var memoryInfo: [String: Any] = [:]
        
        // Get memory usage
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let totalPages = UInt64(vmStats.free_count + vmStats.active_count + vmStats.inactive_count + vmStats.wire_count)
            let usedPages = UInt64(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count)
            let freePages = UInt64(vmStats.free_count)
            
            let totalMemory = totalPages * pageSize
            let usedMemory = usedPages * pageSize
            let freeMemory = freePages * pageSize
            
            memoryInfo["total_bytes"] = totalMemory
            memoryInfo["used_bytes"] = usedMemory
            memoryInfo["free_bytes"] = freeMemory
            memoryInfo["usage_percent"] = totalMemory > 0 ? round((Double(usedMemory) / Double(totalMemory)) * 10000) / 100 : 0
        }
        
        // Get total physical memory
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        memoryInfo["physical_total_bytes"] = totalMemory
        
        return memoryInfo
    }
    
    // MARK: - Device Information
    
    /// Get device identifier
    static func getDeviceID() -> String {
        // Try to get hardware UUID
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        if platformExpert != 0 {
            let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0)
            IOObjectRelease(platformExpert)
            
            if let serialNumber = serialNumberAsCFString?.takeRetainedValue() as? String {
                return serialNumber
            }
        }
        
        // Fallback to host name
        return ProcessInfo.processInfo.hostName
    }
    
    /// Get user information
    static func getUserInfo() -> [String: Any] {
        let userName = NSUserName()
        let fullUserName = NSFullUserName()
        
        return [
            "username": userName,
            "full_name": fullUserName,
            "home_directory": NSHomeDirectory(),
            "user_id": getuid()
        ]
    }
    
    // MARK: - Application Information
    
    /// Get current application information
    static func getAppInfo() -> [String: Any] {
        let bundle = Bundle.main
        
        return [
            "name": bundle.infoDictionary?["CFBundleName"] as? String ?? "Unknown",
            "version": bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build": bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "bundle_id": bundle.bundleIdentifier ?? "Unknown",
            "executable_path": bundle.executablePath ?? "Unknown"
        ]
    }
    
    // MARK: - Network Information
    
    /// Get network interface information
    static func getNetworkInfo() -> [String: Any] {
        var networkInfo: [String: Any] = [:]
        
        // Get primary network interface
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return networkInfo }
        defer { freeifaddrs(ifaddr) }
        
        var primaryInterface: String?
        var primaryIP: String?
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            
            // Skip loopback and non-active interfaces
            if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                if primaryInterface == nil {
                    primaryInterface = name
                }
                
                if name == "en0" || name == "en1" { // Ethernet or WiFi
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    primaryIP = String(cString: hostname)
                    break
                }
            }
        }
        
        networkInfo["primary_interface"] = primaryInterface ?? "Unknown"
        networkInfo["primary_ip"] = primaryIP ?? "Unknown"
        
        return networkInfo
    }
    
    // MARK: - Logic Pro Project Information
    
    /// Get current Logic Pro project information
    static func getCurrentProjectInfo() -> [String: Any] {
        var projectInfo: [String: Any] = [:]
        
        // Try to get Logic Pro application
        guard let logicApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.logic10" }) else {
            projectInfo["name"] = "Logic Pro not running"
            projectInfo["path"] = "N/A"
            projectInfo["region_count"] = 0
            return projectInfo
        }
        
        // Try to get Logic Pro AXUIElement
        if let logicAXApp = LogicUtil.getLogicApp() {
            // Get all windows from Logic Pro
            var windows: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(logicAXApp, kAXWindowsAttribute as CFString, &windows)
            
            if result == .success, let windowsArray = windows as? [AXUIElement] {
                print("🔍 Found \(windowsArray.count) Logic Pro windows")
                
                for (index, window) in windowsArray.enumerated() {
                    print("🔍 === Logic Pro Window \(index + 1) ===")
                    AXElementDebugger.printAllElementAttributes(window, title: "Logic Pro Window \(index + 1)")
                    
                    // Try to get window title
                    var title: CFTypeRef?
                    let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
                    
                    if titleResult == .success, let titleString = title as? String {
                        print("🔍 Window \(index + 1) title: \(titleString)")
                        
                        // Try to get document path (AXDocument attribute)
                        var document: CFTypeRef?
                        let documentResult = AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &document)
                        
                        if documentResult == .success, let documentString = document as? String {
                            print("🔍 Window \(index + 1) document: \(documentString)")
                            
                            // Extract project name from document path
                            if let url = URL(string: documentString) {
                                let projectName = url.lastPathComponent.replacingOccurrences(of: ".logicx", with: "")
                                projectInfo["name"] = projectName
                                projectInfo["path"] = url.path
                                print("🔍 Extracted project name: \(projectName)")
                                print("🔍 Extracted project path: \(url.path)")
                                break
                            }
                        }
                        
                        // Fallback: Use the first window with a meaningful title
                        if !titleString.isEmpty && titleString != "Logic Pro" && projectInfo["name"] == nil {
                            projectInfo["name"] = titleString
                            projectInfo["path"] = "Path extracted from window title"
                        }
                    }
                }
            } else {
                print("❌ Failed to get Logic Pro windows: \(result)")
            }
        }
        
        // Fallback to app name if no window title found
        if projectInfo["name"] == nil {
            let appName = logicApp.localizedName ?? "Logic Pro"
            projectInfo["name"] = appName.contains(".logicx") ? appName : "Untitled Project"
            projectInfo["path"] = "Path not accessible via NSRunningApplication"
        }
        
        // Try to get track count and track names
        let trackInfo = getTrackInfo()
        projectInfo["track_count"] = trackInfo["count"] ?? 0
        projectInfo["track_names"] = trackInfo["names"] ?? []
        
        return projectInfo
    }
    
    /// Get track information from Logic Pro
    private static func getTrackInfo() -> [String: Any] {
        var trackInfo: [String: Any] = [:]
        
        // Check if Logic Pro is running
        guard LogicUtil.isLogicProRunning() else {
            trackInfo["count"] = 0
            trackInfo["names"] = []
            return trackInfo
        }
        
        // Try to get track information using a simplified approach
        // Since we can't use async methods in a sync context, we'll use a basic estimation
        
        // Get Logic Pro application
        if let logicApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.logic10" }) {
            // Since NSRunningApplication doesn't have windows property,
            // we'll use a simple estimation based on app state
            let estimatedTrackCount = 1 // Default to 1 track for running Logic Pro
            
            trackInfo["count"] = estimatedTrackCount
            trackInfo["names"] = generateEstimatedTrackNames(count: estimatedTrackCount)
        } else {
            trackInfo["count"] = 0
            trackInfo["names"] = []
        }
        
        return trackInfo
    }
    
    /// Get real track information using LogicProjectExplorer (async method)
    static func getRealTrackInfo() async -> [String: Any] {
        var trackInfo: [String: Any] = [:]
        
        // Check if Logic Pro is running
        guard LogicUtil.isLogicProRunning() else {
            trackInfo["count"] = 0
            trackInfo["names"] = []
            return trackInfo
        }
        
        do {
            // Use LogicProjectExplorer to get real track information
            let explorer = LogicProjectExplorer()
            try await explorer.exploreProject()
            
            // Get track count and names from the explorer
            let trackCount = explorer.tracks.count
            let trackNames = explorer.tracks.map { $0.name }
            
            trackInfo["count"] = trackCount
            trackInfo["names"] = trackNames
            
        } catch {
            // If exploration fails, fall back to estimation
            trackInfo["count"] = 0
            trackInfo["names"] = []
        }
        
        return trackInfo
    }
    
    /// Generate estimated track names based on count
    private static func generateEstimatedTrackNames(count: Int) -> [String] {
        var trackNames: [String] = []
        
        for i in 1...count {
            if i == 1 {
                trackNames.append("Track 1")
            } else if i == 2 {
                trackNames.append("Track 2")
            } else {
                trackNames.append("Track \(i)")
            }
        }
        
        return trackNames
    }
    
    /// Get RAM size in GB
    private static func getRAMSizeGB(_ memoryInfo: [String: Any]) -> Int {
        if let totalBytes = memoryInfo["physical_total_bytes"] as? UInt64 {
            return Int(totalBytes / (1024 * 1024 * 1024)) // Convert bytes to GB
        }
        return 0
    }
    
    /// Get memory used in MB
    private static func getMemoryUsedMB(_ memoryInfo: [String: Any]) -> Int {
        if let usedBytes = memoryInfo["used_bytes"] as? UInt64 {
            return Int(usedBytes / (1024 * 1024)) // Convert bytes to MB
        }
        return 0
    }
    
    // MARK: - Complete System Report
    
    /// Get complete system information report
    static func getCompleteSystemReport() -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "device_id": getDeviceID(),
            "user": getUserInfo(),
            "system": getMacOSVersion(),
            "logic_pro": getLogicProVersion(),
            "app": getAppInfo(),
            "hardware": [
                "cpu": getCPUInfo(),
                "memory": getMemoryInfo()
            ],
            "network": getNetworkInfo()
        ]
    }
    
    /// Get lightweight system report for frequent updates
    static func getLightweightSystemReport() -> [String: Any] {
        let cpuInfo = getCPUInfo()
        let systemInfo = getMacOSVersion()
        let logicInfo = getLogicProVersion()
        let memoryInfo = getMemoryInfo()
        let projectInfo = getCurrentProjectInfo()
        
        return [
            "system_info": [
                "system_version": systemInfo["version"] ?? "",
                "sample_rate": getAudioSampleRate(),
                "buffer_size": getAudioBufferSize(),
                "audio_device": getAudioDeviceName(),
                "ram_size_gb": getRAMSizeGB(memoryInfo),
                "logic_version": logicInfo["version"] ?? "",
                "cpu_model": cpuInfo["model"] ?? ""
            ],
            "workflow": [
                "selected_track": getSelectedTrack(),
                "selected_region": getSelectedRegion(),
                "focused_window": getFocusedWindow(),
                "active_tool": getActiveTool(),
                "transport_state": getTransportState()
            ],
            "performance": [
                "memory_used_mb": getMemoryUsedMB(memoryInfo),
                "disk_load_percent": getDiskLoadPercent(),
                "cpu_load_percent": cpuInfo["usage_percent"] ?? 0
            ],
            "project_info": [
                "region_count": getRegionCount(),
                "bit_depth": getProjectBitDepth(),
                "time_signature": getTimeSignature(),
                "effects_used": getEffectsUsed(),
                "marker_count": getMarkerCount(),
                "bpm": getProjectBPM(),
                "sample_rate": getProjectSampleRate(),
                "plugins_used": getPluginsUsed(),
                "track_count": projectInfo["track_count"] ?? 0,
                "project_path": projectInfo["path"] ?? "",
                "project_name": projectInfo["name"] ?? ""
            ],
            "protocol_data": getProtocolData()
        ]
    }
    
    // MARK: - Testing and Debugging
    
    /// Print complete system information to console
    static func printSystemInfo() {
        print("🖥️ === System Information Report ===")
        
        let report = getCompleteSystemReport()
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        print("🖥️ === End System Information ===")
    }
    
    /// Print lightweight system information to console
    static func printLightweightSystemInfo() {
        print("⚡ === Lightweight System Info ===")
        
        let report = getLightweightSystemReport()
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        print("⚡ === End Lightweight Info ===")
    }
    
    /// Print API payload format to console (matching the example)
    static func printAPIFormat() {
        print("📡 === API Payload Format (Example) ===")
        
        let systemReport = getLightweightSystemReport()
        let apiPayload: [String: Any] = [
            "client_id": "logic-automator-client",
            "session_id": "TEST-SESSION-002",
            "system_info": systemReport["system_info"] ?? [:],
            "workflow": systemReport["workflow"] ?? [:],
            "performance": systemReport["performance"] ?? [:],
            "project_info": systemReport["project_info"] ?? [:],
            "protocol_data": systemReport["protocol_data"] ?? [:]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: apiPayload, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        print("📡 === End API Payload Format ===")
    }
    
    /// Print local JSON file format to console (matching the example with events in protocol_data)
    static func printLocalJSONFormat() {
        print("📁 === Local JSON File Format (Example) ===")
        
        let systemReport = getLightweightSystemReport()
        var protocolData = systemReport["protocol_data"] as? [String: Any] ?? [:]
        
        // Add user interaction events to protocol_data
        protocolData["events"] = [
            [
                "relativeTime": 1.3558931350708008,
                "command": "AXSelectedTextChanged",
                "AXRole": "AXTextArea",
                "AXValue": "",
                "sessionTimestamp": 1757321056.006104
            ],
            [
                "relativeTime": 2.8884282112121582,
                "command": "AXValueChanged",
                "AXRole": "AXTextField",
                "AXValue": "Noise Sweep",
                "sessionTimestamp": 1757321057.5386391
            ]
        ]
        
        let localJSONPayload: [String: Any] = [
            "client_id": "logic-automator-client",
            "session_id": "TEST-SESSION-002",
            "system_info": systemReport["system_info"] ?? [:],
            "workflow": systemReport["workflow"] ?? [:],
            "performance": systemReport["performance"] ?? [:],
            "project_info": systemReport["project_info"] ?? [:],
            "protocol_data": protocolData
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: localJSONPayload, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        print("📁 === End Local JSON File Format ===")
    }
    
    // MARK: - Audio Information
    
    /// Get audio sample rate
    static func getAudioSampleRate() -> Int {
        // TODO: Get actual audio sample rate from Logic Pro
        return 48000 // Default value
    }
    
    /// Get audio buffer size
    static func getAudioBufferSize() -> Int {
        // TODO: Get actual buffer size from Logic Pro
        return 256 // Default value
    }
    
    /// Get audio device name
    static func getAudioDeviceName() -> String {
        // TODO: Get actual audio device name from Logic Pro
        return "Universal Audio Apollo" // Default value
    }
    
    // MARK: - Workflow Information
    
    /// Get selected track name
    static func getSelectedTrack() -> String {
        // TODO: Get actual selected track from Logic Pro
        return "Vocal Lead" // Default value
    }
    
    /// Get selected region name
    static func getSelectedRegion() -> String {
        // TODO: Get actual selected region from Logic Pro
        return "Verse 1" // Default value
    }
    
    /// Get focused window name
    static func getFocusedWindow() -> String {
        // TODO: Get actual focused window from Logic Pro
        return "Tracks" // Default value
    }
    
    /// Get active tool name
    static func getActiveTool() -> String {
        // TODO: Get actual active tool from Logic Pro
        return "Pointer" // Default value
    }
    
    /// Get transport state
    static func getTransportState() -> String {
        // TODO: Get actual transport state from Logic Pro
        return "stopped" // Default value
    }
    
    // MARK: - Performance Information
    
    /// Get disk load percentage
    static func getDiskLoadPercent() -> Double {
        // TODO: Get actual disk load percentage
        return 12.5 // Default value
    }
    
    // MARK: - Project Information
    
    /// Get region count
    static func getRegionCount() -> Int {
        // TODO: Get actual region count from Logic Pro
        return 15 // Default value
    }
    
    /// Get project bit depth
    static func getProjectBitDepth() -> Int {
        // TODO: Get actual bit depth from Logic Pro
        return 24 // Default value
    }
    
    /// Get time signature
    static func getTimeSignature() -> String {
        // TODO: Get actual time signature from Logic Pro
        return "4/4" // Default value
    }
    
    /// Get effects used
    static func getEffectsUsed() -> [String] {
        // TODO: Get actual effects list from Logic Pro
        return ["Compressor", "Reverb", "EQ"] // Default value
    }
    
    /// Get marker count
    static func getMarkerCount() -> Int {
        // TODO: Get actual marker count from Logic Pro
        return 3 // Default value
    }
    
    /// Get project BPM
    static func getProjectBPM() -> Int {
        // TODO: Get actual BPM from Logic Pro
        return 120 // Default value
    }
    
    /// Get project sample rate
    static func getProjectSampleRate() -> Int {
        // TODO: Get actual project sample rate from Logic Pro
        return 48000 // Default value
    }
    
    /// Get plugins used
    static func getPluginsUsed() -> [String] {
        // TODO: Get actual plugins list from Logic Pro
        return ["VocalSynth", "Neve 1073", "SSL G-Master"] // Default value
    }
    
    // MARK: - Protocol Data
    
    /// Get protocol data
    static func getProtocolData() -> [String: Any] {
        return [
            "protocol_name": "Slice Region into 8",
            "tags": ["editing", "slicing", "audio"],
            "description": "Splits selected audio region into 8 equal slices",
            "events": getProtocolEvents()
        ]
    }
    
    /// Get protocol events (placeholder implementation)
    static func getProtocolEvents() -> [[String: Any]] {
        // TODO: Get actual protocol events from Logic Pro
        return [
            [
                "relativeTime": 1.3558931350708008,
                "AXInsertionPointLineNumber": 0,
                "AXRoleDescription": "text entry area",
                "AXRole": "AXTextArea",
                "AXParent": "<AXUIElement 0x6000019cc600> {pid=16206}",
                "AXSelectedTextRange": "<AXValue 0x6000019dc630> {value = location:0 length:0 type = kAXValueCFRangeType}",
                "AXFocused": 0,
                "AXTopLevelUIElement": "<AXUIElement 0x6000019cc600> {pid=16206}",
                "AXSelectedTextRanges": ["0x0000600001993630"],
                "AXVisibleCharacterRange": "<AXValue 0x6000019c34e0> {value = location:0 length:0 type = kAXValueCFRangeType}",
                "AXValue": "",
                "AXSharedTextUIElements": ["0x00006000019ae4c0"],
                "sessionTimestamp": 1757321056.006104,
                "AXFrame": "<AXValue 0x60000022dd00> {value = x:0.000000 y:1335.000000 w:2560.000000 h:20.000000 type = kAXValueCGRectType}",
                "AXTextInputMarkedRange": "<AXValue 0x6000019c34e0> {value = location:0 length:0 type = kAXValueCFRangeType}",
                "command": "AXSelectedTextChanged",
                "AXHelp": "Error: -25212",
                "AXChildrenInNavigationOrder": [],
                "AXNumberOfCharacters": 0,
                "AXChildren": [],
                "AXIdentifier": "Error: -25200",
                "AXSize": "<AXValue 0x6000019cc600> {value = w:2560.000000 h:20.000000 type = kAXValueCGSizeType}",
                "AXDescription": "Error: -25200",
                "AXWindow": "<AXUIElement 0x6000019c34e0> {pid=16206}",
                "AXPosition": "<AXValue 0x6000019af1e0> {value = x:0.000000 y:1335.000000 type = kAXValueCGPointType}",
                "AXSelectedText": ""
            ],
            [
                "relativeTime": 2.8884282112121582,
                "AXValue": "Noise Sweep",
                "AXRole": "AXTextField",
                "AXFrame": "<AXValue 0x6000002d9780> {value = x:265.000000 y:298.000000 w:96.000000 h:20.000000 type = kAXValueCGRectType}",
                "AXVisibleCharacterRange": "<AXValue 0x6000019bd050> {value = location:0 length:11 type = kAXValueCFRangeType}",
                "AXParent": "<AXUIElement 0x6000019bd050> {pid=14064}",
                "AXEnabled": 1,
                "AXInsertionPointLineNumber": 0,
                "AXSelectedTextRange": "<AXValue 0x6000019bd050> {value = location:0 length:0 type = kAXValueCFRangeType}",
                "AXFocused": 0,
                "AXTopLevelUIElement": "<AXUIElement 0x6000019bd050> {pid=14064}",
                "AXSize": "<AXValue 0x6000019bd050> {value = w:96.000000 h:20.000000 type = kAXValueCGSizeType}",
                "AXIdentifier": "_NS:137",
                "sessionTimestamp": 1757321057.5386391,
                "AXPosition": "<AXValue 0x6000019af0c0> {value = x:265.000000 y:298.000000 type = kAXValueCGPointType}",
                "AXChildren": [],
                "AXHelp": "",
                "AXNumberOfCharacters": 11,
                "command": "AXValueChanged",
                "AXWindow": "<AXUIElement 0x6000019bd050> {pid=14064}",
                "AXRoleDescription": "text field"
            ]
        ]
    }
}
