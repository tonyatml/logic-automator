#!/usr/bin/env python3
"""
Simplified Dance & Go Automator
Focuses on core functionality: project creation, MIDI import, and basic setup
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


def createDanceProject(project_name, tempo=124, key="A minor", midi_file=None):
    """
    Main function to create a dance project with all the specified settings
    """
    # Template project path - you'll need to create this
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
    if midi_file and os.path.exists(midi_file):
        print(f"Importing MIDI file: {midi_file}")
        logic.importMidi(midi_file)
        print("MIDI file imported successfully")
    else:
        print("No MIDI file provided or file not found")
    
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
        print("Usage: python3 simple_dance_automator.py <project_name> [tempo] [key] [midi_file]")
        print("Example: python3 simple_dance_automator.py 'dance & go' 124 'A minor' 'test.midi'")
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
