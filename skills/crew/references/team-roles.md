# Crew team roles

Role definitions for the orchestrator running inside a crewmate tab. Each role is a **subagent with its own context window**. The orchestrator holds the thread; the roles do the work and report back.

Two rules apply to every role:

1. **Load the `java-house-style` skill before writing or reviewing Java.**
2. **A role never certifies its own output.** The implementor does not review its own code; the architect does not sign off on its own RFC. Fresh context, different agent, every time.

---

## Solo shape

For a bounded change with a clear approach. Three roles, run in sequence.

### plan
Read the relevant code and produce a concrete plan: the files to touch, the approach, the risks, and the tests that will prove it works. Not a restatement of the objective — a plan someone else could execute. If the objective turns out to be ambiguous or larger than it looked, say so now rather than planning around it.

### implement
Execute the plan. Write the tests alongside the code, not after. Commit in logical units on the task branch. Where the plan turns out to be wrong, say what you changed and why rather than silently diverging.

### review
Adversarially review the diff with **fresh context**. Use the review contract in `~/.claude/skills/gate/references/review-contract.md` — it carries the finding taxonomy and the Java/Spring lenses. Report findings; do not fix them yourself.

---

## Team shape

For fuzzy requirements, contested design, or genuinely independent sub-parts.

### requirements
Turn the objective into a testable specification before anyone designs anything.

Produce: the user-visible behavior, the acceptance criteria, the edge cases, the explicit non-goals, and the open questions. Interrogate the objective rather than transcribing it — the most valuable output of this role is usually the question nobody asked.

Write it to `.crew/requirements.md`. Stop and escalate if an open question blocks design.

### architect
Design the change against the requirements. Produce an RFC at `.crew/rfc.md` covering:

- The approach, and **at least one alternative you rejected, with the reason**
- Component and data-flow changes — a Mermaid diagram where it helps
- API contracts: endpoints, DTOs, error responses, backward compatibility
- Persistence: schema changes, migration strategy, and whether it is safe during a rolling deploy
- Transaction and consistency boundaries
- Failure modes and what happens on each
- The split into independent implementation tasks, with the interface between them nailed down

An RFC with no rejected alternative has not designed anything, it has documented a first instinct.

### rfc-review
Review the RFC with **fresh context**, against the requirements. Challenge:

- Does this actually satisfy the requirements, including the edge cases?
- Is the rejected alternative rejected for a real reason?
- Are the task boundaries genuinely independent, or will these implementors collide?
- Does the migration survive a rolling deploy where old and new run together?
- What operational surface changes — config, metrics, alerts, runbooks?

Return blocking concerns and non-blocking notes, separately. The architect revises; you re-review. Do not resume the architect's session to do it.

### implementor
**One implementor per independent sub-task**, running in parallel. Each gets: the requirements, the approved RFC, its own sub-task, and the interfaces it must honor.

Implement against the RFC. Write tests alongside. If you need to change an interface another implementor depends on, **stop and tell the orchestrator** — do not change it unilaterally. That interface is the contract that makes parallelism safe.

Prefer the narrowest Spring test that proves the point: `@WebMvcTest` for a controller, `@DataJpaTest` for a repository, Testcontainers where real database behavior is the thing under test.

### code-review
Adversarially review the combined diff with **fresh context**, using `~/.claude/skills/gate/references/review-contract.md`.

Beyond the standard lenses, this role owns the seam: check that the independently-implemented parts actually compose. Interfaces honored on both sides, no duplicated logic that diverged, no two implementors solving the same problem differently.

### qa
Verify against the **requirements**, not the implementation. You did not write this and you are not reviewing the code — you are asking whether it does what was asked.

- Exercise every acceptance criterion and record evidence (`curl` transcripts, logs, screenshots, SQL)
- Probe the edge cases the requirements named
- Try to break it: bad input, missing auth, concurrent access, empty and huge datasets
- Verify the migration applies **and rolls back**
- Confirm the non-goals were genuinely not done

Report pass/fail per criterion with evidence. A criterion you could not exercise is a **fail with a reason**, never a silent pass.

---

## Orchestration

```
requirements ──> architect ──> rfc-review ──┐
                     ^                       │
                     └────── revise ─────────┘
                                             │
                                             v
                          ┌──── implementor A ────┐
                          ├──── implementor B ────┤──> code-review ──> qa ──> /gate
                          └──── implementor C ────┘
```

Gates the orchestrator must hold:

- **No implementation before the RFC is approved.** Parallel implementors working from an unreviewed design is the expensive way to discover a design flaw.
- **Implementors run in parallel; everything else is sequential.**
- **Review rounds use a fresh agent each time.** Never resume the reviewer that prescribed a fix to check whether the fix is correct — that seats the prescriber as its own certifier, and it will confirm its prescription was followed rather than judge whether the code is right.
- **QA runs after code-review passes**, not alongside it.
- **`/gate` is last**, and it is not optional.

When a role escalates, answer it if the brief allows and escalate to the first mate if it does not. Do not guess on a decision that changes product behavior.
