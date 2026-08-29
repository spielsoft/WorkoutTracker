# Faster Set Saves on Poor Connections

A saved set currently waits on a confirming read that can retry up to seven
times before the app responds, so a weak gym connection stalls logging. These
slices move that confirmation off the blocking path without giving up the
protections it provides.

Two boundaries are deliberate and are not to be optimized away:

- A save costs one validate read and one write before the app responds, not
  zero reads. The validate read is the guard against a row or column inserted
  directly in Google Sheets between the read and the write, and that window is
  widest on exactly the slow connections this work targets.
- Reorders, placements, repairs, deletes, and history-block creation keep their
  current blocking confirmation. They are not performed mid-workout, and
  applying their plans locally would require shifting stored cell-formula
  coordinates, which nothing does today.

- [ ] Slice 1: Apply a Saved Set Locally Before the Sheet Confirms It
- [ ] Slice 2: Surface a Set the Sheet Has Not Confirmed
- [ ] Slice 3: Refresh the Workbook While Resting
- [ ] Slice 4: Run the Full Local Guard
- [ ] Slice 5: Validate Save Timing Against Google Sheets

## Slice 1: Apply a Saved Set Locally Before the Sheet Confirms It

### Type

`AFK`

### What to build

A saved set becomes visible as soon as the write returns. The app applies the
write plan to its own parsed workbook and renders the result, then confirms
against the sheet in the background using the session that already outlives the
command. Today the same save waits on a confirming read that retries up to
seven times before anything appears.

Local application is limited to set saves, for a structural reason rather than
caution. History columns always sit to the right of the ten fixed columns, so a
set save's column insertion cannot shift the formula-bearing Exercise and Log
Format columns, and a set save never inserts rows. That makes local application
provably formula-safe for set saves and unsafe for plans that move rows or
insert columns further left.

A background confirmation that fails must not roll the workbook back. The
current synchronous path restores the pre-write baseline and throws, which is
correct only while the athlete is still waiting; once they have moved on it
would discard later sets. This slice reports such a failure through the
existing error surface and leaves the workbook alone. The next slice replaces
that with per-set reporting.

### Acceptance criteria

- [ ] A behavior test first demonstrates a saved set visible in the app before its confirming read completes.
- [ ] Applying a set-save plan locally yields the same parsed workbook the sheet reports once the confirmation lands.
- [ ] Targets, log formats, and exercise formulas are unchanged by local application, including when the plan inserts a history column.
- [ ] A save performs one validate read and one write before the app responds.
- [ ] A confirmation that never finds the set reports the failure without reverting the workbook or discarding later sets.
- [ ] Reorders, placements, repairs, deletes, and history-block creation keep their current blocking confirmation.
- [ ] A confirmation resolving after the athlete leaves the exercise, or after the session is disposed, neither throws nor updates a dead view.
- [ ] A write that itself fails still reports immediately, as it does today.

### Blocked by

None - can start immediately.

### User stories covered

- Owner report: saving a set stalls the app when gym network access is slow.

## Slice 2: Surface a Set the Sheet Has Not Confirmed

### Type

`AFK`

### What to build

A set whose write the sheet has not confirmed stays in the logged list, marked
as unconfirmed rather than removed or silently trusted. Reconciliation is
quiet: the next successful read either finds the set and clears the mark, or
does not and keeps it. The athlete is never asked to act on a state the app can
resolve by itself.

A confirmation that fails because the read failed means unknown, not lost. It
is retried rather than reported as a missing set, so a brief outage during rest
does not accuse the app of losing work.

This state is expected to be rare in practice, and observing it in a real gym
is not an acceptance gate. It is proven here by simulating a confirmation that
never finds the set.

### Acceptance criteria

- [ ] A behavior test first demonstrates a set marked unconfirmed after a confirmation that never finds it.
- [ ] An unconfirmed set keeps its logged value and position and is never silently removed.
- [ ] Semantics convey the unconfirmed state, so it is not carried by color or icon alone.
- [ ] A later successful read that finds the set clears the mark without a message.
- [ ] A later successful read that does not find the set keeps the mark.
- [ ] A confirmation that fails on a read error is retried and is not reported as a lost set.
- [ ] Clearing, editing, and undoing an unconfirmed set either behave as they do for a confirmed set or are refused with a stated reason.

### Blocked by

- Apply a Saved Set Locally Before the Sheet Confirms It

### User stories covered

- Owner report: a set that fails to confirm should be visible, not silently dropped or silently trusted.

## Slice 3: Refresh the Workbook While Resting

### Type

`AFK`

### What to build

After a write settles, the app refreshes the workbook in the background. Saving
a set starts a rest timer, so the connection is idle for the next two or three
minutes; that is when a read costs the athlete nothing. The refresh keeps the
cached report recent so the next save's validate read has current state to
compare against.

No coupling to the rest timer is needed. A save is what starts rest, so
refreshing after a settled write reaches the same idle window without the
shell's timer and the workbook session knowing about each other.

The validate read still runs before every write. Keeping the cache warm reduces
what that read has to reconcile; it does not replace it.

### Acceptance criteria

- [ ] A behavior test first demonstrates a background refresh following a settled write.
- [ ] A refresh in flight never blocks a save, a set edit, or navigation.
- [ ] A refresh that fails is silent and leaves the last good workbook in place.
- [ ] A validate read still runs before every write.
- [ ] Overlapping refreshes and saves cannot interleave into a stale view.
- [ ] A refresh resolving after the session is replaced or disposed is discarded.

### Blocked by

- Apply a Saved Set Locally Before the Sheet Confirms It

### User stories covered

- Owner report: reads should happen while resting, when the connection is otherwise idle.

## Slice 4: Run the Full Local Guard

### Type

`AFK`

### What to build

Run the repository's broad validation gates once the preceding slices have
landed, since each slice runs only the focused tests its change requires.

### Acceptance criteria

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test dev` reports no changes.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes in full.
- [ ] The macOS accessibility probe in `docs/accessibility.md` runs clean, or its skip is recorded with a reason.

### Blocked by

- Every preceding implementation slice

### User stories covered

- `docs/testing.md`: run the broad gates after a broad refactor.

## Slice 5: Validate Save Timing Against Google Sheets

### Type

`HITL`

### What to build

Exercise the changed save path against the real development workbook. This plan
alters how the app handles read-after-write visibility, which is the one
behavior in-memory fakes cannot establish: a fake returns whatever it was
handed, so it can prove the app's confirmation contract but never Google's
actual timing. The existing retry loop exists because that timing is not
guaranteed, so removing it from the blocking path deserves one real run.

Confirm that a set logged over a real connection appears in the sheet, that the
background confirmation resolves without a visible stall, and that the workbook
is left byte-for-byte correct.

This run writes to the allowlisted development sheet and is opt-in. It requires
explicit owner approval before it is enabled, per `docs/testing.md`, and it is
never enabled implicitly.

### Acceptance criteria

- [ ] A set logged against the live development sheet appears in the workbook and in the app without a blocking stall.
- [ ] The background confirmation resolves and leaves no set marked unconfirmed.
- [ ] Pre-existing history is unchanged by the run.
- [ ] The fixture is reset afterwards, and a reset failure fails the run distinctly.
- [ ] The run stays skipped without its environment flag.

### Blocked by

- Run the Full Local Guard

### User stories covered

- `AGENTS.md`: fakes never prove Google behavior.
- `docs/testing.md`: live Google validation is opt-in and owner-approved.
