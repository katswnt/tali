#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(dirname "$script_directory")
destination=${TALI_UI_DESTINATION:-}

if [ -z "$destination" ]; then
    booted_id=$(xcrun simctl list devices booted | sed -nE 's/.*\(([0-9A-F-]{36})\) \(Booted\).*/\1/p' | head -n 1)
    if [ -z "$booted_id" ]; then
        echo "Boot an iPhone simulator or set TALI_UI_DESTINATION." >&2
        exit 2
    fi
    destination="platform=iOS Simulator,id=$booted_id"
fi

cd "$repository_root"
xcodegen generate
xcodebuild \
    -project Tali.xcodeproj \
    -scheme Tali \
    -destination "$destination" \
    -only-testing:TaliUITests \
    test
