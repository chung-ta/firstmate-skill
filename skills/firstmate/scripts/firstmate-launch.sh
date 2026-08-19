#!/usr/bin/env bash
#
# firstmate-launch.sh — open a new iTerm2 tab running the real firstmate distro.
#
#   firstmate-launch.sh [objective-file]
#
# firstmate is an agent distro, not a binary: launching a harness inside the
# clone is what instantiates your first mate. This opens a tab, cds into the
# clone, and starts Claude Code there — AGENTS.md takes over from that point.
#
# With an objective file, its contents become Claude's opening prompt. Without
# one, you get an interactive first mate to talk to.
#
# Environment:
#   FIRSTMATE_HOME   the clone to launch (default ~/development/tools/firstmate)
#   CREW_CLAUDE_BIN  the Claude Code binary (default ~/.claude/local/claude)
#
# Prints the opened iTerm2 session id on stdout.

set -euo pipefail

FM_DIR="${FIRSTMATE_HOME:-$HOME/development/tools/firstmate}"
OBJECTIVE="${1:-}"

# --- preflight -------------------------------------------------------------

fail() { echo "firstmate-launch: $1" >&2; exit 1; }

[ -d "$FM_DIR" ] || fail "no firstmate clone at $FM_DIR
  git clone https://github.com/kunchenguid/firstmate \"$FM_DIR\"
  (or set FIRSTMATE_HOME to an existing clone)"

[ -f "$FM_DIR/AGENTS.md" ] || fail "$FM_DIR does not look like a firstmate clone (no AGENTS.md)"

command -v tmux >/dev/null 2>&1 || fail "tmux not found — firstmate's default session backend needs it
  brew install tmux"

command -v gh >/dev/null 2>&1 || fail "gh not found — firstmate needs the GitHub CLI
  brew install gh && gh auth login"

gh auth status >/dev/null 2>&1 || fail "gh is not authenticated
  gh auth login"

[ -n "$OBJECTIVE" ] && [ ! -f "$OBJECTIVE" ] && fail "no such objective file: $OBJECTIVE"

CLAUDE_BIN="${CREW_CLAUDE_BIN:-$HOME/.claude/local/claude}"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN=claude

# --- build the command -----------------------------------------------------

shquote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
asquote() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

CMD="cd $(shquote "$FM_DIR") && $(shquote "$CLAUDE_BIN")"
if [ -n "$OBJECTIVE" ]; then
  CMD="$CMD \"\$(cat $(shquote "$OBJECTIVE"))\""
fi

# --- open the tab ----------------------------------------------------------

osascript <<EOF
tell application "iTerm2"
  activate
  if (count of windows) = 0 then
    create window with default profile
  end if
  tell current window
    set newTab to (create tab with default profile)
    tell current session of newTab
      set name to "firstmate"
      write text "$(asquote "$CMD")"
      return id
    end tell
  end tell
end tell
EOF
