import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test(
    'Picker authorization gateway exposes restored access token headers',
    () async {
      final gateway = GooglePickerAuthorizationGateway();

      await expectLater(
        gateway.authorizationHeaders(GoogleApisSheetsWriteClient.writeScopes),
        throwsA(isA<StateError>()),
      );

      gateway.restoreGooglePickerAuthorization(
        const GooglePickerAuthorizationSnapshot(
          accessToken: 'picker-access-token',
          accountEmail: 'user@example.com',
          displayName: 'User Name',
          photoUrl: 'https://example.com/user.png',
        ),
      );

      expect(gateway.currentAccount?.email, 'user@example.com');
      expect(gateway.currentAccount?.displayName, 'User Name');
      expect(gateway.currentAccount?.photoUrl, 'https://example.com/user.png');
      expect(
        await gateway.authorizationHeaders(
          GoogleApisSheetsWriteClient.writeScopes,
        ),
        {'Authorization': 'Bearer picker-access-token'},
      );

      await gateway.signOut();

      expect(gateway.currentAuthorization, isNull);
      expect(gateway.currentAccount, isNull);
    },
  );

  test('Picker authorization refresh preserves existing account profile', () {
    final gateway = GooglePickerAuthorizationGateway(
      initial: const GooglePickerAuthorizationSnapshot(
        accessToken: 'old-token',
        accountEmail: 'user@example.com',
        displayName: 'User Name',
        photoUrl: 'https://example.com/user.png',
      ),
    );

    gateway.updateGooglePickerAuthorization(
      const GooglePickerAuthorizationSnapshot(accessToken: 'new-token'),
    );

    expect(gateway.currentAuthorization?.accessToken, 'new-token');
    expect(gateway.currentAccount?.email, 'user@example.com');
    expect(gateway.currentAccount?.displayName, 'User Name');
    expect(gateway.currentAccount?.photoUrl, 'https://example.com/user.png');
  });
}
