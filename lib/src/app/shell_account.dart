part of 'shell.dart';

class _GoogleAccountMenu extends StatefulWidget {
  const _GoogleAccountMenu({
    required this.accountSession,
    required this.onSignedOut,
  });

  final GoogleAccountSession accountSession;
  final Future<void> Function() onSignedOut;

  @override
  State<_GoogleAccountMenu> createState() => _GoogleAccountMenuState();
}

class _GoogleAccountMenuState extends State<_GoogleAccountMenu> {
  bool _isBusy = false;

  Future<void> _signOut() async {
    setState(() {
      _isBusy = true;
    });
    try {
      await widget.onSignedOut();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to log out of Google Sheets: $error')),
        );
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
    return ListenableBuilder(
      listenable: widget.accountSession,
      builder: (context, _) {
        final account = widget.accountSession.currentAccount;
        return PopupMenuButton<_GoogleAccountAction>(
          tooltip: account == null
              ? 'Connect Google Sheets'
              : 'Google Sheets account: ${account.email}',
          enabled: !_isBusy,
          icon: _GoogleAccountAvatar(account: account, isBusy: _isBusy),
          onSelected: (action) {
            switch (action) {
              case _GoogleAccountAction.signOut:
                _signOut();
            }
          },
          itemBuilder: (context) {
            final summaryItem = PopupMenuItem<_GoogleAccountAction>(
              enabled: false,
              child: _GoogleAccountSummary(account: account),
            );
            if (account == null) {
              return [summaryItem];
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
      },
    );
  }
}

enum _GoogleAccountAction { signOut }

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
