import 'package:flutter/material.dart';

import 'account_session.dart';
import 'ui/flow.dart';

class AccountMenu extends StatefulWidget {
  const AccountMenu({required this.account, required this.run, super.key});

  final GoogleAccountProfile? account;
  final Future<CmdResult> Function(SheetCmd cmd) run;

  @override
  State<AccountMenu> createState() => _AccountMenuSt();
}

class _AccountMenuSt extends State<AccountMenu> {
  bool _isBusy = false;

  Future<void> _run(SheetCmd cmd, String failure) async {
    setState(() {
      _isBusy = true;
    });
    try {
      final result = await widget.run(cmd);
      final message = result.message;
      if (!result.ok && message != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$failure: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return PopupMenuButton<_GoogleAccountAction>(
      tooltip: account == null
          ? 'Connect Google Sheets'
          : 'Google Sheets account: ${account.email}',
      enabled: !_isBusy,
      icon: _GoogleAccountAvatar(account: account, isBusy: _isBusy),
      onSelected: (action) {
        switch (action) {
          case _GoogleAccountAction.signIn:
            _run(const SignIn(), 'Unable to log in to Google Sheets');
          case _GoogleAccountAction.signOut:
            _run(const SignOut(), 'Unable to log out of Google Sheets');
        }
      },
      itemBuilder: (context) {
        final summaryItem = PopupMenuItem<_GoogleAccountAction>(
          enabled: false,
          child: _GoogleAccountSummary(account: account),
        );
        if (account == null) {
          return [
            summaryItem,
            const PopupMenuDivider(),
            const PopupMenuItem<_GoogleAccountAction>(
              value: _GoogleAccountAction.signIn,
              child: Row(
                children: [
                  Icon(Icons.login),
                  SizedBox(width: 12),
                  Flexible(child: Text('Log in')),
                ],
              ),
            ),
          ];
        }
        return [
          summaryItem,
          const PopupMenuDivider(),
          PopupMenuItem<_GoogleAccountAction>(
            value: _GoogleAccountAction.signOut,
            child: Row(
              children: const [
                Icon(Icons.logout),
                SizedBox(width: 12),
                Flexible(child: Text('Log out')),
              ],
            ),
          ),
        ];
      },
    );
  }
}

enum _GoogleAccountAction { signIn, signOut }

class _GoogleAccountSummary extends StatelessWidget {
  const _GoogleAccountSummary({required this.account});

  final GoogleAccountProfile? account;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    final textTheme = Theme.of(context).textTheme;
    if (account == null) {
      return Text(
        'No Google Sheets account connected',
        style: textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          account.label,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(account.email, style: textTheme.bodySmall),
      ],
    );
  }
}

class _GoogleAccountAvatar extends StatelessWidget {
  const _GoogleAccountAvatar({required this.account, required this.isBusy});

  final GoogleAccountProfile? account;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final account = this.account;
    if (account == null) {
      return const Icon(Icons.account_circle_outlined);
    }
    final photoUrl = account.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 13, backgroundImage: NetworkImage(photoUrl));
    }
    final initial = account.label.isEmpty
        ? '?'
        : account.label[0].toUpperCase();
    return CircleAvatar(radius: 13, child: Text(initial));
  }
}
