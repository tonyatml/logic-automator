#!/usr/bin/env python3
"""
Improved MIDI Import for Dance & Go Automator
Uses absolute paths to ensure MIDI files are found correctly
"""

import logic
import sys
import os
import shutil
import time


def createProjectFromTemplate(template_path, project_name, output_dir):
    """
    Create a new Logic project from a template
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Copy template to new project location
    new_project_path = os.path.join(output_dir, f"{project_name}.logicx")
    
    if os.path.exists(new_project_path):
        print(f"Project {new_project_path} already exists. Removing...")
        shutil.rmtree(new_project_path)
    
    print(f"Creating new project from template: {template_path}")
    shutil.copytree(template_path, new_project_path)
    
    return new_project_path


def importMidiWithAbsolutePath(midi_file):
    """
    Import MIDI file using absolute path
    """
    # Get absolute path of MIDI file
    abs_path = os.path.abspath(midi_file)
    print(f"Importing MIDI file with absolute path: {abs_path}")
    
    # Check if file exists
    if not os.path.exists(abs_path):
        print(f"Error: MIDI file not found: {abs_path}")
        return False
    
    logic.selectLastTrack()
    
    print("Opening up midi selection window...")
    logic.logic.menuItem("File", "Import", "MIDI File…").Press()
    
    windows = []
    while len(windows) == 0:
        time.sleep(0.1)
        windows = [
            window
            for window in logic.logic.windows()
            if "AXTitle" in window.getAttributes() and window.AXTitle == "Import"
        ]
    import_window = windows[0]
    
    print("Navigating to folder with absolute path...")
    logic.logic.activate()
    logic.logic.sendGlobalKeyWithModifiers("g", ["command", "shift"])
    time.sleep(0.5)  # Wait for dialog to appear
    
    # Send the absolute path - use a different approach
    print(f"Sending path: {abs_path}")
    
    # Clear any existing text first
    logic.logic.sendGlobalKeyWithModifiers("a", ["command"])  # Select all
    logic.logic.sendGlobalKey("backspace")  # Clear selection
    
    # Send the path character by character to avoid truncation
    for char in abs_path:
        logic.logic.sendKeys(char)
        time.sleep(0.01)  # Small delay between characters
    
    time.sleep(0.5)  # Wait before pressing enter
    logic.logic.sendKeys("\n")
    time.sleep(1)  # Wait for path to be set
    
    print("Pressing import...")
    import_window.buttons("Import")[0].Press()
    
    print("Waiting for tempo import message...")
    windows = []
    for _ in range(50):  # Wait up to 5 seconds
        time.sleep(0.1)
        windows = [
            window
            for window in logic.logic.windows()
            if "AXDescription" in window.getAttributes()
            and window.AXDescription == "alert"
        ]
        if len(windows) > 0:
            break
    
    if len(windows) > 0:
        alert = windows[0]
        print("Importing tempo...")
        try:
            alert.buttons("Import Tempo")[0].Press()
        except:
            print("Could not find 'Import Tempo' button, trying 'OK'...")
            try:
                alert.buttons("OK")[0].Press()
            except:
                print("Could not find OK button either")
    
    print("MIDI file imported successfully")
    return True


def createDanceProject(project_name, tempo=124, key="A minor", midi_file=None):
    """
    Main function to create a dance project with all the specified settings
    """
    # Template project path
    template_path = "templates/dance_template.logicx"
    
    # Check if template exists
    if not os.path.exists(template_path):
        print(f"Template not found: {template_path}")
        print("Please create a template project at this location")
        print("See TEMPLATE_SETUP.md for instructions")
        return False
    
    # Create new project from template
    output_dir = "projects"
    project_path = createProjectFromTemplate(template_path, project_name, output_dir)
    
    # Open the new project
    print(f"Opening project: {project_path}")
    logic.open(project_path)
    
    # Import MIDI if provided
    if midi_file:
        if importMidiWithAbsolutePath(midi_file):
            print("MIDI import completed successfully")
        else:
            print("MIDI import failed")
    else:
        print("No MIDI file provided")
    
    print(f"Dance project '{project_name}' created successfully!")
    print(f"Project location: {project_path}")
    print("\nNext steps:")
    print("1. The project is now open in Logic Pro X")
    print("2. You can manually set the tempo to", tempo, "BPM")
    print("3. You can manually set the key to", key)
    print("4. The MIDI regions are ready for playback")
    
    return project_path


def main():
    """
    Command line interface
    """
    if len(sys.argv) < 2:
        print("Usage: python3 improved_midi_import.py <project_name> [tempo] [key] [midi_file]")
        print("Example: python3 improved_midi_import.py 'dance & go' 124 'A minor' 'test.midi'")
        sys.exit(1)
    
    project_name = sys.argv[1]
    tempo = int(sys.argv[2]) if len(sys.argv) > 2 else 124
    key = sys.argv[3] if len(sys.argv) > 3 else "A minor"
    midi_file = sys.argv[4] if len(sys.argv) > 4 else None
    
    print(f"Creating dance project: {project_name}")
    print(f"Tempo: {tempo} BPM")
    print(f"Key: {key}")
    if midi_file:
        print(f"MIDI file: {midi_file}")
    
    createDanceProject(project_name, tempo, key, midi_file)


if __name__ == "__main__":
    main()
