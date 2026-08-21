import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/connection.dart';
import '../data/database_key.dart';
import '../providers.dart';

/// True when [error] is the database-key failure, however it was wrapped.
///
/// The exception is thrown inside drift's lazy opener and reaches the UI
/// through a stream, so it can arrive re-wrapped by the layers in between.
/// Matching the message as well keeps the recovery screen reachable if it
/// does.
bool isMissingDatabaseKey(Object error) =>
    error is MissingDatabaseKeyException ||
    error.toString().contains('MissingDatabaseKeyException');

/// Shown when an encrypted database is on disk but its key is not.
///
/// There is no account and no backend: the key only ever existed in this
/// device's keychain, so nothing can decrypt the file once it is gone. The
/// honest options are to leave the file alone - in case the keychain entry
/// comes back, which a restore from a device backup can do - or to start over.
/// Both are offered plainly rather than a raw exception the user cannot act
/// on.
class LockedDatabaseView extends ConsumerStatefulWidget {
  const LockedDatabaseView({super.key});

  @override
  ConsumerState<LockedDatabaseView> createState() => _LockedDatabaseViewState();
}

class _LockedDatabaseViewState extends ConsumerState<LockedDatabaseView> {
  bool _working = false;

  Future<void> _startFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a fresh database?'),
        content: const Text(
          'This permanently deletes the locked database file. Anything logged '
          'in it is already unreadable without its key, and this cannot be '
          'undone.\n\n'
          'If you have an exported JSON or CSV backup, you can import it '
          'afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete and start fresh'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await deleteDatabaseFiles();
      if (!mounted) return;
      // Drops the failed database and everything derived from it, so the next
      // build opens a new one - with a key freshly minted, now that no
      // undecryptable file stands in the way.
      ref.invalidate(databaseProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the database: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_outline,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'This database is locked',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your logs are encrypted with a key kept in this device’s '
              'keychain, and that key is no longer there. It usually goes '
              'missing after a restore onto a new device, or after the app is '
              'reinstalled with different signing.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Nothing has been deleted. Without the key the existing data '
              'cannot be read — by this app or anyone else — so the '
              'only way forward is a fresh database.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _working ? null : _startFresh,
              child: Text(_working ? 'Working…' : 'Start fresh'),
            ),
            const SizedBox(height: 8),
            // Retrying is worth offering before anything is destroyed: on iOS
            // a keychain set to unlock-only reads as absent until the device
            // has been unlocked once since boot.
            TextButton(
              onPressed:
                  _working ? null : () => ref.invalidate(databaseProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
