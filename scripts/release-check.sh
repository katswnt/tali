#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(dirname "$script_directory")
simulator_destination=${TALI_DESTINATION:-generic/platform=iOS Simulator}

cd "$repository_root"

echo "Checking generated Xcode project"
xcodegen generate
git diff --exit-code -- Tali.xcodeproj/project.pbxproj App/Info.plist MessagesExtension/Info.plist
git diff --check

echo "Running Swift domain tests"
swift test --scratch-path .build-spm

echo "Running Worker, D1, and integration checks"
(
  cd Server
  npm ci
  npm run test:release
)

echo "Building the iOS app and Messages extension"
xcodebuild \
  -project Tali.xcodeproj \
  -scheme Tali \
  -destination "$simulator_destination" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Tali release checks passed"
