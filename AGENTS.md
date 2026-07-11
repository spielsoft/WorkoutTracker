# Agent Guidance

WorkoutTracker is a Flutter gym logger whose durable data is a user-owned
Google Sheet. This file contains only repository-wide rules and routes deeper
guidance by task.

## Start Here

Read this file and any plan explicitly named by the user. Then load only the
guidance relevant to the work:

| Work | Read |
| --- | --- |
| Sheet parsing, validation, planning, or writes | `docs/domain_contract.md` |
| Tests or live Google validation | `docs/testing.md` |
| Login, scopes, sheet choice, or Google setup | `docs/google_sheets_development_auth.md` |
| UI or semantics | `docs/accessibility.md` |
| Apple builds or release bundles | `COMPILE.md` |
| Creating or renaming code | `AGENTS/CONCISE-CODE-NAMES.md` and the `/concise-code-names` skill |

`README.md` is the human-facing project overview; it is not required reading
when the active task and routed guidance already provide enough context.
`APP_STORE.md` is historical and is not an authoritative source.

## Non-Negotiable Product Rules

- The Google Sheet is the source of truth; there is no workout-data backend.
- Never write to a workbook that fails the schema contract.
- Preserve unparseable set cells as raw text.
- A restored sheet remains bound to the Google account that selected it.
- Native Google Sign-In is the only runtime account authority.
- macOS and iOS are the prepared targets. Android readiness is explicitly
  deferred; generated Flutter scaffolding is not evidence of support.

## Working Rules

- Follow an active issue plan in dependency order.
- Preserve unrelated worktree changes and stage only the current slice.
- Prefer a small public interface that owns a complete workflow over several
  pass-through helpers.
- Keep sheet parsing, notation, write planning, Google adapters, application
  orchestration, and UI presentation as distinct concerns.
- Test observable behavior through public interfaces; do not test private
  helpers merely because they exist.
- Fakes may verify this app's request or adapter contract. They never prove
  Google, Firebase, OAuth, Picker, or app-store behavior.
- Use the narrowest relevant validation tier. Run broader gates only when the
  change or active plan requires them.
- Commit each completed and validated plan slice separately. Update a plan
  checkbox only after its acceptance criteria pass.

Live Google tests can modify the development workbook and are opt-in. Follow
`docs/testing.md`; never enable them implicitly.
