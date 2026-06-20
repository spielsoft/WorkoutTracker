---
name: code-review-loop
description: Run an iterative codebase improvement loop that alternates independent code review, temporary issue planning, slice-by-slice subagent implementation, commits, and repeated review passes until findings are marginal. Use when the user asks Codex to repeatedly review and improve a repository, run an architecture/code-quality cleanup loop, convert review findings into implementation slices, or drive review-to-commit remediation with subagents.
---

# Code Review Loop

## Operating Rules

Run a bounded review-to-implementation loop. Use subagents aggressively, but keep the main agent responsible for coordination, quality control, stopping decisions, and final reporting.

If the user does not specify which code review skill to use, ask before starting. Good options include `code-quality-review`, `architecture-deepening`, project-specific rule overlays, or another relevant review skill available in the session.

During code review, bias strongly toward compacting the codebase. Agents tend to produce high-volume, low-quality code, and most useful review rules indirectly push toward less code, clearer ownership, and fewer special cases. Avoid findings that inflate the codebase unless there is a compelling reason, such as wrong behavior, or a clear organizational improvement, such as splitting long lines or separating functionality into several files.

Always complete at least two review cycles unless the user sends a stop message or an external blocker prevents meaningful progress.

Stop after the second cycle or later when any of these conditions apply:

- Suggested changes are trivial, cosmetic, or not worth the risk.
- The findings look like random-walk churn, where each pass pushes style or structure in a different direction without converging.
- The remaining work is too broad or risky for autonomous slice commits.
- The user asks to stop, pause, summarize, or change direction.

## Loop

1. Establish the review skill.
   - Use the user-selected code review skill if provided.
   - If none is provided, ask one concise question naming available review-skill options.
   - Prefer a stricter project-specific review skill when one clearly applies.

2. Choose the session issue-plan file.
   - Pick one fixed filename inside the active project before creating issues. Prefer an existing project convention such as `issues/code-review-loop.md`; if no issue directory exists, use a clear top-level filename such as `CODE_REVIEW_LOOP_ISSUES.md`.
   - Inform the user of the absolute path before implementation work starts so they can track progress while the loop is running.
   - Reuse this same file for every review cycle in the current session. Update it in place instead of creating new per-cycle issue files.

3. Dispatch one independent review subagent.
   - Ask it to use the selected review skill against the current codebase.
   - Request prioritized findings with concrete file references, risk, and suggested slices.
   - Tell it to prefer compacting changes and to justify any recommendation that increases total code size.
   - Do not ask for implementation in the review subagent.

4. Convert findings into the fixed temporary issue plan.
   - Use `to-issues` to create or update the chosen issue file for the actionable findings.
   - Keep slices independently grabbable and narrow.
   - Exclude findings that are speculative, purely stylistic, or not backed by code evidence.

5. Close slices one by one.
   - Dispatch implementation subagents for individual slices when useful.
   - Require each implementation agent to follow the repository's local instructions, run relevant tests, and commit its slice.
   - Review each slice result before moving to the next one.
   - If a slice fails, either repair it directly or mark it blocked in the temporary issue plan.

6. Report the cycle result.
   - After each loop, tell the user a short list of what improved.
   - Keep this report brief and grounded in committed changes or issue-plan updates.
   - Include the fixed issue-plan file path when useful for tracking.

7. Repeat the review.
   - Start the next review cycle from the updated repository state.
   - Use the same review skill unless the user explicitly changes it or the original choice is clearly inapplicable.
   - Compare new findings against prior cycles before deciding whether they are converging or becoming churn.

## Issue Plan Handling

Treat the issue file as temporary working state unless the user asks to keep it. Keep its filename fixed for the whole session, keep it somewhere in the active project, and mention its absolute path in progress updates and the final report. Update checklist status as slices are completed, blocked, or discarded. Remove or clearly mark obsolete items when a later review shows they are no longer relevant.

Do not let the temporary issue plan become a broad architecture wish list. It should contain only code-backed work that can be closed and committed independently.

## Subagent Prompts

For review subagents, include:

- The selected review skill name.
- The repository path.
- A request for prioritized findings and implementation slices.
- A reminder not to modify files.

For implementation subagents, include:

- The exact issue slice.
- The repository path.
- The repository's commit and test expectations.
- A requirement to leave unrelated changes untouched.

## Final Report

Report:

- Review skill used.
- Number of review cycles completed.
- Short list of improvements from each cycle.
- Commits created, with hashes and slice titles.
- Tests run.
- Remaining findings, grouped as marginal, blocked, or recommended follow-up.
- Any unrelated worktree changes that were left unstaged.
