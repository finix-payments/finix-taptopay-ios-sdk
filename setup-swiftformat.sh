#!/bin/bash

# DO NOT UPGRADE SWIFTFORMAT BEYOND 0.52.10. KEEP LOCAL AND CI LOCKED TO THIS VERSION.
# To update, coordinate with the team and update both local and CI together.
#
# This script installs SwiftFormat 0.52.10 for local use (bin/swiftformat)

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NO_COLOR="\033[0m"

echo -e "${BOLD}${BLUE}SwiftFormat Setup Script${NO_COLOR}"
echo "=================================================="
echo

# Navigate to the project root directory
cd "$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT=$(pwd)

# Create bin directory if it doesn't exist
mkdir -p bin

# Install SwiftFormat
echo -e "${BOLD}Checking SwiftFormat installation...${NO_COLOR}"
if ! command -v ./bin/swiftformat &> /dev/null; then
    echo -e "${YELLOW}SwiftFormat not found. Downloading...${NO_COLOR}"

    # Download the latest SwiftFormat binary
    echo "Downloading SwiftFormat 0.52.10 binary..."
    curl -L https://github.com/nicklockwood/SwiftFormat/releases/download/0.52.10/swiftformat.zip -o swiftformat.zip

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download SwiftFormat.${NO_COLOR}"
        exit 1
    fi

    # Unzip the binary
    echo "Extracting..."
    unzip -o swiftformat.zip -d bin/

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract SwiftFormat.${NO_COLOR}"
        exit 1
    fi

    # Make it executable
    chmod +x bin/swiftformat

    # Clean up
    rm swiftformat.zip

    echo -e "${GREEN}✓ SwiftFormat installed successfully${NO_COLOR}"
else
    SWIFTFORMAT_VERSION=$(./bin/swiftformat --version)
    echo -e "${GREEN}✓ SwiftFormat is already installed: ${SWIFTFORMAT_VERSION}${NO_COLOR}"
fi
echo

# Create scripts directory if it doesn't exist
mkdir -p scripts

# Create format script
echo -e "${BOLD}Creating format scripts...${NO_COLOR}"
cat > scripts/format.sh << 'EOF'
#!/bin/bash

# Format all Swift files in the project
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./bin/swiftformat --config .swiftformat .
EOF

# Create modified-only format script
cat > scripts/format-modified.sh << 'EOF'
#!/bin/bash

# Format only modified Swift files
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODIFIED_FILES=$(git diff --name-only --diff-filter=ACMR | grep -E "\.swift$")

if [ -z "$MODIFIED_FILES" ]; then
  echo "No modified Swift files found."
  exit 0
fi

echo "$MODIFIED_FILES" | xargs ./bin/swiftformat
EOF

# Make scripts executable
chmod +x scripts/format.sh scripts/format-modified.sh
echo -e "${GREEN}✓ Format scripts created and made executable${NO_COLOR}"
echo

# Final instructions
echo -e "${BOLD}${GREEN}SwiftFormat setup completed successfully!${NO_COLOR}"
echo
echo -e "${BOLD}Usage:${NO_COLOR}"
echo -e "${BOLD}${BLUE}./scripts/format.sh${NO_COLOR} - Format all Swift files in the project"
echo -e "${BOLD}${BLUE}./scripts/format-modified.sh${NO_COLOR} - Format only modified Swift files"
echo
echo -e "${YELLOW}Note: SwiftFormat runs manually. Run ./scripts/format.sh before committing.${NO_COLOR}"
echo -e "${YELLOW}CI will verify formatting on PRs.${NO_COLOR}"
echo "=================================================="
