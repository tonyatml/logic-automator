import SwiftUI

@main
struct ProjectExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ProjectExplorerView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ProjectExplorerMainView: View {
    @StateObject private var projectExplorer = LogicProjectExplorer()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text("Logic Pro Project Explorer")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(projectExplorer.isExploring ? .orange : .green)
                            .frame(width: 8, height: 8)
                        Text(projectExplorer.isExploring ? "Exploring..." : "Ready")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content
            ProjectExplorerContentView(projectExplorer: projectExplorer)
        }
        .frame(width: 500, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ProjectExplorerContentView: View {
    @ObservedObject var projectExplorer: LogicProjectExplorer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Explore track and region information in Logic Pro projects")
                    .font(.headline)
                
                Text("Use macOS Accessibility API to read Logic Pro project structure information, including track names, types, positions, sizes and other properties, as well as region information.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            
            // Control buttons
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await projectExplorer.exploreProjectExample()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Explore Project")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(projectExplorer.isExploring)
                
                Button(action: {
                    projectExplorer.explorationResults = ""
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Results")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(projectExplorer.explorationResults.isEmpty)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Results section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exploration Results:")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !projectExplorer.explorationResults.isEmpty {
                        Text("\(projectExplorer.explorationResults.components(separatedBy: "\n").count) lines")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ScrollView {
                    if projectExplorer.explorationResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Click the \"Explore Project\" button to start exploring Logic Pro projects")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        Text(projectExplorer.explorationResults)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
    }
}

#Preview {
    ProjectExplorerMainView()
}
