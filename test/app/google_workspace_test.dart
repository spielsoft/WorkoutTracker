import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'restores selected sheet, account, picker availability, and fallback',
    () async {
      final accessState = _MemoryGoogleWorkspaceAccessStateOwner(
        const GoogleWorkspaceAccessState(
          spreadsheetText: 'pasted-spreadsheet-id',
          selectedSpreadsheet: SelectedSpreadsheet(
            spreadsheetId: 'selected-spreadsheet-id',
            name: '2026 Workouts',
            drivePath: 'My Drive / Workouts / 2026 Workouts',
            accountEmail: 'athlete@example.com',
          ),
          googleAuthorization: GooglePickerAuthorizationSnapshot(
            accessToken: 'picker-access-token',
            accountEmail: 'athlete@example.com',
            displayName: 'Athlete Name',
          ),
        ),
      );
      final accountSession = GooglePickerAuthorizationGateway();
      final workspace = GoogleWorkspaceLifecycleController(
        accessStateOwner: accessState,
        accountSession: accountSession,
        spreadsheetPicker: const DisabledSpreadsheetPicker(
          reason: 'Picker is unavailable.',
        ),
      );

      final restored = await workspace.restore();

      expect(
        restored.selectedSpreadsheet?.spreadsheetId,
        'selected-spreadsheet-id',
      );
      expect(
        restored.selectedSpreadsheet?.displayLabel,
        'My Drive / Workouts / 2026 Workouts',
      );
      expect(restored.pastedSpreadsheetText, 'pasted-spreadsheet-id');
      expect(restored.accountProfile?.email, 'athlete@example.com');
      expect(restored.accountProfile?.displayName, 'Athlete Name');
      expect(restored.pickerAuthorization?.accessToken, 'picker-access-token');
      expect(restored.pickerAvailability.canChoose, isFalse);
      expect(restored.pastedSheetFallbackAvailable, isFalse);
      expect(workspace.state, same(restored));
    },
  );

  test(
    'restores pasted sheet fallback when picker choosing is unavailable',
    () async {
      final workspace = GoogleWorkspaceLifecycleController(
        accessStateOwner: _MemoryGoogleWorkspaceAccessStateOwner(
          const GoogleWorkspaceAccessState(
            spreadsheetText: 'pasted-spreadsheet-id',
          ),
        ),
        spreadsheetPicker: const DisabledSpreadsheetPicker(
          reason: 'Picker is unavailable.',
        ),
      );

      final restored = await workspace.restore();

      expect(restored.selectedSpreadsheet, isNull);
      expect(restored.pastedSpreadsheetText, 'pasted-spreadsheet-id');
      expect(restored.pickerAvailability.canChoose, isFalse);
      expect(restored.pastedSheetFallbackAvailable, isTrue);
    },
  );
}

class _MemoryGoogleWorkspaceAccessStateOwner
    implements GoogleWorkspaceAccessStateOwner {
  _MemoryGoogleWorkspaceAccessStateOwner(this.value);

  @override
  GoogleWorkspaceAccessState value;

  @override
  Future<void> clear() async {
    value = const GoogleWorkspaceAccessState();
  }

  @override
  Future<GoogleWorkspaceAccessState> restore() async {
    return value;
  }

  @override
  Future<GoogleWorkspaceAccessState> update(
    GoogleWorkspaceAccessState Function(GoogleWorkspaceAccessState current)
    updateState,
  ) async {
    value = updateState(value);
    return value;
  }
}
