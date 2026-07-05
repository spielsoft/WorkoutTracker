# Concise Code Names Replacement Log

Living log for the repo-wide concise-name cleanup.

## Slice 1

Status: committed after the initial hotspot pass.

### File renames

| Old file | New file |
| --- | --- |
| `lib/src/google_sheets/workout_tracker_workbook_initialization_plan.dart` | `lib/src/google_sheets/workbook_init_plan.dart` |
| `lib/src/google_sheets/workout_tracker_workbook_initializer.dart` | `lib/src/google_sheets/workbook_init.dart` |
| `lib/src/google_sheets/workout_tracker_workbook_template.dart` | `lib/src/google_sheets/workbook_template.dart` |
| `lib/src/app/google_spreadsheet_validation_service.dart` | `lib/src/app/spreadsheet_validation_service.dart` |
| `lib/src/app/google_spreadsheet_validation_wiring.dart` | `lib/src/app/spreadsheet_validation_wiring.dart` |
| `lib/src/app/workout_tracker_shell.dart` | `lib/src/app/shell.dart` |
| `lib/src/app/workout_tracker_shell_account.dart` | `lib/src/app/shell_account.dart` |
| `lib/src/app/workout_tracker_shell_workout.dart` | `lib/src/app/shell_workout.dart` |
| `lib/src/app/workout_tracker_shell_validation.dart` | `lib/src/app/shell_validation.dart` |
| `lib/src/app/workout_tracker_shell_exercise_authoring.dart` | `lib/src/app/shell_exercise_authoring.dart` |
| `lib/src/app/workout_tracker_shell_exercise_manager.dart` | `lib/src/app/shell_exercise_manager.dart` |
| `lib/src/app/workout_tracker_shell_visual_states.dart` | `lib/src/app/shell_visual_states.dart` |
| `lib/src/app/workout_tracker_shell_logging.dart` | `lib/src/app/shell_logging.dart` |
| `lib/src/app/workout_tracker_shell_accessibility.dart` | `lib/src/app/shell_accessibility.dart` |
| `test/google_sheets/workout_tracker_workbook_template_test.dart` | `test/google_sheets/workbook_template_test.dart` |

### Symbol replacements

| Old name | New name |
| --- | --- |
| `WorkoutTrackerWorkbookInitializerFactory` | `WorkbookInitFactory` |
| `WorkoutTrackerWorkbookInitializer` | `WorkbookInit` |
| `GoogleApisWorkoutTrackerWorkbookInitializer` | `GoogleApisWorkbookInit` |
| `WorkoutTrackerWorkbookTabRewritePlan` | `WorkbookTabPlan` |
| `WorkoutTrackerWorkbookTab` | `WorkbookTab` |
| `WorkoutTrackerWorkbook` | `Workbook` |
| `loadWorkoutTrackerWorkbookTemplate` | `loadWorkbookTemplate` |
| `workoutTrackerWorkbookTemplate` | `workbookTemplate` |
| `GoogleSpreadsheetValidationService` | `SpreadsheetValidationService` |
| `GoogleSpreadsheetWorkbookAccess` | `SpreadsheetAccess` |
| `SpreadsheetValidationReport` | `ValidationReport` |
| `WorkoutTrackerController` | `AppController` |
| `WorkoutTrackerScrollBehavior` | `AppScrollBehavior` |
| `validateSpreadsheetSelection` | `validateSelection` |
| `reportSpreadsheetSelectionFailure` | `reportSelectionFailure` |
| `addExistingExerciseToWorkout` | `addExerciseToWorkout` |
| `GoogleWorkspaceAccessStateController` | `WorkspaceStateController` |
| `GoogleWorkspaceAccessStateOwner` | `WorkspaceStateOwner` |
| `GoogleWorkspaceAccessState` | `WorkspaceAccessState` |
| `readGoogleWorkspaceAccessState` | `readWorkspaceState` |
| `writeGoogleWorkspaceAccessState` | `writeWorkspaceState` |
| `clearGoogleWorkspaceAccessState` | `clearWorkspaceState` |
| `GoogleWorkspaceLifecycleController` | `WorkspaceController` |
| `GoogleWorkspaceLifecycle` | `WorkspaceLifecycle` |
| `GoogleWorkspaceState` | `WorkspaceUiState` |
| `authorizeSpreadsheetCreation` | `authorizeSheetCreation` |
| `resolveSelectedSpreadsheet` | `resolveSelection` |
| `GooglePickerAuthorizationSnapshot` | `PickerAuth` |
| `GooglePickerAuthorizationGateway` | `PickerAuthGateway` |
| `GooglePickerAuthorizationStore` | `PickerAuthStore` |
| `restoreGooglePickerAuthorization` | `restorePickerAuth` |
| `updateGooglePickerAuthorization` | `updatePickerAuth` |
| `GoogleSignInAuthorizationGateway` | `SignInAuthGateway` |
| `NativeGoogleSignInAuthorizationGateway` | `NativeSignInAuthGateway` |
| `workoutTrackerGoogleSignInClientIdDartDefine` | `googleClientIdDef` |
| `workoutTrackerGoogleSignInClientId` | `googleClientId` |
| `workoutTrackerGoogleSignInServerClientIdDartDefine` | `googleServerClientIdDef` |
| `workoutTrackerGoogleSignInServerClientId` | `googleServerClientId` |
| `GooglePickerCallbackReceiverFactory` | `PickerCallbackReceiverFactory` |
| `GooglePickerCallbackReceiver` | `PickerCallbackReceiver` |
| `NativeGooglePickerCallbackReceiver` | `NativePickerCallbackReceiver` |
| `GooglePickerCallbackResult` | `PickerCallbackResult` |
| `MobileGoogleDriveSpreadsheetPicker` | `MobileSpreadsheetPicker` |
| `GooglePickerAppConfig` | `PickerAppConfig` |
| `loadGooglePickerAppConfig` | `loadPickerAppConfig` |
| `defaultGooglePickerAppConfigAsset` | `defaultPickerAppConfigAsset` |
| `googlePickerAuthorizationUrl` | `pickerAuthorizationUrl` |
| `GoogleSheetsSpreadsheetCreator` | `SpreadsheetCreator` |
| `GooglePickerNativeCallbackValidation` | `PickerCallbackValidation` |
| `validateGooglePickerNativeCallback` | `validatePickerCallback` |
| `_newGooglePickerCallbackState` | `_newPickerCallbackState` |
| `_isGooglePickerNativeCallbackUri` | `_isNativeCallbackUri` |
| `buildExerciseLoggingContext` | `buildLoggingContext` |
| `planPrimaryWorkoutPlacement` | `planPrimaryPlacement` |
| `planBackupWorkoutPlacement` | `planBackupPlacement` |
| `planWorkoutExerciseReorder` | `planExerciseReorder` |
| `planPrimaryWorkoutExerciseDeletion` | `planPrimaryExerciseDeletion` |
| `planCanonicalExerciseAppend` | `planCanonicalAppend` |
| `planCanonicalExerciseUpdate` | `planCanonicalUpdate` |
| `planCanonicalExerciseReorder` | `planCanonicalReorder` |
| `googleAuthorization` | `pickerAuth` |
| `_MemoryGoogleWorkspaceAccessStateOwner` | `_MemoryWorkspaceStateOwner` |
| `_RecordingGoogleSignInAuthorizationGateway` | `_RecordingSignInAuthGateway` |
| `_UnusedGoogleSignInAuthorizationGateway` | `_UnusedSignInAuthGateway` |
| `_updateGooglePickerAuthorization` | `_updatePickerAuth` |
| `_authorizeSpreadsheetCreation` | `_authorizeSheetCreation` |
| `_googlePickerCallbackStateBytes` | `_pickerCallbackStateBytes` |
| `_googlePickerSpreadsheetIdPattern` | `_sheetIdPattern` |

### Files simplified in slice 1

- `lib/main.dart`
- `lib/google_sheets.dart`
- `lib/workout_tracker_app.dart`
- `lib/src/app/app_state_store.dart`
- `lib/src/app/google_account_session.dart`
- `lib/src/app/google_authorization_client.dart`
- `lib/src/app/google_workspace.dart`
- `lib/src/app/spreadsheet_selection.dart`
- `lib/src/app/spreadsheet_validation.dart`
- `lib/src/app/spreadsheet_validation_core.dart`
- `lib/src/app/spreadsheet_validation_service.dart`
- `lib/src/app/spreadsheet_validation_wiring.dart`
- `lib/src/app/workout_tracker_controller.dart`
- `lib/src/app/shell.dart`
- `lib/src/app/shell_account.dart`
- `lib/src/app/shell_workout.dart`
- `lib/src/app/shell_validation.dart`
- `lib/src/app/shell_exercise_authoring.dart`
- `lib/src/app/shell_exercise_manager.dart`
- `lib/src/app/shell_visual_states.dart`
- `lib/src/app/shell_logging.dart`
- `lib/src/app/shell_accessibility.dart`
- `lib/src/google_sheets/workbook_init_plan.dart`
- `lib/src/google_sheets/workbook_init.dart`
- `lib/src/google_sheets/workbook_template.dart`
- `lib/src/sheet_contract/active_sheet/parsed_active_sheet.dart`
- `lib/src/sheet_contract/active_sheet/read_models.dart`
- `lib/src/sheet_contract/active_sheet/write_plan_domain_planners.dart`
- `lib/src/sheet_contract/active_sheet/write_plans.dart`

## Remaining work

- Audit every Dart file under `lib` for names that are still too long even when they no longer carry the original project/module prefixes.
- Commit follow-up slices in small batches and append their replacements here.

## Slice 2

Status: controller and shell follow-up pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `workbookCommands` | `svc` |
| `_confirmWriteReads` | `_readRetries` |
| `_ControllerActionFailure` | `_SaveFail` |
| `_WorkoutTrackerScreen` | `_AppScreen` |
| `_ExercisePlacementKind` | `_PlaceKind` |
| `_PlacementIntent` | `_PlaceIntent` |
| `_SheetChooser` | `_SheetPick` |
| `_NamePromptDialog` | `_NameDialog` |

### Files simplified in slice 2

- `lib/src/app/workout_tracker_controller.dart`
- `lib/src/app/shell.dart`
- `lib/src/app/shell_workout.dart`
- `test/app/workout_tracker_controller_test.dart`
- `test/widget_test.dart`
