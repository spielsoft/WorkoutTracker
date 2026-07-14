# Bundled exercise defaults review

The bundled catalog's authoritative data is
[`assets/exercise_defaults/default_exercises.json`](../assets/exercise_defaults/default_exercises.json).
The catalog-wide contract tests verify every definition rather than duplicating
all values in this document.

The current review established that:

- every Log Format uses Python-style `{Field}` placeholders and declares one
  through five unique fields;
- every Default Values map has the same fields in declaration order, and every
  value is a populated numeric string;
- measurement context belongs in exact field names such as `Weight (lbs)`,
  `Height (in)`, and `Reps (per side)`;
- every declared `Pain` value is `0`; and
- ranges and coaching qualifiers live in descriptions or notes instead of
  stored numeric values.

DB Step-Up is the five-field boundary case. Its format is exactly
`({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}`, its ordered defaults are
`12`, `15`, `8`, `8`, and `0`, and its rendered default is
`(12, 15)x8@8,0`.
