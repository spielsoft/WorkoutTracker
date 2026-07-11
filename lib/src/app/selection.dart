import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheets.dart';

import 'auth_client.dart';

typedef WbkInitFact = WbkInit Function(sheets.SheetsApi api);
typedef SheetViewFact = Future<SheetEntry?> Function(SheetViewReq req);
typedef SheetLoad = Future<List<SheetEntry>> Function(String query);

const _sheetMimeType = 'application/vnd.google-apps.spreadsheet';
const _recentPageSize = 25;
const _searchPageSize = 50;
const _unnamedSheet = 'Untitled spreadsheet';

class SheetViewReq {
  const SheetViewReq({required this.load, this.accountEmail});

  final SheetLoad load;
  final String? accountEmail;
}

class SheetEntry {
  const SheetEntry({
    required this.id,
    required this.name,
    this.webViewLink,
    this.owner,
    this.modifiedAt,
    this.viewedAt,
  });

  final String id;
  final String name;
  final String? webViewLink;
  final String? owner;
  final DateTime? modifiedAt;
  final DateTime? viewedAt;
}

class SelectedSheet {
  const SelectedSheet({
    required String spreadsheetId,
    required this.name,
    this.drivePath,
    this.webViewLink,
    this.accountEmail,
  }) : id = spreadsheetId;

  final String id;
  final String name;
  final String? drivePath;
  final String? webViewLink;
  final String? accountEmail;

  String get displayLabel {
    final path = drivePath?.trim();
    if (path != null && path.isNotEmpty) {
      return path;
    }
    final trimmedName = name.trim();
    return trimmedName.isEmpty ? _unnamedSheet : trimmedName;
  }

  Map<String, Object?> toJson() {
    return {
      'spreadsheetId': id,
      'name': name,
      if (drivePath != null) 'drivePath': drivePath,
      if (webViewLink != null) 'webViewLink': webViewLink,
      if (accountEmail != null) 'accountEmail': accountEmail,
    };
  }

  static SelectedSheet? fromJson(Object? value) {
    if (value case <String, Object?>{
      'spreadsheetId': final String spreadsheetId,
      'name': final String name,
    }) {
      return SelectedSheet(
        spreadsheetId: spreadsheetId,
        name: name,
        drivePath: value['drivePath'] as String?,
        webViewLink: value['webViewLink'] as String?,
        accountEmail: value['accountEmail'] as String?,
      );
    }
    return null;
  }
}

abstract interface class SheetPicker {
  PickerAvail get availability;

  Future<SelectedSheet?> chooseSheet();

  Future<SelectedSheet?> createSheet({String? name});
}

class PickerAvail {
  const PickerAvail.available() : chooseReason = null, createReason = null;

  const PickerAvail.unavailable({this.chooseReason, this.createReason});

  final String? chooseReason;
  final String? createReason;

  bool get canChoose => chooseReason == null;

  bool get canCreate => createReason == null;

  String? get summary {
    final reasons = {
      if (chooseReason case final String reason) reason,
      if (createReason case final String reason) reason,
    };
    return reasons.isEmpty ? null : reasons.join(' ');
  }
}

class DisabledPicker implements SheetPicker {
  const DisabledPicker({
    this.reason =
        'Google Drive sheet selection is temporarily disabled for this build.',
  });

  final String reason;

  @override
  PickerAvail get availability {
    return PickerAvail.unavailable(chooseReason: reason, createReason: reason);
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    throw StateError(reason);
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    throw StateError(reason);
  }
}

class DriveSheetPicker implements SheetPicker {
  DriveSheetPicker({
    required this.googleAccess,
    required this.showPicker,
    this.sheetCreator,
  });

  final SheetViewFact showPicker;
  final ApiAccess googleAccess;
  final SheetCreator? sheetCreator;

  @override
  PickerAvail get availability {
    return PickerAvail.unavailable(
      createReason: sheetCreator == null
          ? 'Google Drive sheet creation is not connected yet.'
          : null,
    );
  }

  @override
  Future<SelectedSheet?> chooseSheet() {
    return googleAccess.run(
      scopes: const [driveMetaScope],
      action: (resources) async {
        final picked = await showPicker(
          SheetViewReq(
            load: (query) => _loadSheets(resources.driveApi, query),
            accountEmail: googleAccess.account?.email,
          ),
        );
        if (picked == null) {
          return null;
        }
        return SelectedSheet(
          spreadsheetId: picked.id,
          name: picked.name,
          webViewLink: picked.webViewLink,
          accountEmail: googleAccess.account?.email,
        );
      },
    );
  }

  Future<List<SheetEntry>> _loadSheets(drive.DriveApi api, String query) async {
    final trimmed = query.trim();
    final listed = await api.files.list(
      q: _sheetQuery(trimmed),
      orderBy: trimmed.isEmpty
          ? 'viewedByMeTime desc,modifiedTime desc,name_natural'
          : 'name_natural',
      pageSize: trimmed.isEmpty ? _recentPageSize : _searchPageSize,
      spaces: 'drive',
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
      $fields:
          'files('
          'id,'
          'name,'
          'webViewLink,'
          'owners(displayName,emailAddress),'
          'modifiedTime,'
          'viewedByMeTime'
          ')',
    );
    final files = listed.files ?? const <drive.File>[];
    return [for (final file in files) ?_sheetEntry(file)];
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    final creator = sheetCreator;
    if (creator == null) {
      throw StateError('Google Drive sheet creation is not connected yet.');
    }
    return creator.createSheet(name: name);
  }
}

SheetEntry? _sheetEntry(drive.File file) {
  final id = file.id?.trim();
  if (id == null || id.isEmpty) {
    return null;
  }
  final name = file.name?.trim();
  return SheetEntry(
    id: id,
    name: name == null || name.isEmpty ? _unnamedSheet : name,
    webViewLink: file.webViewLink ?? sheetUrl(id),
    owner: _ownerLabel(file),
    modifiedAt: file.modifiedTime,
    viewedAt: file.viewedByMeTime,
  );
}

String? _ownerLabel(drive.File file) {
  for (final owner in file.owners ?? const <drive.User>[]) {
    final name = owner.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = owner.emailAddress?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
  }
  return null;
}

String _sheetQuery(String query) {
  final parts = <String>["mimeType = '$_sheetMimeType'", 'trashed = false'];
  for (final term in query.trim().split(RegExp(r'\s+'))) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    parts.add("name contains '${_escapeDriveQuery(trimmed)}'");
  }
  return parts.join(' and ');
}

String _escapeDriveQuery(String value) {
  return value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
}

class SheetCreator {
  SheetCreator({
    required this.googleAccess,
    WbkInitFact? initFactory,
    String Function()? titleFactory,
  }) : initFactory = initFactory ?? ((api) => GoogleApisWbkInit(api)),
       titleFactory = titleFactory ?? defaultSheetTitle;

  final ApiAccess googleAccess;
  final WbkInitFact initFactory;
  final String Function() titleFactory;

  Future<SelectedSheet> createSheet({String? name}) async {
    final requestedTitle = (name ?? titleFactory()).trim();
    final title = requestedTitle.isEmpty ? defaultSheetTitle() : requestedTitle;
    return googleAccess.run(
      scopes: GoogleApisWbkInit.writeScopes,
      action: (resources) async {
        final created = await resources.sheetsApi.spreadsheets.create(
          sheets.Spreadsheet(
            properties: sheets.SpreadsheetProperties(title: title),
          ),
          $fields: 'spreadsheetId,spreadsheetUrl,properties/title',
        );
        final spreadsheetId = created.spreadsheetId;
        if (spreadsheetId == null || spreadsheetId.trim().isEmpty) {
          throw StateError('Google Sheets did not return a spreadsheet ID.');
        }

        final workbook = await loadWbkTmpl();
        await initFactory(
          resources.sheetsApi,
        ).initializeWorkbook(spreadsheetId: spreadsheetId, workbook: workbook);

        return SelectedSheet(
          spreadsheetId: spreadsheetId,
          name: created.properties?.title ?? title,
          webViewLink: created.spreadsheetUrl ?? sheetUrl(spreadsheetId),
          accountEmail: googleAccess.account?.email,
        );
      },
    );
  }
}

String defaultSheetTitle() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return 'WorkoutTracker ${now.year}-$month-$day';
}

String sheetUrl(String spreadsheetId) {
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
}
