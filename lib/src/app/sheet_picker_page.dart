import 'dart:async';

import 'package:flutter/material.dart';

import 'selection.dart';

Future<SheetEntry?> showSheetPickerPage(
  BuildContext context,
  SheetViewReq req,
) {
  return Navigator.of(context).push<SheetEntry>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _SheetPickerPage(req: req),
    ),
  );
}

class _SheetPickerPage extends StatefulWidget {
  const _SheetPickerPage({required this.req});

  final SheetViewReq req;

  @override
  State<_SheetPickerPage> createState() => _SheetPickerPageState();
}

class _SheetPickerPageState extends State<_SheetPickerPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<SheetEntry> _items = const [];
  String? _err;
  bool _isLoading = false;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _load(value);
    });
    setState(() {});
  }

  Future<void> _load(String query) async {
    final current = ++_loadId;
    if (mounted) {
      setState(() {
        _err = null;
        _isLoading = true;
      });
    }
    try {
      final items = await widget.req.load(query.trim());
      if (!mounted || current != _loadId) {
        return;
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted || current != _loadId) {
        return;
      }
      setState(() {
        _err = 'Unable to load Google Sheets: $error';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {});
    _load('');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose workout sheet')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.req.accountEmail case final String email) ...[
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search Google Sheets',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: _onQueryChanged,
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body(context, query)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String query) {
    if (_err case final String err when _items.isEmpty) {
      return _ErrorCard(message: err, onRetry: () => _load(query));
    }
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty
              ? 'No recent Google Sheets found.'
              : 'No sheets matched "$query".',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        final subtitle = _subtitle(item);
        final timeLabel = _timeLabel(item);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: const CircleAvatar(child: Icon(Icons.table_chart_outlined)),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: timeLabel == null
              ? null
              : Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Picker unavailable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(message),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _subtitle(SheetEntry item) {
  final parts = <String>[
    if (item.owner case final String owner when owner.trim().isNotEmpty)
      owner.trim(),
    item.id,
  ];
  return parts.isEmpty ? null : parts.join('  •  ');
}

String? _timeLabel(SheetEntry item) {
  final time = item.viewedAt ?? item.modifiedAt;
  if (time == null) {
    return null;
  }
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}
