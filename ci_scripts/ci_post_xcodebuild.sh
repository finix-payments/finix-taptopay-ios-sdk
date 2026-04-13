#!/bin/sh

#  ci_post_xcodebuild.sh
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
    echo "Skipping XCFramework release - SDK is being built as a linked dependency"
    echo "Primary repository: $PRIMARY_REPO_NAME (expected: taptopay-ios-sdk)"
    echo "This prevents unwanted releases when checkout-ios-app builds trigger SDK archives."
    exit 0
  fi
fi

# Restore original project.pbxproj if backup exists
if [[ -f "$CI_PRIMARY_REPOSITORY_PATH/FinixTapToPaySDK.xcodeproj/project.pbxproj.backup" ]]; then
  echo "Restoring original project.pbxproj..."
  mv "$CI_PRIMARY_REPOSITORY_PATH/FinixTapToPaySDK.xcodeproj/project.pbxproj.backup" "$CI_PRIMARY_REPOSITORY_PATH/FinixTapToPaySDK.xcodeproj/project.pbxproj"
  echo "Project file restored"
fi

echo "Starting post-xcodebuild process for SDK..."

# Check if the archives were successful
if ! [[ -d "$CI_ARCHIVE_PATH" && -d "$SIMULATOR_ARCHIVE_PATH" ]]; then
  echo "Archive not found, CI_ARCHIVE_PATH=$CI_ARCHIVE_PATH, SIMULATOR_ARCHIVE_PATH=$SIMULATOR_ARCHIVE_PATH"
  exit 1
fi

# Create the xcframework
echo "Creating xcframework..."
XCFRAMEWORK_TEMP_PATH="$CI_WORKSPACE_PATH/xcframeworks/$CI_XCODE_SCHEME.xcframework"

xcodebuild -create-xcframework \
    -archive "$CI_ARCHIVE_PATH" -framework "$CI_XCODE_SCHEME.framework" \
    -archive "$SIMULATOR_ARCHIVE_PATH" -framework "$CI_XCODE_SCHEME.framework" \
    -output "$XCFRAMEWORK_TEMP_PATH"

# Remove ci_pre_xcodebuild.sh and ci_post_xcodebuild.sh files from the xcframework
echo "Removing script files..."
rm -rf "$XCFRAMEWORK_TEMP_PATH/ios-arm64/$CI_XCODE_SCHEME.framework/ci_pre_xcodebuild.sh"
rm -rf "$XCFRAMEWORK_TEMP_PATH/ios-arm64/$CI_XCODE_SCHEME.framework/ci_post_xcodebuild.sh"

rm -rf "$XCFRAMEWORK_TEMP_PATH/ios-x86_64-simulator/$CI_XCODE_SCHEME.framework/ci_pre_xcodebuild.sh"
rm -rf "$XCFRAMEWORK_TEMP_PATH/ios-x86_64-simulator/$CI_XCODE_SCHEME.framework/ci_post_xcodebuild.sh"

# Sign the xcframework
echo "Signing the xcframework..."
xcrun codesign --force --sign - --timestamp=none "$XCFRAMEWORK_TEMP_PATH"
echo "Checking signature after signing..."
codesign -dv "$XCFRAMEWORK_TEMP_PATH" &> /dev/null

# Push to FinixTapToPaySDK SPM repo
SPM_REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/finix-payments/finix-taptopay-ios-sdk"
SPM_REPO_TEMP_PATH="$CI_WORKSPACE_PATH/spm_repo"

echo "Cloning SPM repository..."
git clone "$SPM_REPO_URL" "$SPM_REPO_TEMP_PATH"

echo "Replacing xcframework in SPM repo..."
rm -rf "$SPM_REPO_TEMP_PATH/Sources/$CI_XCODE_SCHEME.xcframework"
cp -R "$XCFRAMEWORK_TEMP_PATH" "$SPM_REPO_TEMP_PATH/Sources/"

cd "$SPM_REPO_TEMP_PATH"
git config user.name "finix-devops-sa"
git config user.email "devops-git@finixpayments.com"
git add .

# Check if CI_TAG is provided (for release builds) or not (for regular builds)
if [[ -n "$CI_TAG" && "$CI_TAG" != "" ]]; then
    # Release build with tag - create version and tag
    VERSION="$CI_TAG"
    echo "Updating SPM repo with version $VERSION..."
    git commit -m "Update $CI_XCODE_SCHEME.xcframework to version $VERSION"
    git push origin main

    echo "Tagging new version..."
    git tag -a "$VERSION" -m "Version $VERSION"
    git push origin "$VERSION"

    echo "Release deployment complete! Version $VERSION is now available."
else
    # Regular build without tag - just update xcframework
    echo "Updating SPM repo on main branch..."
    git commit -m "Update $CI_XCODE_SCHEME.xcframework at $CI_COMMIT"
    git push origin main

    echo "Development deployment to main branch complete!"
fi

exit 0
