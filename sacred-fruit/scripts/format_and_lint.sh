#!/bin/zsh
# run GDScript formatter and basic lint checks
# requires 'gdformat' available (pip install gdformat)

echo "Formatting all .gd files..."
if command -v gdformat >/dev/null 2>&1; then
    gdformat -r -i "$(pwd)"/**/*.gd
else
    echo "warning: gdformat not found; install with 'pip install gdformat'"
fi

echo "Running Godot static analyzer (if available)..."
if command -v godot >/dev/null 2>&1; then
    # if godot-lint script is available, run it
    if command -v godot-lint >/dev/null 2>&1; then
        if ! godot-lint "$(pwd)"/**/*.gd; then
            echo "error: lint warnings detected"
            exit 1
        fi
    else
        echo "warning: godot-lint not found; consider installing via 'pip install godot-lint'"
        # lint step is optional, continue gracefully
    fi
else
    echo "warning: godot executable not on PATH"
    exit 1
fi
