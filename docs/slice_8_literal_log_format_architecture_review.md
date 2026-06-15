# Slice 8 Literal Log Format Architecture Review

## Scope

This review covered the new literal log format Module, sheet-contract
read/write planning, and GUI dynamic field rendering.

The review used the required vocabulary: Module, Interface, Implementation,
Depth, Seam, Adapter, Leverage, Locality, and deletion test.

## Literal Log Format Module

The literal log format Module is deep enough for the behavior added through
Slice 7.

Its public Interface is `parseLogFormat`, `renderLogFormat`, `parseLogEntry`,
and the public log-format value objects. The Implementation hides token
parsing, default-format handling, validation, literal rendering, row-local
history parsing, blank-field preservation, and raw-entry fallback.

The deletion test says this Module is earning its keep. Deleting it would not
remove complexity; it would move literal token parsing and delimiter-sensitive
entry parsing into sheet-contract read models, write planning, and the GUI.
Keeping the Module gives those callers Leverage over the format contract and
preserves Locality for future format fixes.

## Sheet Contract Interface

The sheet-contract Interface remains the public test surface.

Row-local log formats enter through `parseActiveSheet(ActiveSheetInput)`, are
exposed on parsed workout slots and logging contexts, and are consumed by
`planSetLoggingWrite`, `planSetEdit`, and row-history read models. The
Implementation owns fixed-column placement, default format selection,
schema-violation reporting, row-local parsing, and compact set rendering.

The deletion test still favors keeping this behavior behind the sheet-contract
Module. Deleting the read/write planning Modules would spread row-validity,
history-block, and row-local format knowledge into GUI or Google Adapter code.

## GUI Dynamic Rendering

The GUI remains a caller of the backend Interfaces rather than a second parser.

Widget tests cross `WorkoutTrackerApp` and smoke the critical presentation and
interaction behavior: field labels come from the selected row, row switching
refreshes the labels and parsed values, raw controls remain visible, and saving
sends a backend write plan through the validation service. They do not assert
literal parsing internals or duplicate the log format Module's parser matrix.

## Cleanup

No duplicate tests failed the deletion test strongly enough to remove. The
overlapping examples cross different Interfaces:

- log-format tests own parser and renderer behavior local to the format Module
- sheet-contract tests own row-local sheet behavior through public parsed-sheet
  Interfaces
- widget tests own GUI rendering and interaction smoke behavior

The concrete cleanup was limited to the log-format Implementation: the
recursive entry parser now returns `null` explicitly on failed paths, removing
the analyzer warning without changing the Interface.
