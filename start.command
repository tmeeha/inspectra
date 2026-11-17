#!/usr/bin/env bash
# Double-click to start the app: serves this folder on localhost (this computer only) and opens the browser.
cd "$(dirname "$0")" || exit 1
if command -v perl >/dev/null 2>&1; then exec perl serve.pl "$@"; fi
echo "Could not find Perl, which is needed to start the local server."
read -r -n 1 -p "Press any key to close..."
