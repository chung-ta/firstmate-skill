#!/usr/bin/env bash
#
# crew-tab.sh — open a new iTerm2 tab, cd into a worktree, and launch Claude Code
# seeded with a brief file.
#
#   crew-tab.sh <workdir> <title> <brief-file> [extra claude args...]
#
# The brief file is passed as Claude's initial prompt. Keeping it in a file
# instead of inlining it avoids every layer of AppleScript/shell quoting trouble,
# and leaves the brief on disk in the worktree for the agent to re-read.
#
# Prints the opened tab's iTerm2 session id on stdout so the caller can track it.

set -euo pipefail

usage() {
  echo "usage: crew-tab.sh <workdir> <title> <brief-file> [claude-args...]" >&2
  exit 2
}

[ $# -ge 3 ] || usage

WORKDIR=$1
TITLE=$2
BRIEF=$3
shift 3
EXTRA_ARGS="$*"

[ -d "$WORKDIR" ] || { echo "crew-tab: no such directory: $WORKDIR" >&2; exit 1; }
[ -f "$BRIEF" ]   || { echo "crew-tab: no such brief file: $BRIEF" >&2; exit 1; }

# A spawned shell may not resolve `claude` the same way an interactive one does,
# so prefer a known install path and fall back to PATH. Override with
# CREW_CLAUDE_BIN (the dry-run check in the README uses this).
CLAUDE_BIN="${CREW_CLAUDE_BIN:-}"
if [ -z "$CLAUDE_BIN" ]; then
  for candidate in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude"; do
    [ -x "$candidate" ] && { CLAUDE_BIN=$candidate; break; }
  done
fi
[ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ] || CLAUDE_BIN=claude

# Single-quote a value for safe interpolation into the shell command line.
shquote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Escape a value for embedding in an AppleScript double-quoted string literal.
asquote() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

CMD="cd $(shquote "$WORKDIR") && $(shquote "$CLAUDE_BIN") ${EXTRA_ARGS} \"\$(cat $(shquote "$BRIEF"))\""

SESSION_ID=$(osascript <<EOF
tell application "iTerm2"
  activate
  if (count of windows) = 0 then
    create window with default profile
  end if
  tell current window
    set newTab to (create tab with default profile)
    tell current session of newTab
      set name to "$(asquote "$TITLE")"
      write text "$(asquote "$CMD")"
      return id
    end tell
  end tell
end tell
EOF
)

echo "$SESSION_ID"
