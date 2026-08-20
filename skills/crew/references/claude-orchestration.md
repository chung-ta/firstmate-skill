# Claude Code orchestration for Java/Spring crewmates

`team-roles.md` defines *what* each role does. This file defines *how* a crewmate runs those roles in Claude Code — which agents to spawn, which skills to load, and which existing tooling to reuse rather than reinvent.

A crewmate that invents its own reviewer when a tuned one already exists throws away every rule that reviewer encodes. Prefer the installed agent every time.

## Map roles to installed agents

Spawn these with the Task tool. Where a role has a dedicated agent, **use it** rather than a `general-purpose` agent with an improvised prompt.

| Role | Agent | Notes |
|---|---|---|
| requirements | `Explore`, or `/spec` | `/spec` produces a precise spec from a vague requirement — run it before planning when the brief is fuzzy. |
| architect | `java-code-architect` | Reviews the plan for soundness before any code exists. |
| plan (solo shape) | `Plan`, or `/spring-plan` | `/spring-plan` fans out planners across data/service/API/test layers. |
| implementor | `java-spring-code-implementer` | TDD-oriented. One per independent sub-task. |
| — entity/repository work | `spring-entity-designer` | |
| — service layer | `spring-service-builder` | |
| — controllers | `spring-controller-builder` | |
| — DTOs and mappers | `spring-dto-mapper-builder` | |
| — migrations | `spring-migration-manager` | Pair with `flyway-migration-reviewer` before done. |
| — tests | `spring-test-generator` | |
| code-review | `java-spring-code-reviewer` | The 16-section house reviewer. Never substitute an improvised prompt. |
| — migrations | `flyway-migration-reviewer` | Mandatory when the diff touches `db/migration/`. |
| — simplification | `java-code-simplifier` | After implementation, before review. |
| qa | `test-coverage-checker` | 80% line coverage is a hard gate. |
| performance | `spring-performance-optimizer` | Use when the change touches queries or fetch strategy. |

Load `java-house-style` before writing any Java, and `jpa-patterns` when the work touches persistence.

## Parallel dispatch

Independent agents go out in **one message with multiple Task calls** so they run concurrently. Sequential messages run them one at a time and waste the parallelism the crew exists for.

Parallel: implementors on independent sub-tasks; independent review lenses on the same diff.

Sequential, always: requirements → architect → RFC review → implement → review → QA → `/gate`. Each consumes the previous one's output.

## The self-certification rule

Never let an agent certify its own work. Concretely:

- The implementor never reviews its own code.
- The architect never approves its own RFC.
- A review round after fixes uses a **fresh** agent, never the one that prescribed the fix.

Carry cross-round context in the prompt — previous findings, what changed in response — rather than by continuing the prescribing agent. That agent will verify its prescription was followed instead of judging whether the new code is correct.

## Finishing

`/gate` is the definition of done and it is not optional. It resolves fast vs full mode from the base branch itself, so do not pre-empt it: run it and let it decide what to skip.

Report the PR URL and risk level. Stop and escalate rather than guessing on any decision the brief does not answer.

## What not to do

- Do not run `/pre-pr-review` directly — `/gate` invokes it in full mode. Running both reviews the same diff twice.
- Do not spawn a `general-purpose` agent for a job one of the agents above already covers.
- Do not skip `java-house-style` because the change looks small. The IDE reformats on save, and unformatted code produces phantom diffs blamed on your change.
- Do not edit outside the worktree. The crewmate owns its worktree and nothing else.
