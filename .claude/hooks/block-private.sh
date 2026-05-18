#!/usr/bin/env bash
# PreToolUse hook: block Edit/Write/MultiEdit on paths under private/
# (contains gitignored SSH host config and GPG key fingerprint).

set -eu

path=$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))')

case "$path" in
  */private/*|private/*)
    echo "Edits under private/ are blocked by .claude/hooks/block-private.sh (contains gitignored secrets)." >&2
    exit 2
    ;;
esac

exit 0
