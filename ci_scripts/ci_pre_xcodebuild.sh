#!/bin/sh

#  ci_pre_xcodebuild.sh
#  FinixTapToPaySDK
#
#  Created on 2026-04-06
#

set -e  # Exit immediately if any command fails

# Only execute if archiving using XCode Cloud
if ! [[ "$CI_XCODE_CLOUD" == "TRUE" && "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
  echo "Skipping the process, isXCodeCloud=$CI_XCODE_CLOUD, xcodebuildAction=$CI_XCODEBUILD_ACTION"
  exit 0
fi

# Only execute if building the SDK as the PRIMARY repository, not as a linked dependency
# When SDK is linked to checkout-ios-app, CI_PRIMARY_REPOSITORY_ID will be checkout-ios-app's ID
# We should only release XCFrameworks when building taptopay-ios-sdk directly
if [[ -n "$CI_PRIMARY_REPOSITORY_ID" ]]; then
  # Extract repository name from the ID (format: github.com/org/repo)
  PRIMARY_REPO_NAME=$(echo "$CI_PRIMARY_REPOSITORY_ID" | sed 's/.*\///')
  if [[ "$PRIMARY_REPO_NAME" != "taptopay-ios-sdk" ]]; then
    echo "Skipping simulator archive - SDK is being built as a linked dependency"
    echo "Primary repository: $PRIMARY_REPO_NAME (expected: taptopay-ios-sdk)"
    echo "This prevents unnecessary builds when checkout-ios-app builds trigger SDK archives."
    exit 0
  fi
fi

echo "Starting pre-xcodebuild process for SDK..."

# Apply CI.xcconfig for standalone SDK builds
# This sets SKIP_INSTALL=NO so framework goes to Products/Library/Frameworks for XCFramework creation
echo "Applying CI.xcconfig to FinixTapToPaySDK target..."
cd "$CI_PRIMARY_REPOSITORY_PATH" || exit 1

# Find the xcconfig file reference ID in project.pbxproj
CI_XCCONFIG_ID=$(grep "CI.xcconfig" FinixTapToPaySDK.xcodeproj/project.pbxproj | grep "PBXFileReference" | awk '{print $1}' | tr -d '\t')

if [[ -z "$CI_XCCONFIG_ID" ]]; then
  echo "ERROR: Could not find CI.xcconfig reference in project"
  exit 1
fi

echo "Found CI.xcconfig ID: $CI_XCCONFIG_ID"

# Backup the project file
cp FinixTapToPaySDK.xcodeproj/project.pbxproj FinixTapToPaySDK.xcodeproj/project.pbxproj.backup

# Apply CI.xcconfig and remove explicit SKIP_INSTALL from project settings
# Project-level SKIP_INSTALL overrides xcconfig, so we need to remove it
# Use awk to:
# 1. Insert baseConfigurationReference after isa = XCBuildConfiguration
# 2. Remove explicit SKIP_INSTALL = YES lines from target settings
awk -v xcconfig_id="$CI_XCCONFIG_ID" '
  # Match Debug and Release configurations for the SDK target
  # You may need to adjust these IDs based on your project.pbxproj
  /Debug.*= \{/ && /FinixTapToPaySDK/ { print; in_debug=1; next }
  /Release.*= \{/ && /FinixTapToPaySDK/ { print; in_release=1; next }
  /isa = XCBuildConfiguration;/ && (in_debug || in_release) {
    print "\t\t\tbaseConfigurationReference = " xcconfig_id " /* CI.xcconfig */;"
  }
  # Skip SKIP_INSTALL lines within target configurations (before buildSettings closes)
  (in_debug || in_release) && /SKIP_INSTALL = YES;/ {
    next
  }
  # Reset flags when we exit the buildSettings block
  /\t\t\};$/ && (in_debug || in_release) {
    in_debug=0
    in_release=0
  }
  { print }
' FinixTapToPaySDK.xcodeproj/project.pbxproj > FinixTapToPaySDK.xcodeproj/project.pbxproj.new
mv FinixTapToPaySDK.xcodeproj/project.pbxproj.new FinixTapToPaySDK.xcodeproj/project.pbxproj

echo "CI.xcconfig applied and explicit SKIP_INSTALL removed"

# Archive for x86_64 simulator
echo "Archiving for x86_64 simulator..."
xcodebuild archive \
    -project "$CI_PROJECT_FILE_PATH" \
    -scheme "$CI_XCODE_SCHEME" \
    -arch x86_64 \
    -configuration Release \
    -archivePath "$SIMULATOR_ARCHIVE_PATH" \
    -sdk iphonesimulator \
    -derivedDataPath "$CI_DERIVED_DATA_PATH" \
    SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES  &> /dev/null
