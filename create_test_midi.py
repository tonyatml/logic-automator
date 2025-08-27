#!/usr/bin/env python3
"""
Create test MIDI file with chord progressions for dance music
"""

from midiutil import MIDIFile
import sys


def create_dance_chord_progression(output_file="test.midi"):
    """
    Create a MIDI file with a typical dance chord progression in A minor
    Am - F - C - G (i - VI - III - VII)
    """
    
    # Create MIDI file
    midi = MIDIFile(1)  # One track
    
    # Set tempo
    tempo = 124  # BPM
    midi.addTempo(0, 0, tempo)
    
    # A minor chord progression
    # Am (A, C, E), F (F, A, C), C (C, E, G), G (G, B, D)
    chords = [
        [57, 60, 64],  # Am - A3, C4, E4
        [53, 57, 60],  # F  - F3, A3, C4  
        [48, 52, 55],  # C  - C3, E3, G3
        [50, 54, 57],  # G  - G3, B3, D4
    ]
    
    # Time settings
    time = 0
    duration = 2  # 2 beats per chord
    volume = 80
    
    # Add chords to MIDI
    for chord in chords:
        for note in chord:
            midi.addNote(0, 0, note, time, duration, volume)
        time += duration
    
    # Write to file
    with open(output_file, "wb") as output:
        midi.writeFile(output)
    
    print(f"Created dance chord progression: {output_file}")
    print("Chord progression: Am - F - C - G (8 beats total)")


def create_techno_chord_progression(output_file="techno_chords.midi"):
    """
    Create a MIDI file with a techno-style chord progression
    """
    
    # Create MIDI file
    midi = MIDIFile(1)
    
    # Set tempo
    tempo = 124
    midi.addTempo(0, 0, tempo)
    
    # Techno chord progression (more repetitive)
    # Am - Am - F - F - C - C - G - G
    chords = [
        [57, 60, 64],  # Am
        [57, 60, 64],  # Am
        [53, 57, 60],  # F
        [53, 57, 60],  # F
        [48, 52, 55],  # C
        [48, 52, 55],  # C
        [50, 54, 57],  # G
        [50, 54, 57],  # G
    ]
    
    # Time settings
    time = 0
    duration = 1  # 1 beat per chord (more techno-like)
    volume = 80
    
    # Add chords to MIDI
    for chord in chords:
        for note in chord:
            midi.addNote(0, 0, note, time, duration, volume)
        time += duration
    
    # Write to file
    with open(output_file, "wb") as output:
        midi.writeFile(output)
    
    print(f"Created techno chord progression: {output_file}")
    print("Chord progression: Am-Am-F-F-C-C-G-G (8 beats total)")


def main():
    """
    Create different types of MIDI files
    """
    if len(sys.argv) > 1:
        output_file = sys.argv[1]
    else:
        output_file = "test.midi"
    
    print("Creating MIDI chord progressions...")
    
    # Create basic dance progression
    create_dance_chord_progression("test.midi")
    
    # Create techno progression
    create_techno_chord_progression("techno_chords.midi")
    
    print("\nMIDI files created successfully!")
    print("You can now use these files with the dance_go_automator.py script:")
    print("python3 dance_go_automator.py 'dance & go' 124 'A minor' 'test.midi'")


if __name__ == "__main__":
    main()
