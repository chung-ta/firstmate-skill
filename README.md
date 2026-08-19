# firstmate-skill

**Run a crew of parallel Claude Code agents from iTerm2 tabs — as a native skill.**

Ported from [`firstmate`](https://github.com/kunchenguid/firstmate) by [Kun Chen](https://github.com/kunchenguid).

---

## What this is

You can run one coding agent easily. The moment you want three tasks done in parallel you become a tab-juggler: babysitting sessions, copy-pasting context between repos, forgetting which terminal had the failing test.

`firstmate` flips that — you talk to a single agent, the *first mate*, and it runs the crew for you.

The original is an **agent distro**: a repo you clone and launch your agent inside, with its own `AGENTS.md`, tmux session backend, and supervision watcher.

This repo gives you two ways to get a first mate:

| Skill | What it does |
|---|---|
| **`crew`** | A native port — dispatches parallel tasks to iTerm2 tabs running Claude Code subagent teams, driven from your current conversation. Geared toward Java/Spring Boot. |
| **`firstmate`** | Launches the **real** distro from `~/development/tools/firstmate` in a new iTerm2 tab. Nothing reimplemented — you get secondmates, the supervision watcher, and every backend. |

**Use `/crew`** for a batch you will check back on yourself, driven from the conversation you are already in.

**Use `/firstmate`** when the job needs what the real distro has and the port does not: event-driven zero-token supervision that notices a wedged crewmate without you looking, secondmates on isolated or SSH-remote homes, a backend other than iTerm2, or the Relay integration. The cost is that it runs in its own tab — you talk to it there, not in your current session.

Everything below describes `crew`. For `/firstmate`, see [`skills/firstmate/SKILL.md`](skills/firstmate/SKILL.md); it preflights the clone, `tmux`, and `gh` auth, and fails with the exact fix command if something is missing.

## What `crew` does

Give it an objective. It:

1. **Splits** the objective into genuinely independent tasks
2. **Creates a worktree** per task, so parallel work on one repo never collides
3. **Opens an iTerm2 tab** per task, running Claude Code seeded from a written brief
4. Has each tab run an **orchestrator over a team of subagents**
5. **Supervises** them, escalates only real decisions, and reports plain outcomes

You can watch or type into any tab directly. The first mate is **read-only over your projects** — every change is made by a crewmate inside its own worktree.

### Two team shapes

| Shape | Use when | Roles |
|---|---|---|
| **solo** | A bounded change with a clear approach | plan → implement → review |
| **team** | Fuzzy requirements, contested design, or genuinely independent sub-parts | requirements → architect → RFC review → implementors (1 per sub-part) → code review → QA |

Solo is the default. A full team on a two-file bug fix is theater, and you pay for it in tokens and latency. Role definitions are in [`skills/crew/references/team-roles.md`](skills/crew/references/team-roles.md).

Two rules apply to every role: **load the house style before writing Java**, and **no role certifies its own output** — the implementor never reviews its own code, the architect never signs off on its own RFC.

### Splitting a Spring Boot codebase

The skill knows the couplings that make two Java tasks secretly one task:

- **Split by vertical slice, never by Spring layer.** Giving one agent the controller, another the service, and a third the repository is the classic bad split — they are one change and will each wait on the others.
- **Flyway migrations collide.** Two agents each adding `V<N>__*.sql` pick the same version number. The first mate assigns version numbers up front when more than one task needs a migration.
- Shared DTOs, shared `@Entity` classes, `application.yml`, and the Spring Security filter chain are all single-owner.

When a coupling is unavoidable, it lands as its own first task and the dependents go out after it merges.

## Requirements

- **Claude Code**
- **iTerm2** — the tab automation is AppleScript against iTerm2 specifically
- **[`treehouse`](https://github.com/kunchenguid/treehouse)** for worktree management (falls back to plain `git worktree` if absent):
  ```sh
  curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
  ```
- For **`/firstmate`** only: a [`firstmate`](https://github.com/kunchenguid/firstmate) clone and **tmux**
  ```sh
  git clone https://github.com/kunchenguid/firstmate ~/development/tools/firstmate
  brew install tmux
  ```
  Point elsewhere with `FIRSTMATE_HOME=/path/to/firstmate`.
- **[`no-mistakes-skill`](https://github.com/chung-ta/no-mistakes-skill)** — provides `gate` and `java-house-style`, which crewmates need to finish their work. Install it too.
- **git** and **[`gh`](https://cli.github.com/)**, authenticated

## Install

```sh
git clone https://github.com/chung-ta/firstmate-skill.git
cd firstmate-skill
./install.sh
```

Then **start a new Claude Code session**.

By default the installer **symlinks** the skill into `~/.claude/skills/`, so `git pull` updates it with no reinstall.

```sh
./install.sh --copy        # copy instead, so the skill survives this checkout going away
./install.sh --force       # replace a skill already installed under the same name
./install.sh --uninstall   # remove it
./install.sh --dir <path>  # install somewhere other than ~/.claude/skills
./install.sh --help
```

Install the companion repo as well, or crewmates will fail their definition of done:

```sh
git clone https://github.com/chung-ta/no-mistakes-skill.git
cd no-mistakes-skill && ./install.sh
```

### Verify

Start a new session and run `/crew` with no arguments. It should ask what you want dispatched rather than doing anything.

To check the tab automation alone, without launching real agents:

```sh
mkdir -p /tmp/crewcheck && echo "hello" > /tmp/crewcheck/brief.md
CREW_CLAUDE_BIN=/bin/echo ~/.claude/skills/crew/scripts/crew-tab.sh \
  /tmp/crewcheck crew-check /tmp/crewcheck/brief.md
```

A new iTerm2 tab should open and echo `hello`. Close it when done.

## Use

### `/crew` — dispatch from this conversation

```
/crew add pagination to the transaction and listing endpoints, and fix the N+1 on agent lookup
```

The first mate states its split before spawning anything — dispatching is cheap, a wrong split is not. Push back on the split if it looks wrong; that is the point of it telling you.

Then it reports:

```
✓ paginate transaction endpoint    PR #412  risk: low     CI green
✓ paginate listing endpoint        PR #413  risk: low     CI green
⚠ fix N+1 on agent lookup          needs a decision — see below
```

### `/firstmate` — hand off to the real distro

```
/firstmate add an update command to lavish-axi, treehouse, and gnhf that bumps to the latest npm version
```

Opens a tab, launches Claude Code inside the firstmate clone, and hands it the objective. From then on **you talk to the first mate in that tab**, not in your original session.

On the first launch of a fresh clone it runs a short setup conversation — project mode, backend, autonomy — which you answer in the tab.

### State and cleanup

Task state lives in `~/.crew/tasks.json` — worktree path, branch, iTerm2 session id, status, PR URL. That is what makes supervision survive a session restart.

Worktrees are acquired with `treehouse get "<desc>" --lease`, which marks them durable so `prune` will not reclaim them while an agent is inside. Release with `treehouse return "$WT"` when a task is done. A leased worktree is never reclaimed automatically — that is the point of the lease, and also why it has to be released.

## Differences from the original

**Kept:** the first-mate/captain model, one worktree per crewmate, visible sessions you can watch and type into, on-disk restart-proof state, the read-only-over-projects hard rule, and finishing every task through a validation gate.

**Dropped:** secondmates (persistent second mates on isolated or remote homes), the Relay X/Discord integration, the event-driven zero-token supervision watcher and turn-end guard, and every session backend except iTerm2 (the original supports tmux, herdr, zellij, Orca, cmux).

**The honest gap is supervision.** The original has a watcher that wakes it when a crewmate needs attention, costing nothing while idle. This skill checks when you ask or after dispatching a batch — so a stuck crewmate stays stuck until someone looks.

**Added:** Java/Spring Boot task-splitting rules, the requirements/architect/RFC-review/implementor/code-review/QA team shape, and Spring test-slice guidance.

**None of this is a reason to not have the real thing.** When you want secondmates, the supervision watcher, or another backend, use `/firstmate` — it launches the actual distro in a tab rather than approximating it. `crew` is the lighter option, not the better one.

## Attribution

Derived from [github.com/kunchenguid/firstmate](https://github.com/kunchenguid/firstmate) — MIT, © 2026 Kun Chen. The first-mate/captain model, the crew and worktree architecture, the read-only project boundary, and the disposable-worktree discipline are his work; this repo ports them to Claude Code subagents, iTerm2, and a Java stack.

His other tools in the same workflow, all free and open source:

- [`no-mistakes`](https://github.com/kunchenguid/no-mistakes) — kill all the slop, raise clean PRs
- [`lavish-axi`](https://github.com/kunchenguid/lavish-axi) — review HTML artifacts instead of walls of terminal text
- [`treehouse`](https://github.com/kunchenguid/treehouse) — manage worktrees without managing worktrees
- [`gnhf`](https://github.com/kunchenguid/gnhf) — "good night, have fun": long-running agent loops

Background: [L8 Principal's Agentic Engineering Workflow](https://www.youtube.com/watch?v=iQyg-KypKAA).

**Companion repo:** [`no-mistakes-skill`](https://github.com/chung-ta/no-mistakes-skill) — provides the `gate` pipeline and `java-house-style`, which this skill's crewmates depend on.

## License

MIT. See [LICENSE](LICENSE).
