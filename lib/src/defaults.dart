const defaultLogFormat = '{Weight}x{Reps}@{RPE}';
const currentWbkVersion = '1.1';

/// The version a converted [priorWbkVersion] workbook receives.
///
/// Schema 1.1 added the required Exercises `Timer Fields` column, which that
/// conversion never creates, so its result stays unsupported until the owner
/// upgrades the workbook themselves.
const convertedWbkVersion = '1.0';
const priorWbkVersion = '0.9';
