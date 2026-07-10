import 'package:flutter/material.dart';

import 'a11y.dart';

class NameDialog extends StatefulWidget {
  const NameDialog({
    required this.title,
    required this.label,
    this.initialValue,
    this.submitLabel = 'Add',
    this.textFieldKey,
    super.key,
  });

  final String title;
  final String label;
  final String? initialValue;
  final String submitLabel;
  final Key? textFieldKey;

  @override
  State<NameDialog> createState() => _NameDialogSt();
}

class _NameDialogSt extends State<NameDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
    _focus = FocusNode()..addListener(_selectText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_selectText);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _selectText() {
    if (!_focus.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focus.hasFocus) {
        _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        );
      }
    });
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: A11yTextField(
        label: widget.label,
        valueListenable: _ctrl,
        child: TextField(
          key: widget.textFieldKey,
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          selectAllOnFocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
