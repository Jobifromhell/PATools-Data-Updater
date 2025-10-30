# PA Tools Dataset Publisher

The **PA Tools Dataset Publisher** is a SwiftUI-based macOS utility that helps maintainers author and publish the PA Tools OTA datasets (`ampload.json` and `prealignment.json`).

## Features

- Dual workspaces for Amp Load and Pre-alignment datasets with full CRUD controls for amplifiers, speaker load mappings, combos, and components.
- Inline validation to ensure required fields and numeric ranges are respected before publishing.
- Dataset metadata management including version editing and dataset identifiers.
- Release notes integration that appends publish summaries to `ReleaseNotes.md` and displays existing history with filtering by dataset.
- Manifest management with SHA-256 checksum calculation, optional version bumping, and manifest entry updates.
- Git automation capable of staging, committing, and optionally pushing dataset changes.
- Undo/redo support via macOS standard keyboard shortcuts.

## Getting Started

1. Open the project in Xcode 15 or later on macOS 13+.
2. Build and run the **PA Tools Dataset Publisher** target. The default window shows a sidebar with the Amp Load, Pre-alignment, Release Notes, and Settings workspaces.

## Configuring Paths

1. **Dataset files** – Open the Amp Load or Pre-alignment workspace and use the **Open** toolbar button to select `ampload.json` or `prealignment.json` respectively.
2. **Manifest file** – Navigate to **Settings** and either paste the full path or use **Choose…** to locate `manifest.json`.
3. **Release notes** – Switch to **Release Notes** and choose the `ReleaseNotes.md` file. New publish actions append entries automatically.

## Editing Data

- Use the lists in each workspace to add, duplicate, or delete amplifiers, speaker load definitions, combos, and components.
- Metadata fields (version and dataset identifier) appear at the top of each workspace.
- Inline validation messages appear in the publish panel when required data is missing or invalid.
- Changes are tracked via macOS undo/redo. The app also warns about unsaved data when quitting.

## Publishing Datasets

1. Enter any human-authored release notes in the publish panel.
2. Toggle whether the manifest path and version should be updated.
3. Press **Publish Dataset** to perform the workflow:
   - Validate the dataset.
   - Save the JSON with pretty-printed formatting.
   - Calculate the SHA-256 checksum and update the manifest entry matching the dataset identifier.
   - Append an entry to `ReleaseNotes.md` with the dataset id, version, timestamp, and notes.
   - Stage, commit, and optionally push the manifest, datasets, and release notes using git.

## Git Integration

Configure Git settings in **Settings**:

- **Repository Path** – Path to the local git repository containing the datasets and manifest.
- **Remote** – Remote name or HTTPS URL. When an HTTPS URL is provided, the personal access token (PAT) is embedded automatically.
- **Branch** – Target branch for pushes.
- **Personal Access Token** – Optional PAT used to authenticate pushes over HTTPS.
- **Push automatically** – Enable to push after each publish. Otherwise only commits are created.

Git commands executed:

```bash
git add <files>
git commit -m "Publish <dataset> v<version>"
git push <remote> <branch>
```

Logs appear inside the publish panel after a successful run.

## Unit Tests

Unit tests cover JSON encoding/decoding, checksum generation, and manifest updates. Run them with:

```bash
xcodebuild test -scheme "PATools Data Updater" -destination 'platform=macOS'
```

(When running outside macOS, use Xcode on macOS to execute the tests.)

## Release Notes Format

Entries appended to `ReleaseNotes.md` use the following Markdown structure:

```
## <datasetId> v<version> - <YYYY-MM-DD HH:mm>
<Optional notes>
```

The release notes viewer parses this format to populate the changelog list.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later

## License

This project is provided for maintainers of PA Tools datasets.
