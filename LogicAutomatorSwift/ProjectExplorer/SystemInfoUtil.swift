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
        let appInfo = getAppInfo()
        let userInfo = getUserInfo()
        
        return [
            "device_id": getDeviceID(),
            "cpu_model": cpuInfo["model"] ?? "Unknown",
            "system_version": systemInfo["version"] ?? "Unknown",
            "logic_name": logicInfo["name"] ?? "Unknown",
            "logic_version": logicInfo["version"] ?? "Unknown",
            "username": userInfo["username"] ?? "Unknown",
            "app_version": appInfo["version"] ?? "Unknown",
            "app_build": appInfo["build"] ?? "Unknown"
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
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        print("⚡ === End Lightweight Info ===")
    }
}
