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

## Slice 3

Status: workspace and spreadsheet-selection follow-up pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `SpreadsheetPickerAvailability` | `PickerAvailability` |
| `DisabledSpreadsheetPicker` | `DisabledPicker` |
| `chooseUnavailableReason` | `chooseReason` |
| `createUnavailableReason` | `createReason` |
| `authorizationGateway` | `auth` |
| `authorizationClientFactory` | `authClientFactory` |
| `callbackReceiverFactory` | `callbackFactory` |
| `workbookInitializerFactory` | `initFactory` |
| `_selectedSpreadsheetForPickedId` | `_pickedSheet` |
| `_restoreAccountProfileFromDrive` | `_restoreProfile` |
| `createWorkoutSpreadsheet` | `createSheet` |
| `_spreadsheetPicker` | `_picker` |
| `spreadsheetPicker` | `picker` |
| `_initialSelectedSpreadsheet` | `_initialSelection` |
| `initialSelectedSpreadsheet` | `initialSelection` |
| `_initialSpreadsheetText` | `_initialText` |
| `initialSpreadsheetText` | `initialText` |
| `pastedSpreadsheetText` | `pastedText` |
| `pastedSheetFallbackAvailable` | `fallbackAvailable` |
| `persistPastedSpreadsheetText` | `persistPastedText` |
| `restoreResolvedSelection` | `restoreResolved` |
| `adoptSelectedSpreadsheet` | `adoptSelection` |
| `_currentPickerAuthorization` | `_currentAuth` |
| `_restorePickerAuthorization` | `_restoreAuth` |
| `_updateAccessStateBestEffort` | `_updateState` |

### Files simplified in slice 3

- `lib/main.dart`
- `lib/src/app/google_workspace.dart`
- `lib/src/app/spreadsheet_selection.dart`
- `lib/src/app/shell.dart`
- `test/app/create_sheet_dialog_test.dart`
- `test/app/google_authorization_client_test.dart`
- `test/app/google_workspace_test.dart`
- `test/app/logging_progress_behavior_test.dart`
- `test/app/spreadsheet_selection_test.dart`
- `test/app/spreadsheet_validation_test.dart`
- `test/widget_test.dart`

## Slice 4

Status: google-sheets infrastructure and default-name pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `GoogleSheetsReadAdapter` | `SheetsReadAdapter` |
| `GoogleSheetsWriteAdapter` | `SheetsWriteAdapter` |
| `GoogleApisSheetsWorkbookClient` | `GoogleApisWorkbookClient` |
| `workoutTrackerDefaultLogFormat` | `defaultLogFormat` |
| `usableWorkbookRowCount` | `usableRowCount` |
| `_operationsForWorkbookInitialization` | `_initOps` |
| `_valueInputModeForWorkbookInitialization` | `_initMode` |
| `_ensureInitializationTargets` | `_ensureTargets` |
| `_InitializationTargets` | `_InitTargets` |
| `_gridSnapshotFromApiSheet` | `_sheetSnapshot` |
| `sourceSheetRowNumber` | `fromRow` |
| `destinationSheetRowNumber` | `toRow` |
| `sourceSheetColumnNumber` | `fromColumn` |
| `destinationSheetColumnNumber` | `toColumn` |
| `applyExercisesWritePlan` | `applyExercisesPlan` |
| `_headerWritesForInsertion` | `_headerWrites` |
| `_exerciseRowUpdateWrites` | `_rowUpdateWrites` |
| `_exerciseRowAppendWrites` | `_rowAppendWrites` |

### Files simplified in slice 4

- `lib/src/app/google_workspace.dart`
- `lib/src/app/spreadsheet_selection.dart`
- `lib/src/app/spreadsheet_validation_service.dart`
- `lib/src/app/spreadsheet_validation_wiring.dart`
- `lib/src/google_sheets/read_adapter.dart`
- `lib/src/google_sheets/workbook_client.dart`
- `lib/src/google_sheets/workbook_init.dart`
- `lib/src/google_sheets/workbook_init_plan.dart`
- `lib/src/google_sheets/write_adapter.dart`
- `lib/src/log_format/log_format.dart`
- `lib/src/sheet_contract/active_sheet/input.dart`
- `lib/src/sheet_contract/active_sheet/write_plan_domain_planners.dart`
- `lib/src/workout_tracker_defaults.dart`
- `test/app/google_account_session_test.dart`
- `test/app/spreadsheet_validation_test.dart`
- `test/google_sheets/google_sheets_read_adapter_test.dart`
- `test/google_sheets/google_sheets_workbook_client_test.dart`
- `test/google_sheets/google_sheets_write_adapter_test.dart`

## Slice 5

Status: logging flow and logging-screen pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `ExerciseLoggingFlow` | `LoggingFlow` |
| `ExerciseLoggingViewModel` | `LoggingVm` |
| `_primarySheetRowNumber` | `_primaryRow` |
| `_selectedSheetRowNumber` | `_selectedRow` |
| `_ExerciseLoggingScreen.primarySheetRowNumber` | `_LogScreen.primaryRow` |
| `_ExerciseLoggingScreen.selectedSheetRowNumber` | `_LogScreen.selectedRow` |
| `loggedFormattedControllers` | `loggedControllers` |
| `planStructuredSetSave` | `planSetSave` |
| `planStructuredSetEdit` | `planSetEdit` |
| `clearNewSetControllers` | `clearNewSets` |
| `_syncLoggedEntryControllers` | `_syncLoggedControllers` |
| `_syncLoggedFieldControllers` | `_syncSetControllers` |
| `_disposeLoggedFieldControllers` | `_disposeSetControllers` |
| `removedFormattedSetNumbers` | `removedLoggedSets` |
| `_ExerciseLoggingScreen` | `_LogScreen` |
| `_ExerciseLoggingScreenState` | `_LogScreenState` |
| `_LoggedFormattedSetEditor` | `_LoggedSetFields` |

### Files simplified in slice 5

- `lib/src/app/exercise_logging_flow.dart`
- `lib/src/app/shell_logging.dart`
- `lib/src/app/shell_workout.dart`

## Slice 6

Status: validation-panel and exercise-manager pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `onRepairUnambiguousFormulaIssues` | `onRepairFormulas` |
| `_FormulaChoiceRepairItem` | `_RepairChoiceItem` |
| `_FormulaChoiceRepairItemState` | `_RepairChoiceItemState` |
| `_selectedExerciseSheetRowNumber` | `_selectedRow` |
| `_formulaHealingIssueLines` | `_issueLines` |
| `_ExerciseManagerInventory` | `_ExerciseLibrary` |
| `highlightedExerciseSheetRowNumber` | `highlightedRow` |
| `_repairFormulaIssue.selectedExerciseSheetRowNumber` | `_repairFormulaIssue.selectedRow` |

### Files simplified in slice 6

- `lib/src/app/shell.dart`
- `lib/src/app/shell_exercise_manager.dart`
- `lib/src/app/shell_validation.dart`
- `lib/src/app/shell_workout.dart`

## Slice 7

Status: exercise-authoring form pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `toCanonicalExerciseDefinition` | `toDefinition` |
| `_ExerciseAuthoringFormState` | `_AuthoringFormState` |
| `_ExerciseAuthoringTextField` | `_AuthoringField` |
| `_ExerciseAuthoringTextFieldState` | `_AuthoringFieldState` |
| `_exerciseAuthoringTitle` | `_authoringTitle` |
| `_exerciseAuthoringSubmitLabel` | `_submitLabelText` |
| `_exerciseAuthoringIcon` | `_authoringIcon` |
| `_draftFromControllers` | `_draft` |
| `_exerciseNameController` | `_nameCtrl` |
| `_descriptionController` | `_descCtrl` |
| `_defaultSetsController` | `_setsCtrl` |
| `_defaultRepsController` | `_repsCtrl` |
| `_defaultRPEController` | `_rpeCtrl` |
| `_defaultRestController` | `_restCtrl` |
| `_defaultTempoController` | `_tempoCtrl` |
| `_notesController` | `_notesCtrl` |
| `_logFormatController` | `_formatCtrl` |

### Files simplified in slice 7

- `lib/src/app/shell.dart`
- `lib/src/app/shell_exercise_authoring.dart`

## Slice 8

Status: workout-pane private UI pass.

### Symbol replacements

| Old name | New name |
| --- | --- |
| `_WorkoutSelectorField` | `_WorkoutField` |
| `_WorkoutSelectorFieldState` | `_WorkoutFieldState` |
| `_HistoryBlockSelectorField` | `_HistoryField` |
| `_HistoryBlockSelectorFieldState` | `_HistoryFieldState` |
| `_openAddAfterDropdownCloses` | `_openAddAfterClose` |
| `_PrimaryExerciseAddBackupMenuItem` | `_AddBackupMenuItem` |
| `_PrimaryExerciseDeleteMenuItem` | `_DeleteExerciseMenuItem` |
| `_AddExercisePlacementScreen` | `_PlaceExerciseScreen` |
| `_ExercisePlacementForm` | `_PlaceForm` |
| `_ExercisePlacementFormState` | `_PlaceFormState` |
| `_PlacementMetadataField` | `_MetaField` |
| `_CanonicalExerciseCreationScreen` | `_CreateExerciseScreen` |
| `_CanonicalExerciseEditScreen` | `_EditExerciseScreen` |
| `_handleExerciseSearchChanged` | `_handleSearch` |
| `_exerciseSearchController` | `_searchCtrl` |
| `_loadExerciseDefaults` | `_loadDefaults` |
| `_clearSelectionForAnother` | `_clearForNext` |
| `_metadataFromControllers` | `_metadata` |
| `_setsController` | `_setsCtrl` |
| `_repsController` | `_repsCtrl` |
| `_rpeController` | `_rpeCtrl` |
| `_restController` | `_restCtrl` |
| `_tempoController` | `_tempoCtrl` |
| `_notesController` | `_notesCtrl` |

### Files simplified in slice 8

- `lib/src/app/shell_workout.dart`
