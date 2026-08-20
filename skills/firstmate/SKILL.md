---
name: firstmate
description: Launch the real firstmate agent distro in a new iTerm2 tab, optionally seeded with an objective. Use when the user says launch firstmate, start the first mate, hand this to firstmate, or /firstmate — or when a job needs secondmates, the supervision watcher, or a session backend the lighter crew skill does not provide.
user-invocable: true
argument-hint: [objective to hand the first mate]
---

# firstmate (launcher)

Launches the **real** [`firstmate`](https://github.com/kunchenguid/firstmate) distro rather than reimplementing it.

`firstmate` is an *agent distro*, not a binary: a repo whose `AGENTS.md`, bundled skills, and helper scripts turn a general-purpose agent into a first mate. Launching a harness inside the clone is what instantiates it. This skill opens an iTerm2 tab, cds into the clone, and starts Claude Code there.

## Request

$ARGUMENTS

## When to use this instead of `/crew`

Both give you a first mate running a crew. Pick by what the job needs:

| Use `/firstmate` | Use `/crew` |
|---|---|
| Long-running work where a crewmate getting stuck must be noticed without you looking | A batch you will check back on yourself |
| You want secondmates — persistent second mates on isolated or SSH-remote homes | Everything runs on this machine |
| You want a backend other than iTerm2 (tmux, herdr, zellij, Orca, cmux) | iTerm2 tabs are fine |
| You want the Relay X/Discord integration | You do not |
| You want project modes and the full `no-mistakes` gate | The `gate` skill is enough |
| You are fine talking to it in its own tab | You want the crew driven from this conversation |

The real distro's decisive advantage is **event-driven, zero-token supervision**: a watcher sleeps on the fleet and wakes the first mate only when something needs attention. `/crew` has no equivalent — it checks when asked, so a wedged crewmate stays wedged until someone looks.

Its cost is that it runs in its own session. You talk to it there, not here.

## Launch

```sh
~/.claude/skills/firstmate/scripts/firstmate-launch.sh [objective-file]
```

With an objective file, its contents become the first mate's opening prompt. Without one, you get an interactive first mate to talk to.

When the user gave an objective in `$ARGUMENTS`, write it to a temp file first and pass that — it keeps quoting out of the shell and gives the first mate the full text:

```sh
OBJ=$(mktemp); cat > "$OBJ" <<'EOF'
<the user's objective, verbatim, plus any context from this conversation
 that the first mate cannot see — it starts with a fresh context window>

Decide anything clear, straightforward, or obvious — do not ask about a choice
that has one correct answer. When a decision is genuinely yours, make it and say
what you assumed.

When you hit a decision that is NOT answerable from this objective — a real fork
where different answers lead to materially different work — surface it visually
rather than stalling in this tab. Batch them: finish investigating, collect EVERY
open decision, and present them together in ONE artifact rather than asking one
at a time — later findings often reshape or dissolve earlier questions. Interrupt
early only for a hard blocker. Write an HTML artifact under `.lavish/` showing
what is being chosen, the evidence behind it, each option's tradeoff, your
recommendation and why, and what is reversible. Open it with
`npx -y lavish-axi <file>` and then run `npx -y lavish-axi poll <file>` in the
FOREGROUND, leaving it running until the captain answers. Use native radio/form
controls with `data-lavish-question` so they can answer by clicking. Run
`npx -y lavish-axi playbook input` first for the decision-surface rules.

This matters more here than elsewhere: this session may not be able to message
back into the dispatching conversation, so a question left in the terminal can
go unseen indefinitely.
EOF
~/.claude/skills/firstmate/scripts/firstmate-launch.sh "$OBJ"
```

The script preflights everything and fails with the exact fix command if something is missing: the clone exists and looks like firstmate, `tmux` is installed, `gh` is installed and authenticated. Do not work around a preflight failure — report it.

Point it at a different clone with `FIRSTMATE_HOME=/path/to/firstmate`.

## After launching

Tell the user the tab is open and that **the first mate lives in that tab now** — they talk to it there. Report the objective you handed it.

On the very first launch of a fresh clone, firstmate runs a short setup conversation asking for preferences (project mode, backend, autonomy). That is expected and it is just talking — the user answers in the tab.

Do not try to drive the first mate's session from here, and do not poll it. It is a peer, not a subagent. If the user wants status, they can read the tab; if they want you to coordinate, use `/crew` instead.

## Keeping it current

The distro updates by pulling the clone. Its own `updatefirstmate` skill handles this from inside a session, which is the safer path since it knows about in-flight crew state:

```
> update firstmate
```

Do not `git pull` the clone from here while a first mate session is live.
