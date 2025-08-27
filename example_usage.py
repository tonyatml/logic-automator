#!/usr/bin/env python3
"""
Example usage of the Dance & Go Logic Automator
"""

import os
import sys
from dance_go_automator import createDanceProject


def main():
    """
    Example usage of the dance project creator
    """
    print("🎵 Dance & Go Logic Automator - Example Usage")
    print("=" * 50)
    
    # Example 1: Basic dance project
    print("\n1. Creating basic dance project...")
    try:
        project_path = createDanceProject(
            project_name="dance & go",
            tempo=124,
            key="A minor"
        )
        print(f"✅ Project created: {project_path}")
    except Exception as e:
        print(f"❌ Error: {e}")
        print("💡 Make sure you have created the template project first!")
    
    # Example 2: Techno project with MIDI
    print("\n2. Creating techno project with MIDI...")
    if os.path.exists("techno_chords.midi"):
        try:
            project_path = createDanceProject(
                project_name="techno dance",
                tempo=128,
                key="A minor",
                midi_file="techno_chords.midi"
            )
            print(f"✅ Techno project created: {project_path}")
        except Exception as e:
            print(f"❌ Error: {e}")
    else:
        print("⚠️  MIDI file not found. Run 'python3 create_test_midi.py' first.")
    
    # Example 3: Different key and tempo
    print("\n3. Creating project in different key...")
    try:
        project_path = createDanceProject(
            project_name="house vibes",
            tempo=120,
            key="C major",
            midi_file="test.midi"
        )
        print(f"✅ House project created: {project_path}")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print("\n🎉 Examples completed!")
    print("\n📋 To use this yourself:")
    print("1. Create template: Follow TEMPLATE_SETUP.md")
    print("2. Run: python3 dance_go_automator.py 'your_project' 124 'A minor' 'your_midi.midi'")


if __name__ == "__main__":
    main()
