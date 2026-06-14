# Google Sheets Development Auth

Slice 12 only reads spreadsheet structure and cell display/formula data. Use the
minimum read-only Sheets scope:

```text
https://www.googleapis.com/auth/spreadsheets.readonly
```

The read adapter does not require Drive scopes and does not write to the sheet.
The live verification command uses Application Default Credentials:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_read.dart
```

For AFK verification, provide credentials before running the command:

1. Create or choose a Google Cloud project with the Google Sheets API enabled.
2. Create a service account or Application Default Credentials that can read
   Google Sheets with the scope above.
3. Share the development spreadsheet with the service account email if using a
   service account JSON file.
4. Set `GOOGLE_APPLICATION_CREDENTIALS` to the service account JSON path, or
   use an existing ADC setup.

If no ADC credentials are available, the smallest repeatable user-assisted step
is to install the Google Cloud CLI and create user ADC credentials:

```sh
gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/spreadsheets.readonly
```

Google Sheets API calls made with local user ADC also require a quota project.
Choose a Google Cloud project where you can enable services, then run:

```sh
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
gcloud services enable sheets.googleapis.com --project=YOUR_PROJECT_ID
```

Then rerun:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_read.dart
```

The development spreadsheet for Slice 12 is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```
