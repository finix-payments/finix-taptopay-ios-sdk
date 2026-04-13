#!/bin/bash

# Format all Swift files in the project
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./bin/swiftformat --config .swiftformat .
