---
name: narrow-patch
description: Implement, trim, or plan a code change through the smallest clear existing behavior path. Use when the user wants a compact feature patch, an overbuilt change simplified, a scope budget before editing, or project-specific rules enforced without broad refactors or adjacent cleanup.
---

# Narrow Patch

Use this skill to keep a change small, direct, and aligned with the project's documented architecture.

## Vocabulary

Use these terms consistently:

- **Module**: anything with an interface and an implementation.
- **Interface**: everything a caller must know to use a module correctly, including invariants, ordering, error modes, and configuration.
- **Implementation**: the code inside a module.
- **Seam**: where an interface lives; a place behavior can vary without editing callers.
- **Adapter**: a concrete thing satisfying an interface at a seam.
- **Depth**: leverage at the interface. A deep module hides substantial behavior behind a small interface.
- **Leverage**: capability callers get per unit of interface.
- **Locality**: change, bugs, and verification concentrated in one place.

Prefer these terms over "component," "service," "API," or "boundary."

## Source Priority

Use this order when deciding what shape is valid:

1. Explicit user direction.
2. Repository instructions such as `AGENTS.md`.
3. Architecture docs, specs, ADRs, and design notes.
4. Existing implementation.

Treat implementation as evidence, not authority, when it conflicts with documented architecture or the requested behavior.

## Workflow

1. Restate the irreducible user-visible behavior.
2. Read the touched function, enclosing module, and direct call path.
3. Identify the narrowest existing behavior path that already performs the operation being changed.
4. Declare a patch budget before editing:
   - expected files touched
   - expected new helpers
   - whether any interface change is actually needed
   - tests or inspections that prove the changed path
5. Substitute the mechanism inside the existing path before adding new modules, seams, adapters, queues, state machines, or commands.
6. If the patch exceeds the budget, stop and prove why the smaller path fails before expanding scope.
7. Remove or collapse scaffolding that is not required by the final behavior.

## Narrowing Rules

Prefer:

- local edits inside existing modules
- one authoritative implementation path
- one clear owner for the behavior
- existing queues, commands, relays, helpers, and public interfaces
- a small wrapper only when it reduces repeated call-site logic or preserves useful domain language
- concise contract-focused tests

Avoid:

- broad cleanup mixed into a narrow task
- speculative infrastructure
- compatibility shims or fallback behavior not requested by the user
- duplicate public/private, GUI/non-GUI, or helper/command paths
- new seams with only one adapter
- single-use helpers that make the total code larger or less direct
- deleting useful wrappers when that merely duplicates logic across callers

## Authoritative Path Checks

When a project has a documented command path, public interface, view/domain split, or execution owner, enforce it as a general architecture rule:

- View or UI code should collect transient state and render results, not own domain execution.
- Public commands or public interfaces should remain the reproducible contract unless the user explicitly changes that contract.
- Translation layers should translate representation, not become hidden owners of the behavior.
- New feature kinds should extend an existing kind-based mechanism before creating a parallel registry or path.

## Tests

Keep only tests that prove the public contract through the right interface. Rewrite or delete tests that pin helper names, call choreography, private state, incidental DOM shape, or temporary plumbing.

If the architecture is part of the contract, test it directly but narrowly.

## Final Check

Before finishing, answer:

- Can this be done by changing an existing operation instead of adding a new path?
- Did any new module, seam, adapter, or helper earn its keep through leverage or locality?
- Did the patch create two implementation paths where one authoritative path should exist?
- Did I solve an adjacent problem the user did not ask for?
- Do the tests prove behavior through the intended interface?
