abstract base class AppView {
  const AppView({required this.isBusy, this.error});

  final bool isBusy;
  final String? error;
}

abstract base class LoadedView extends AppView {
  const LoadedView({
    required super.isBusy,
    required this.sheetLabel,
    super.error,
  });

  final String sheetLabel;
}

class CmdResult {
  const CmdResult._(this.ok, this.message);

  const CmdResult.done() : this._(true, null);

  const CmdResult.failed([String? message]) : this._(false, message);

  const CmdResult.result(bool ok, [String? message]) : this._(ok, message);

  final bool ok;
  final String? message;
}
