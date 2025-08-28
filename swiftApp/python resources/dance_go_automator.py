#!/usr/bin/env python3
"""
Dance & Go Automator
Creates a new dance production project from a template, sets tempo/key, 
imports MIDI chord progressions, and sets up playback.
"""

import logic
import sys
import os
import shutil
import time
import atomacos
from pathlib import Path

# Get the directory where this script is located
def get_script_directory():
    """Get the directory where this script is located"""
    # When running from Swift app bundle, __file__ will be the path in the bundle
    script_path = os.path.abspath(__file__)
    script_dir = os.path.dirname(script_path)
    return script_dir

# Get the bundle resources directory
def get_bundle_resources_directory():
    """Get the bundle resources directory where this script is located"""
    script_dir = get_script_directory()
    # The script should be in the bundle's Contents/Resources directory
    return script_dir

# Get the project root directory (where the main project files are)
def get_project_root():
    """Get the project root directory"""
    # When running from Swift app, we need to find the project root
    # If current working directory is not writable or doesn't exist, use Desktop
    cwd = os.getcwd()
    
    # Check if current directory is writable
    if os.access(cwd, os.W_OK):
        return cwd
    else:
        # Use Desktop as fallback
        desktop_path = os.path.expanduser("~/Desktop")
        print(f"Current directory not writable, using Desktop: {desktop_path}")
        return desktop_path


def createProjectFromTemplate(template_path, project_name, output_dir):
    """
    Create a new Logic project from a template
    """
    try:
        # Validate template path
        if not os.path.exists(template_path):
            print(f"Template not found: {template_path}")
            return None
        
        # Create output directory if it doesn't exist
        print(f"Creating output directory: {output_dir}")
        os.makedirs(output_dir, exist_ok=True)
        
        # Check if output directory is writable
        if not os.access(output_dir, os.W_OK):
            print(f"Output directory not writable: {output_dir}")
            return None
        
        # Copy template to new project location
        new_project_path = os.path.join(output_dir, f"{project_name}.logicx")
        
        if os.path.exists(new_project_path):
            print(f"Project {new_project_path} already exists. Removing...")
            shutil.rmtree(new_project_path)
        
        print(f"Creating new project from template: {template_path}")
        print(f"New project path: {new_project_path}")
        shutil.copytree(template_path, new_project_path)
        
        print(f"Project created successfully: {new_project_path}")
        return new_project_path
        
    except Exception as e:
        print(f"Error creating project: {e}")
        return None


def setProjectTempo(bpm):
    """
    Set the project tempo using Logic's tempo display
    """
    print(f"Setting tempo to {bpm} BPM...")
    logic.logic.activate()
    
    # Open the tempo display (usually in the transport bar)
    # This is a simplified approach - we'll click on the tempo display
    # and type the new tempo
    
    # Find the main window
    main_window = None
    try:
        for window in logic.logic.windows():
            if "AXTitle" in window.getAttributes() and "Tracks" in window.AXTitle:
                main_window = window
                break
    except Exception as e:
        print(f"Error finding Logic windows: {e}")
        return False
    
    if not main_window:
        print("Could not find main Logic window")
        return False
    
    # Look for tempo display in the transport area
    # This is a simplified approach - in practice you'd need to find the exact UI element
    try:
        # Try to find tempo-related elements
        tempo_elements = main_window.findAllR(AXRole="AXStaticText")
        for element in tempo_elements:
            if "AXValue" in element.getAttributes():
                value = element.AXValue
                if isinstance(value, str) and "BPM" in value or value.isdigit():
                    print(f"Found tempo element: {value}")
                    # Click on it and type new tempo
                    logic.logic.activate()
                    atomacos.mouse.click(x=element.AXPosition.x + 5, y=element.AXPosition.y + 5)
                    time.sleep(0.1)
                    logic.logic.sendKeys(str(bpm))
                    logic.logic.sendKeys("\n")
                    print(f"Tempo set to {bpm} BPM")
                    return True
    except Exception as e:
        print(f"Error setting tempo: {e}")
    
    print("Could not find tempo display, using alternative method...")
    # Alternative: Use Logic's menu to set tempo
    try:
        logic.logic.menuItem("Project", "Tempo", f"{bpm} BPM").Press()
        print(f"Tempo set to {bpm} BPM via menu")
        return True
    except Exception as e:
        print(f"Could not set tempo via menu: {e}")
        return False


def setProjectKey(key):
    """
    Set the project key signature
    """
    print(f"Setting key to {key}...")
    logic.logic.activate()
    
    try:
        # Try to set key via menu
        logic.logic.menuItem("Project", "Key Signature", key).Press()
        print(f"Key set to {key}")
        return True
    except Exception as e:
        print(f"Could not set key via menu: {e}")
        # Alternative: Use the key signature display
        try:
            main_window = None
            try:
                for window in logic.logic.windows():
                    if "AXTitle" in window.getAttributes() and "Tracks" in window.AXTitle:
                        main_window = window
                        break
            except Exception as e:
                print(f"Error finding Logic windows: {e}")
                return False
            
            if main_window:
                key_elements = main_window.findAllR(AXRole="AXStaticText")
                for element in key_elements:
                    if "AXValue" in element.getAttributes():
                        value = element.AXValue
                        if isinstance(value, str) and any(k in value.upper() for k in ["C", "D", "E", "F", "G", "A", "B", "MINOR", "MAJOR"]):
                            print(f"Found key element: {value}")
                            atomacos.mouse.click(x=element.AXPosition.x + 5, y=element.AXPosition.y + 5)
                            time.sleep(0.1)
                            logic.logic.sendKeys(key)
                            logic.logic.sendKeys("\n")
                            print(f"Key set to {key}")
                            return True
        except Exception as e:
            print(f"Could not set key: {e}")
    
    return False


def setupElectricPiano():
    """
    Set up an Electric Piano instrument on the current track
    """
    print("Setting up Electric Piano instrument...")
    
    # Electric Piano path in Logic's instrument menu
    electric_piano_path = ["AU Instruments", "Logic Pro X", "Electric Piano", "Stereo"]
    
    try:
        logic.selectInstrument(electric_piano_path)
        print("Electric Piano instrument selected")
        return True
    except Exception as e:
        print(f"Could not select Electric Piano: {e}")
        # Try alternative path
        try:
            alt_path = ["AU Instruments", "Logic Pro X", "Electric Piano"]
            logic.selectInstrument(alt_path)
            print("Electric Piano instrument selected (alternative path)")
            return True
        except Exception as e2:
            print(f"Could not select Electric Piano with alternative path: {e2}")
            return False


def setCycleRegion(start_bar=1, end_bar=4):
    """
    Set the transport cycle region to loop the imported MIDI
    """
    print(f"Setting cycle region from bar {start_bar} to {end_bar}...")
    logic.logic.activate()
    
    try:
        # Select the imported region first
        logic.selectAllRegions()
        
        # Set cycle region to match the selected region
        # Logic shortcut: Cmd+L to set cycle region to selection
        logic.logic.sendGlobalKeyWithModifiers("l", ["command"])
        print("Cycle region set to match imported MIDI")
        return True
    except Exception as e:
        print(f"Could not set cycle region: {e}")
        return False


def startPlayback():
    """
    Start playback
    """
    print("Starting playback...")
    logic.logic.activate()
    
    try:
        # Space bar to start/stop playback
        logic.logic.sendGlobalKey(" ")
        print("Playback started")
        return True
    except Exception as e:
        print(f"Could not start playback: {e}")
        return False


def createDanceProject(project_name, tempo=124, key="A minor", midi_file=None):
    """
    Main function to create a dance project with all the specified settings
    """
    # Get the bundle resources directory where templates are stored
    bundle_resources = get_bundle_resources_directory()
    template_path = os.path.join(bundle_resources,"dance_template.logicx")
    
    # Debug information
    print("=== Path Information ===")
    print(f"Script directory: {get_script_directory()}")
    print(f"Bundle resources: {bundle_resources}")
    print(f"Project root: {get_project_root()}")
    print(f"Template path: {template_path}")
    print(f"Template exists: {os.path.exists(template_path)}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Current directory writable: {os.access(os.getcwd(), os.W_OK)}")
    print("========================")
    
    # Check if template exists
    if not os.path.exists(template_path):
        print(f"Template not found: {template_path}")
        print("Please ensure the template is in the bundle's templates directory")
        return False
    
    # Create new project from template
    project_root = get_project_root()
    output_dir = os.path.join(project_root, "projects")
    project_path = createProjectFromTemplate(template_path, project_name, output_dir)
    
    if project_path is None:
        print("Failed to create project from template")
        return None
    
    # Open the new project
    logic.open(project_path)
    
    # logic.newTrack()

    # Set project tempo
    # if not setProjectTempo(tempo):
    #    print("Warning: Could not set tempo")
    
    # Set project key
    # if not setProjectKey(key):
    #    print("Warning: Could not set key")
    
    # Import MIDI if provided
    if midi_file:
        # Handle both relative and absolute paths for MIDI file
        original_midi_path = midi_file
        if not os.path.isabs(midi_file):
            # If it's a relative path, try to find it in the project root
            midi_file = os.path.join(project_root, midi_file)
        
        if os.path.exists(midi_file):
            print(f"Importing MIDI file: {midi_file}")
            logic.importMidi(midi_file)
            time.sleep(2)
        else:
            print(f"MIDI file not found: {original_midi_path}")
            print(f"Tried path: {midi_file}")
            print("Please provide the full path to the MIDI file")
        
       
    else:
        print("No MIDI file provided or file not found")
    
    print(f"Dance project '{project_name}' created successfully!")
    print(f"Project location: {project_path}")
    
    return project_path


def main():
    """
    Command line interface
    """
    if len(sys.argv) < 2:
        print("Usage: python3 dance_go_automator.py <project_name> [tempo] [key] [midi_file]")
        print("Example: python3 dance_go_automator.py 'dance & go' 124 'A minor' 'test.midi'")
        sys.exit(1)
    
    project_name = sys.argv[1]
    tempo = int(sys.argv[2]) if len(sys.argv) > 2 else 124
    key = sys.argv[3] if len(sys.argv) > 3 else "A minor"
    midi_file = sys.argv[4] if len(sys.argv) > 4 else os.path.expanduser("~/Desktop/test.midi")
    
    print(f"Creating dance project: {project_name}")
    print(f"Tempo: {tempo} BPM")
    print(f"Key: {key}")
    if midi_file:
        print(f"MIDI file: {midi_file}")
    
    createDanceProject(project_name, tempo, key, midi_file)


if __name__ == "__main__":
    main()
