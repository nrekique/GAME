#!/bin/sh
# Utility script to set the active build profile in project.godot.
# Usage: ./scripts/build_profile.sh <fast-iteration|playtest|shipping>
# The value is stored under [application]build_profile and can be read
# at runtime via ProjectSettings.get_setting("application/build_profile").

set -e

PROFILE="$1"
if [ -z "$PROFILE" ]; then
    echo "Usage: $0 <fast-iteration|playtest|shipping>"
    exit 1
fi

FILE="project.godot"

# ensure the project file exists
if [ ! -f "$FILE" ]; then
    echo "error: $FILE not found (run from project root)"
    exit 1
fi

# update existing entry or insert after [application] header
if grep -q '^build_profile=' "$FILE"; then
    sed -i.bak "s/^build_profile=.*/build_profile=\"$PROFILE\"/" "$FILE"
else
    awk -v prof="$PROFILE" '
        /^\[application\]/ {print; print "build_profile=\"" prof "\""; next}
        {print}
    ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
fi

echo "Set build_profile to $PROFILE in $FILE"
