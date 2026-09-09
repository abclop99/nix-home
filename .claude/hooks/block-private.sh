#!/usr/bin/env bash
# PreToolUse hook: block Edit/Write/MultiEdit on paths under private/
# (their real content is skip-worktree'd and must not reach a commit).
#
# Fails closed. Only exit 2 blocks a tool call; every other non-zero status is
# a non-blocking error, so a parser that is absent or chokes would leave the
# hook installed and permissive. Anything that stops us reading the path
# therefore blocks instead.

set -eu

if ! path=$(jaq -r '.tool_input.file_path // ""'); then
  echo "block-private.sh could not read the hook payload (jaq missing, or input malformed). Blocking to fail closed." >&2
  exit 2
fi

case "$path" in
  */private/*|private/*)
    echo "Edits under private/ are blocked by .claude/hooks/block-private.sh (real content is skip-worktree'd)." >&2
    exit 2
    ;;
esac

exit 0
