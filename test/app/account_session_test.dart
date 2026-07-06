import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test(
    'Picker authorization gateway exposes restored access token headers',
    () async {
      final gateway = PickerAuthGateway();

      await expectLater(
        gateway.authorizationHeaders(GoogleApisWbkClient.writeScopes),
        throwsA(isA<StateError>()),
      );

      gateway.restorePickerAuth(
        const PickerAuth(
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
        await gateway.authorizationHeaders(GoogleApisWbkClient.writeScopes),
        {'Authorization': 'Bearer picker-access-token'},
      );

      await gateway.signOut();

      expect(gateway.currentAuthorization, isNull);
      expect(gateway.currentAccount, isNull);
    },
  );

  test('Picker authorization refresh preserves existing account profile', () {
    final gateway = PickerAuthGateway(
      initial: const PickerAuth(
        accessToken: 'old-token',
        accountEmail: 'user@example.com',
        displayName: 'User Name',
        photoUrl: 'https://example.com/user.png',
      ),
    );

    gateway.updatePickerAuth(const PickerAuth(accessToken: 'new-token'));

    expect(gateway.currentAuthorization?.accessToken, 'new-token');
    expect(gateway.currentAccount?.email, 'user@example.com');
    expect(gateway.currentAccount?.displayName, 'User Name');
    expect(gateway.currentAccount?.photoUrl, 'https://example.com/user.png');
  });
}
