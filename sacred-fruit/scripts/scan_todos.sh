#!/bin/zsh
# search the project for TODO comments and fail if any are found
# ignores binary/metadata directories (.godot, addons/func_godot/fgd if needed)

set -e

echo "Scanning for TODOs..."

# gather list of GDScript files while skipping directories we don't care about
matches=$(find . -type f -name '*.gd' \
    -not -path './.git/*' \
    -not -path './.godot/*' \
    -not -path './docs/*' \
    -not -path './addons/func_godot/*' \
    -not -name 'scan_todos.sh' \
    -exec grep -nH 'TODO' {} + || true)

if [ -n "$matches" ]; then
    echo "Found TODOs in the following locations:"
    echo "$matches"
    echo "Please address or move these items before merging."
    exit 1
else
    echo "No TODO comments found."
fi
