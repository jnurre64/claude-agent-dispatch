#!/bin/bash
set -euo pipefail

# ─── Create agent labels on a GitHub repository ─────────────────
# Usage: create-labels.sh <owner/repo>

REPO="${1:?Usage: create-labels.sh <owner/repo>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS_FILE="${SCRIPT_DIR}/../labels.txt"

if [ ! -f "$LABELS_FILE" ]; then
    echo "ERROR: labels.txt not found at $LABELS_FILE"
    exit 1
fi

echo "Creating agent labels on $REPO..."
echo ""

while IFS='|' read -r name color description; do
    # Skip empty lines and comments
    [[ -z "$name" || "$name" =~ ^# ]] && continue

    echo -n "  Creating '$name'... "
    if gh label create "$name" --color "$color" --description "$description" --force --repo "$REPO" 2>/dev/null; then
        echo "done"
    else
        echo "failed (may need gh auth with write access)"
    fi
done < "$LABELS_FILE"

echo ""
echo "Label creation complete."
