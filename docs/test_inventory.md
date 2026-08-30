# Release Test Inventory

The default credential-free gate is `flutter test` and is organized by public
contract:

| Contract | Test files | Purpose |
| --- | --- | --- |
| Workbook schema and models | `test/contract/active/{schema_safety,parser,models,history,healing,plans}_test.dart`, `test/fixtures/workbook_test.dart`, `test/log_format/format_test.dart` | Protect fixed columns, format-derived defaults and targets, history blocks, formula healing, raw-text preservation, and mutation plans. |
| Sheets adapters | `test/sheets/{client,read_adapter,write_adapter,template}_test.dart` | Verify the requests and operations this app sends to the Sheets client boundary, including workbook-version metadata. They do not establish Google behavior. |
| Application orchestration | `test/app/{service,validation,controller,workspace,store}_test.dart`, `test/app/ui/flow_test.dart` | Protect validation-before-write, rereads, account binding, persistence failures, restore and command serialization, and public commands. |
| Account and sheet access | `test/app/{account_session,auth_client,selection,create_dialog}_test.dart`, `test/app/ui/{sheet,sheet_flow,sheet_picker_page}_test.dart` | Protect optional Dart-override validation, Apple-native configuration delegation, accepted native callback shapes, requested scopes, app-owned adapter calls, account mismatch handling, and visible selection flows. Fakes do not establish Google Sign-In or Drive behavior. |
| Workout and exercise flows | `test/app/{progress,live_logging_entry}_test.dart`, `test/app/ui/{workout_home,logging_flow,log,navigation,placement_flow,exercise_library_flow,exercise_authoring,exercise_screen,library_search}_test.dart` | Protect generated default/target fields, target-prefilled logging, raw-set editing, navigation, authoring, placement, reorder auto-scroll, progress, and error recovery. |
| Shell and accessibility | `test/app/ui/shell_test.dart` | Runs Flutter accessibility guidelines in core states and checks narrow, large-text workflows through visible outcomes. |

## Unusual Checks

- `test/sheets/reset_harness_test.dart` proves the destructive reset harness is
  restricted to the named development Sheet and produces a valid deterministic
  fixture. It uses a fake initializer and does not contact Google.
- `test/app/live_logging_entry_test.dart` proves the application-owned live-test
  entry composes workspace selection and public logging commands. Its fake
  service is not evidence of Google behavior.
- No live Google test currently exists, so `flutter test` is the whole suite.
  The former live logging flow depended on the deleted `0.9` conversion; see
  `docs/testing.md` for the fixture that survives it and the opt-in rules any
  rebuilt live flow must follow.
- Native Apple bundle and accessibility smoke checks are release commands, not
  simulated Dart tests. See `BUILDING.md` and `docs/accessibility.md`.
- Dynamic-field live acceptance inspects both a conventional Weight/Reps/RPE
  exercise and a non-conventional format in the app and resulting Google
  Sheet. The local suite proves only WorkoutTracker's contracts.

## Cleanup Classification

Keep:

- Workbook safety, raw entries, write plans and adapter inputs.
- Configuration failures, persistence, account binding, restore and command
  serialization.
- Public screen flows, accessible names, narrow/large-text behavior, and live
  entry/reset safety.

Rewrite:

- Workout and exercise-library reorder tests now enter through
  `WorkoutTrackerApp` and prove edge auto-scroll through the accepted reorder
  request instead of inspecting a private `ScrollableState`.
- Exercise authoring now proves labeled input through the resulting public
  create command instead of semantic identifiers and `EditableText` internals.
- Sheet-name replacement is exercised through the platform text-input state
  and resulting picker request, without inspecting `EditableText` internals or
  exact selection offsets.

Delete:

- Tests of exact documentation wording and the complete published file list.
- Direct screen callback/type scaffolding duplicated by public app flows.
- Native Google listener initialization/cancellation counts and callback-order
  assertions; only accepted callback shapes and public account state remain.
- Exact widget geometry, border placement, decoration colors, widget classes,
  and icon-choice assertions.
