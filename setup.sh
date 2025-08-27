#!/bin/bash

# Dance & Go Logic Automator Setup Script

echo "🎵 Setting up Dance & Go Logic Automator..."

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p templates
mkdir -p projects
mkdir -p midi_files

# Check if Python dependencies are installed
echo "🔍 Checking Python dependencies..."

# Check for midiutil
if ! python3 -c "import midiutil" 2>/dev/null; then
    echo "📦 Installing midiutil..."
    pip3 install midiutil
else
    echo "✅ midiutil already installed"
fi

# Check for atomacos
if ! python3 -c "import atomacos" 2>/dev/null; then
    echo "📦 Installing atomacos..."
    pip3 install atomacos
else
    echo "✅ atomacos already installed"
fi

# Check for pyobjc
if ! python3 -c "import objc" 2>/dev/null; then
    echo "📦 Installing pyobjc..."
    pip3 install pyobjc
else
    echo "✅ pyobjc already installed"
fi

# Create test MIDI files
echo "🎼 Creating test MIDI files..."
python3 create_test_midi.py

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x dance_go_automator.py
chmod +x create_test_midi.py

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Create a Logic Pro X template project:"
echo "   - Open Logic Pro X"
echo "   - Create new project with Software Instrument"
echo "   - Set up Electric Piano instrument"
echo "   - Save as 'templates/dance_template.logicx'"
echo ""
echo "2. Test the automation:"
echo "   python3 dance_go_automator.py 'dance & go' 124 'A minor' 'test.midi'"
echo ""
echo "3. Check TEMPLATE_SETUP.md for detailed instructions"
echo ""
echo "�� Happy producing!"
