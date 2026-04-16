#!/bin/bash
set -euo pipefail

# GitHub Release Script
# Usage: ./Scripts/create-release.sh [version] [--draft] [--publish]
#
# Examples:
#   ./Scripts/create-release.sh 0.1.0          # Create draft release
#   ./Scripts/create-release.sh 0.1.0 --publish # Create and publish

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="JuanWithJunJie/ai-dynamic-island"

# Parse arguments
VERSION="${1:-}"
DRAFT="--draft"
if [[ "${2:-}" == "--publish" ]]; then
    DRAFT=""
fi

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [--publish]"
    echo "Example: $0 0.1.0"
    exit 1
fi

# Build release
echo "Building release v${VERSION}..."
"$ROOT/Scripts/build-release.sh"

ARTIFACT="$ROOT/.build/release/MacIrland-v${VERSION}-macos.zip"

if [ ! -f "$ARTIFACT" ]; then
    echo "Error: Artifact not found at $ARTIFACT"
    exit 1
fi

# Create release notes
NOTES="## MacIrland v${VERSION}

### What's New
See [changelog](https://github.com/${REPO}/blob/main/CHANGELOG.md) for details.

### Installation
1. Download the zip below
2. Unzip and move \`MacIrland.app\` to \`/Applications\`
3. On first launch, go to System Settings > Privacy & Security to allow the app
4. Enable Claude Code hook: \`bash Scripts/install-hooks.sh\`

### Requirements
- macOS 14+
- Claude Code hook installed"

# Create or update release
if gh release view "v${VERSION}" --repo "$REPO" 2>/dev/null; then
    echo "Release v${VERSION} exists. Upload artifact..."
    gh release upload "v${VERSION}" "$ARTIFACT" --repo "$REPO" --clobber
else
    echo "Creating release v${VERSION}..."
    gh release create "v${VERSION}" \
        --repo "$REPO" \
        --title "MacIrland v${VERSION}" \
        $DRAFT \
        --notes "$NOTES" \
        "$ARTIFACT"
fi

echo ""
echo "Done! Release: https://github.com/${REPO}/releases/tag/v${VERSION}"
