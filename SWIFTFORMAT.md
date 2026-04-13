# SwiftFormat Setup

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) 0.52.10 for consistent code formatting.

## Initial Setup

Run the setup script to install SwiftFormat:

```bash
./setup-swiftformat.sh
```

This will:
- Download SwiftFormat 0.52.10 binary to `bin/swiftformat`
- Create formatting scripts in `scripts/`

## Usage

⚠️ **IMPORTANT**: SwiftFormat is run **manually** before committing. Run formatting before you commit to avoid conflicts.

### Format All Files (Recommended before committing)

```bash
./scripts/format.sh
```

### Format Only Modified Files

```bash
./scripts/format-modified.sh
```

### Manual Formatting

```bash
./bin/swiftformat --config .swiftformat .
```

## Workflow

1. Make your code changes
2. **Run `./scripts/format.sh`** before committing
3. Review the formatted changes with `git diff`
4. Commit your changes
5. CI will verify formatting on your PR

## CI Integration

GitHub Actions will automatically check formatting on pull requests. If formatting issues are found:

1. Run `./scripts/format.sh` locally
2. Commit the changes
3. Push to your branch

## Configuration

SwiftFormat configuration is in `.swiftformat`. Key settings:

- **Swift version**: 5.9
- **Indentation**: 4 spaces
- **Max line width**: 100 characters
- **Line endings**: LF
- **Import sorting**: Alphabetical

## Important Notes

⚠️ **DO NOT UPGRADE** SwiftFormat beyond version 0.52.10 without team coordination.

Both local (bin/swiftformat) and CI (.github/workflows/swiftformat.yml) are locked to this version to ensure consistency.

## Troubleshooting

### SwiftFormat not found

Run the setup script:
```bash
./setup-swiftformat.sh
```

### CI formatting check fails

1. Run locally: `./scripts/format.sh`
2. Review changes: `git diff`
3. Commit the formatted files: `git add . && git commit -m "Apply SwiftFormat"`
4. Push to your branch: `git push`

### Formatting conflicts after merge

If you encounter formatting conflicts after merging:
```bash
# Format the entire project to resolve conflicts
./scripts/format.sh

# Review and commit the changes
git add .
git commit -m "Apply SwiftFormat after merge"
```
