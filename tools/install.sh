#!/bin/bash
# tools/install.sh - convenience wrapper: runs ../install.sh (the real installer in the Snow-Dot folder).
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh" "$@"
