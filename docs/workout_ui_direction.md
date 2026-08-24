# Workout UI Direction

This note records the intended separation between workout setup, workout
editing, and performing a workout. It also defines the smaller refinements that
can be made before that larger redesign.

## Future redesign

The current workout screen mixes the app's primary activity—performing a
workout—with structural editing. A future redesign should split those
responsibilities into distinct views.

### Main/setup view

The main view should provide access to:

- selecting a history block;
- selecting a workout within that context;
- adding and editing workouts;
- adding or managing exercises; and
- entering the selected workout.

History block should appear before workout because it establishes the context
that contains the workout being performed.

### Workout execution view

The execution view should be dedicated to performing the selected workout. Its
header should contain a back button and the selected workout name, truncated on
one line when necessary. The exercise list should follow directly below it.

For example:

`← Functional Athleticism & Up…`

Workout-structure controls such as add, delete, reorder, and editing menus
should not compete with logging in this view.

### Workout editor

A distinct editor should own structural changes such as adding, deleting,
reordering, and configuring primary or backup exercises.

This redesign is future scope. The near-term refinements below must not begin a
partial navigation restructure.

## Near-term refinements

### Selector order

Reverse the two selectors on the current screen so that History block appears
above Workout. Preserve their existing behavior and available actions.

### Keyboard-aware logging visibility

Keep the logging fields and Save set button in their existing document order.
When a numeric keypad or keyboard is visible:

1. The focused field has first priority and must remain visible.
2. Scroll the form only as much as needed to keep that field visible. As focus
   advances downward, move the visible region with it.
3. Among the scroll positions that keep the focused field fully visible, prefer
   one that also shows Save set in its normal position when such a position
   exists.
4. If both cannot fit, preserve the focused field and allow Save set to remain
   below the visible region.

Do not move, pin, float, or otherwise rearrange Save set in an attempt to force
both the field and button on screen. Existing keyboard-dismissal behavior should
remain available.

## Near-term acceptance checks

- History block precedes Workout in visual, focus, and semantics order on
  compact and wide layouts.
- Opening the numeric keypad never obscures the focused logging field.
- Moving focus through every configured field scrolls the form with that field.
- Save set remains in normal form order and becomes visible alongside the
  focused field whenever the available viewport permits it.
- Three-field and five-field logging formats are checked on an iPhone 13 mini
  sized viewport.
- No workout editing controls or navigation are relocated as part of these
  refinements.
