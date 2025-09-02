import SwiftUI

/// Logic Pro Project Explorer UI Interface
struct ProjectExplorerView: View {
    @StateObject private var example = LogicProjectExplorerExample()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Logic Pro Project Explorer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await example.exploreProjectExample()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Explore Project")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(example.isExploring)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tab selection
            Picker("Select Function", selection: $selectedTab) {
                Text("Project Exploration").tag(0)
                Text("Track Management").tag(1)
                Text("Region Operations").tag(2)
                Text("Data Analysis").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Content area
            TabView(selection: $selectedTab) {
                // Project exploration tab
                ProjectExplorationTab(example: example)
                    .tag(0)
                
                // Track management tab
                TrackManagementTab(example: example)
                    .tag(1)
                
                // Region operations tab
                RegionOperationTab(example: example)
                    .tag(2)
                
                // Data analysis tab
                DataAnalysisTab(example: example)
                    .tag(3)
            }
            .tabViewStyle(DefaultTabViewStyle())
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Project Exploration Tab

struct ProjectExplorationTab: View {
    @ObservedObject var example: LogicProjectExplorerExample
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Exploration")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Explore track and region information in Logic Pro projects")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Exploration results
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exploration Results:")
                        .font(.headline)
                    
                    Text(example.explorationResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Track Management Tab

struct TrackManagementTab: View {
    @ObservedObject var example: LogicProjectExplorerExample
    @State private var selectedTrackType: LogicTrackType = .audio
    @State private var volume: Float = 0.8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Track Management")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Manage tracks in Logic Pro projects")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Track type selection
            HStack {
                Text("Track Type:")
                Picker("Track Type", selection: $selectedTrackType) {
                    ForEach(LogicTrackType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
            }
            
            // Volume control
            HStack {
                Text("Volume:")
                Slider(value: $volume, in: 0...1, step: 0.1)
                Text("\(Int(volume * 100))%")
                    .frame(width: 40)
            }
            
            // Operation buttons
            HStack {
                Button("Find Tracks") {
                    Task {
                        let tracks = await example.findTracksByType(selectedTrackType)
                        // Results can be displayed here
                    }
                }
                
                Button("Batch Modify Volume") {
                    Task {
                        await example.batchModifyTrackVolumes(volume: volume)
                    }
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Region Operations Tab

struct RegionOperationTab: View {
    @ObservedObject var example: LogicProjectExplorerExample
    @State private var selectedRegionType: LogicRegionType = .audio
    @State private var volume: Float = 0.8
    @State private var pan: Float = 0.0
    @State private var velocity: Int = 64
    @State private var pitch: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Region Operations")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Operate on regions in Logic Pro projects")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Region type selection
            HStack {
                Text("Region Type:")
                Picker("Region Type", selection: $selectedRegionType) {
                    ForEach(LogicRegionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
            }
            
            // Parameter controls
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Volume:")
                    Slider(value: $volume, in: 0...1, step: 0.1)
                    Text("\(Int(volume * 100))%")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Pan:")
                    Slider(value: $pan, in: -1...1, step: 0.1)
                    Text("\(Int(pan * 100))")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Velocity:")
                    Slider(value: Binding(
                        get: { Double(velocity) },
                        set: { velocity = Int($0) }
                    ), in: 1...127, step: 1)
                    Text("\(velocity)")
                        .frame(width: 40)
                }
                
                HStack {
                    Text("Pitch:")
                    Slider(value: Binding(
                        get: { Double(pitch) },
                        set: { pitch = Int($0) }
                    ), in: -24...24, step: 1)
                    Text("\(pitch)")
                        .frame(width: 40)
                }
            }
            
            // Operation buttons
            HStack {
                Button("Find Regions") {
                    Task {
                        let regions = await example.findRegionsByType(selectedRegionType)
                        // Results can be displayed here
                    }
                }
                
                Button("Apply Parameters") {
                    // Parameter application functionality needs to be implemented here
                }
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Data Analysis Tab

struct DataAnalysisTab: View {
    @ObservedObject var example: LogicProjectExplorerExample
    @State private var showJSONExport = false
    @State private var jsonString = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Analysis")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Analyze Logic Pro project data structure")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Analysis buttons
            HStack {
                Button("Analyze Project Structure") {
                    Task {
                        await example.analyzeProjectStructure()
                    }
                }
                
                Button("Find Duplicate Regions") {
                    Task {
                        let duplicates = await example.findDuplicateRegions()
                        // Results can be displayed here
                    }
                }
                
                Button("Optimize Project Layout") {
                    Task {
                        await example.optimizeProjectLayout()
                    }
                }
                
                Spacer()
            }
            
            // Export/Import functionality
            HStack {
                Button("Export JSON") {
                    Task {
                        if let json = await example.exportProjectInfoToJSON() {
                            jsonString = json
                            showJSONExport = true
                        }
                    }
                }
                
                Button("Import JSON") {
                    if !jsonString.isEmpty {
                        Task {
                            await example.importProjectInfoFromJSON(jsonString)
                        }
                    }
                }
                
                Spacer()
            }
            
            // JSON display area
            if showJSONExport {
                ScrollView {
                    Text(jsonString)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

struct ProjectExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectExplorerView()
    }
}
