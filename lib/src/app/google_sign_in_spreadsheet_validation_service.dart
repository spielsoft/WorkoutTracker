import 'google_account_session.dart';
import 'google_authorization_client.dart';
import 'google_spreadsheet_validation_wiring.dart';

class GoogleSignInSpreadsheetValidationService
    extends GoogleSpreadsheetWorkbookAccess {
  GoogleSignInSpreadsheetValidationService({
    GoogleSignInAuthorizationGateway? authorizationGateway,
    GoogleAuthorizationClientFactory? authorizationClientFactory,
    ScopedGoogleApiAccess? googleAccess,
    super.workbookClientFactory,
  }) : super(
         googleAccess ??
             GoogleScopedApiAccess(
               authorizationGateway:
                   authorizationGateway ??
                   NativeGoogleSignInAuthorizationGateway(),
               authorizationClientFactory: authorizationClientFactory,
             ),
       );
}
