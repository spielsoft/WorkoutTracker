part of 'workout_tracker_shell.dart';

class _GoogleAccountMenu extends StatefulWidget {
  const _GoogleAccountMenu({required this.accountSession});

  final GoogleAccountSession accountSession;

  @override
  State<_GoogleAccountMenu> createState() => _GoogleAccountMenuState();
}

class _GoogleAccountMenuState extends State<_GoogleAccountMenu> {
  bool _isSwitching = false;

  Future<void> _switchAccount() async {
    setState(() {
      _isSwitching = true;
    });
    try {
      await widget.accountSession.switchAccount(
        scopes: GoogleApisSheetsWriteClient.writeScopes,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to update Google Sheets authorization: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
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
          enabled: !_isSwitching,
          icon: _GoogleAccountAvatar(account: account, isBusy: _isSwitching),
          onSelected: (action) {
            switch (action) {
              case _GoogleAccountAction.switchAccount:
                _switchAccount();
            }
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<_GoogleAccountAction>(
                enabled: false,
                child: _GoogleAccountSummary(account: account),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_GoogleAccountAction>(
                value: _GoogleAccountAction.switchAccount,
                child: Row(
                  children: [
                    const Icon(Icons.switch_account_outlined),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        account == null
                            ? 'Connect Google Sheets'
                            : 'Switch Google Sheets account',
                        maxLines: 2,
                      ),
                    ),
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

enum _GoogleAccountAction { switchAccount }

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
