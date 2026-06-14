import 'package:flutter/material.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  runApp(
    const WorkoutTrackerApp(
      validationService: AdcSpreadsheetValidationService(),
      initialSpreadsheetText: workoutTrackerDevelopmentSpreadsheetUrl,
    ),
  );
}
