//
//  FilterConfigurationModal.swift
//  logic
//
//  Event filtering configuration modal for Logic Pro automation
//

import SwiftUI

/// Modal for configuring event filtering settings
struct FilterConfigurationModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var monitor: LogicMonitor
    
    // Event type categories for better organization
    private let eventCategories = [
        ("Menu Operations", [
            "AXMenuOpened",
            "AXMenuClosed", 
            "AXMenuItemSelected"
        ]),
        ("Value Changes", [
            "AXValueChanged"
        ]),
        ("Focus & Selection", [
            "AXFocusedUIElementChanged",
            "AXSelectedChildrenChanged"
        ]),
        ("Button Interactions", [
            "AXButtonPressed"
        ]),
        ("Slider Controls", [
            "AXSliderValueChanged"
        ]),
        ("Checkbox/Radio", [
            "AXCheckBoxToggled",
            "AXRadioButtonToggled"
        ])
    ]
    
    // UI Element type categories
    private let elementCategories = [
        ("Interactive Elements", [
            "AXButton",
            "AXMenuItem",
            "AXTextField",
            "AXSlider",
            "AXCheckBox",
            "AXRadioButton"
        ]),
        ("Menu Elements", [
            "AXMenu",
            "AXComboBox"
        ]),
        ("Layout Elements", [
            "AXToolbar",
            "AXTabGroup"
        ])
    ]
    
    // Default high-probability meaningful events (selected by default)
    private let defaultMeaningfulEvents: Set<String> = [
        "AXMenuOpened",
        "AXMenuClosed",
        "AXMenuItemSelected",
        "AXValueChanged",
        "AXFocusedUIElementChanged",
        "AXSelectedChildrenChanged",
        "AXButtonPressed"
    ]
    
    // Default high-probability meaningful elements (selected by default)
    private let defaultMeaningfulElements: Set<String> = [
        "AXButton",
        "AXMenuItem",
        "AXTextField",
        "AXSlider",
        "AXMenu",
        "AXCheckBox",
        "AXRadioButton"
    ]
    
    @State private var selectedEventTypes: Set<String>
    @State private var selectedElementTypes: Set<String>
    @State private var debounceTime: Double = 0.5
    @State private var maxEventsPerSecond: Double = 10
    @State private var strictMode: Bool = false
    
    // UserDefaults keys for persistence
    private let eventTypesKey = "FilterEventTypes"
    private let elementTypesKey = "FilterElementTypes"
    private let debounceTimeKey = "FilterDebounceTime"
    private let maxEventsKey = "FilterMaxEvents"
    private let strictModeKey = "FilterStrictMode"
    
    init(isPresented: Binding<Bool>, monitor: LogicMonitor) {
        self._isPresented = isPresented
        self.monitor = monitor
        
        // Load saved settings or use defaults
        let savedEventTypes = UserDefaults.standard.stringArray(forKey: "FilterEventTypes") ?? []
        let savedElementTypes = UserDefaults.standard.stringArray(forKey: "FilterElementTypes") ?? []
        
        self._selectedEventTypes = State(initialValue: savedEventTypes.isEmpty ? defaultMeaningfulEvents : Set(savedEventTypes))
        self._selectedElementTypes = State(initialValue: savedElementTypes.isEmpty ? defaultMeaningfulElements : Set(savedElementTypes))
        self._debounceTime = State(initialValue: UserDefaults.standard.double(forKey: "FilterDebounceTime") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "FilterDebounceTime"))
        self._maxEventsPerSecond = State(initialValue: UserDefaults.standard.double(forKey: "FilterMaxEvents") == 0 ? 10 : UserDefaults.standard.double(forKey: "FilterMaxEvents"))
        self._strictMode = State(initialValue: UserDefaults.standard.bool(forKey: "FilterStrictMode"))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with action buttons
            HStack {
                Text("Event Filter Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Action buttons in header
                HStack(spacing: 12) {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Apply Settings") {
                        applySettings()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    Text("Select which event types and UI elements to monitor. Unselected items will be filtered out as noise.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Event Types Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Event Types to Monitor")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ForEach(eventCategories, id: \.0) { category, events in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                    ForEach(events, id: \.self) { eventType in
                                        HStack {
                                            Button(action: {
                                                toggleEventType(eventType)
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: selectedEventTypes.contains(eventType) ? "checkmark.square.fill" : "square")
                                                        .foregroundColor(selectedEventTypes.contains(eventType) ? .blue : .gray)
                                                    
                                                    Text(eventType)
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // UI Element Types Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("UI Element Types to Monitor")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ForEach(elementCategories, id: \.0) { category, elements in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                    ForEach(elements, id: \.self) { elementType in
                                        HStack {
                                            Button(action: {
                                                toggleElementType(elementType)
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: selectedElementTypes.contains(elementType) ? "checkmark.square.fill" : "square")
                                                        .foregroundColor(selectedElementTypes.contains(elementType) ? .blue : .gray)
                                                    
                                                    Text(elementType)
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Advanced Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Settings")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Debounce Time:")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(debounceTime, specifier: "%.1f")s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            Slider(value: $debounceTime, in: 0.1...2.0, step: 0.1)
                                .padding(.horizontal, 20)
                                .help("Prevent duplicate events within this time window")
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Max Events Per Second:")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(Int(maxEventsPerSecond))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            Slider(value: $maxEventsPerSecond, in: 1...50, step: 1)
                                .padding(.horizontal, 20)
                                .help("Rate limit to prevent event spam")
                        }
                        
                        HStack {
                            Toggle("Strict Mode", isOn: $strictMode)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("More aggressive filtering")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helper Functions
    
    private func toggleEventType(_ eventType: String) {
        if selectedEventTypes.contains(eventType) {
            selectedEventTypes.remove(eventType)
        } else {
            selectedEventTypes.insert(eventType)
        }
    }
    
    private func toggleElementType(_ elementType: String) {
        if selectedElementTypes.contains(elementType) {
            selectedElementTypes.remove(elementType)
        } else {
            selectedElementTypes.insert(elementType)
        }
    }
    
    private func resetToDefaults() {
        selectedEventTypes = defaultMeaningfulEvents
        selectedElementTypes = defaultMeaningfulElements
        debounceTime = 0.5
        maxEventsPerSecond = 10
        strictMode = false
        
        // Clear saved settings
        UserDefaults.standard.removeObject(forKey: eventTypesKey)
        UserDefaults.standard.removeObject(forKey: elementTypesKey)
        UserDefaults.standard.removeObject(forKey: debounceTimeKey)
        UserDefaults.standard.removeObject(forKey: maxEventsKey)
        UserDefaults.standard.removeObject(forKey: strictModeKey)
    }
    
    private func applySettings() {
        // Save settings to UserDefaults
        UserDefaults.standard.set(Array(selectedEventTypes), forKey: eventTypesKey)
        UserDefaults.standard.set(Array(selectedElementTypes), forKey: elementTypesKey)
        UserDefaults.standard.set(debounceTime, forKey: debounceTimeKey)
        UserDefaults.standard.set(maxEventsPerSecond, forKey: maxEventsKey)
        UserDefaults.standard.set(strictMode, forKey: strictModeKey)
        
        // Create new configuration
        var config = FilteringConfiguration()
        config.meaningfulEventTypes = selectedEventTypes
        config.meaningfulRoles = selectedElementTypes
        config.debounceTime = debounceTime
        config.maxEventsPerSecond = Int(maxEventsPerSecond)
        config.strictMode = strictMode
        
        // Apply to monitor
        monitor.updateFilterConfiguration(config)
    }
}

#Preview {
    FilterConfigurationModal(isPresented: .constant(true), monitor: LogicMonitor())
}
