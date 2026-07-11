# Engineering Debt Issues

This plan resolves the remaining non-blocking engineering debt found in the
second codebase review.

## Progress

- [ ] Slice 1: Surface workspace persistence failures
- [ ] Slice 2: Own the native authentication event lifecycle
- [ ] Slice 3: Decompose write planning by responsibility
- [ ] Slice 4: Clean up the resulting tests

## Slice 1: Surface workspace persistence failures

### Type

`AFK`

### What to build

Make saved-workspace read and write failures visible without making the current
session unusable. A user should be able to continue with an in-memory sheet or
workout selection, while the application clearly reports that the choice could
not be restored or persisted and therefore may not survive a restart.

### Acceptance criteria

- [ ] Failed workspace restoration produces a clear, non-crashing application
      error instead of being silently treated as empty state.
- [ ] Failed persistence of pasted sheet text, a selected sheet, or workout
      setup is surfaced to the user.
- [ ] A persistence failure does not discard an otherwise valid in-memory
      selection or prevent the current session from continuing.
- [ ] A later successful persistence operation clears the stale persistence
      error.
- [ ] Behavior tests cover restoration failure, write failure, recovery, and
      preservation of in-memory state through the public workspace interface.

### Blocked by

None - can start immediately.

### User stories covered

- Users can trust whether their selected sheet and workout setup will restore
  on the next launch.
- Local state failures remain recoverable and do not block workout logging.

## Slice 2: Own the native authentication event lifecycle

### Type

`AFK`

### What to build

Give the native Google account gateway explicit ownership of its authentication
event listener. Initialization should create at most one listener, and disposing
the gateway should detach it so a retired gateway cannot retain resources or
publish account changes.

### Acceptance criteria

- [ ] Repeated initialization uses one authentication event subscription.
- [ ] Disposing the gateway cancels its subscription exactly once.
- [ ] Authentication events cannot notify listeners after the gateway is
      disposed.
- [ ] Existing restore, explicit login, authorization-header, and logout
      behavior is unchanged.
- [ ] Focused tests exercise the lifecycle through an intentional injectable
      interface rather than a simulated Google service response.

### Blocked by

None - can start immediately.

### User stories covered

- Recreating or shutting down the application does not leave authentication
  listeners attached to retired state owners.
- Account state remains single-sourced by the active native gateway.

## Slice 3: Decompose write planning by responsibility

### Type

`AFK`

### What to build

Replace the oversized write-planning compilation units with cohesive internal
modules for plan contracts, stale-write expectations, preview application, and
the history, set, exercise, and workout planning strategies. Preserve the
existing public sheet-contract API and keep each module deep enough to own a
complete planning concern.

### Acceptance criteria

- [ ] Public plan types and planner entry points remain source-compatible for
      application and adapter callers.
- [ ] Stale-write expectations and rejection messages have one clear owner.
- [ ] In-memory preview application has one clear owner independent of planner
      orchestration.
- [ ] History, set, exercise, and workout planning strategies are separated by
      domain responsibility without shallow pass-through wrappers.
- [ ] No behavior changes occur in parsing, safety rejection, write previews,
      or generated write requests.
- [ ] Existing contract and adapter behavior tests pass without pinning the new
      private file layout.

### Blocked by

None - can start immediately.

### User stories covered

- Maintainers can change one write-planning concern without navigating an
  unrelated monolith.
- Workbook safety and human-readable sheet behavior remain stable through
  future planner changes.

## Slice 4: Clean up the resulting tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove temporary scaffolding and keep only the
smallest durable behavior tests for persistence errors, authentication
lifecycle ownership, and the unchanged public write-planning contract.

### Acceptance criteria

- [ ] The `test-cleanup` skill is used for this slice.
- [ ] Tests assert public behavior or intentional adapter interfaces rather
      than private helper names and file placement.
- [ ] Temporary TDD-only cases and redundant assertions are removed.
- [ ] Persistence recovery and authentication disposal retain focused coverage.
- [ ] The complete Flutter test suite and static analysis pass.
- [ ] Clean macOS and unsigned iOS release builds pass.

### Blocked by

- Slice 1: Surface workspace persistence failures.
- Slice 2: Own the native authentication event lifecycle.
- Slice 3: Decompose write planning by responsibility.

### User stories covered

- Future refactors retain a compact safety net around behavior instead of
  implementation details.
