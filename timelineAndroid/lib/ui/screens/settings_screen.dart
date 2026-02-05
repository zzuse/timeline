import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_session_manager.dart';
import '../../services/sync_engine.dart';

/// Settings screen with sync integration
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthSessionManager>();
    final syncEngine = context.watch<SyncEngine>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader(context, 'Account'),
          
          if (authManager.isSignedIn) ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Signed In'),
              subtitle: const Text('You are signed in and syncing'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () => _showSignOutDialog(context, authManager),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Sign In'),
              subtitle: const Text('Sign in to sync your notes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => authManager.login(),
            ),
          ],
          
          if (authManager.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: ${authManager.errorMessage}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          
          const Divider(),

          // Sync section
          _buildSectionHeader(context, 'Sync'),
          
          if (authManager.isSignedIn) ...[
            ListTile(
              leading: Icon(
                _getSyncIcon(syncEngine.status),
                color: _getSyncColor(syncEngine.status, context),
              ),
              title: const Text('Sync Status'),
              subtitle: Text(_getSyncStatusText(syncEngine)),
              trailing: syncEngine.status == SyncStatus.syncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            
            if (syncEngine.lastSyncTime != null)
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Last Sync'),
                subtitle: Text(_formatLastSync(syncEngine.lastSyncTime!)),
              ),
            
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Now'),
              subtitle: const Text('Manually trigger sync'),
              enabled: syncEngine.status != SyncStatus.syncing,
              onTap: () => syncEngine.sync(),
            ),
            
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Full Resync'),
              subtitle: const Text('Clear local data and pull from server'),
              enabled: syncEngine.status != SyncStatus.syncing,
              onTap: () => _showFullResyncDialog(context, syncEngine),
            ),
          ] else ...[
            const ListTile(
              leading: Icon(Icons.sync_disabled),
              title: Text('Sync Disabled'),
              subtitle: Text('Sign in to enable sync'),
              enabled: false,
            ),
          ],
          
          const Divider(),

          // About section
          _buildSectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Timeline Notes'),
            subtitle: Text('Version 1.0.0 (Android)'),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Local Storage'),
            subtitle: Text('All notes stored locally with optional cloud sync'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getSyncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_outlined;
      case SyncStatus.syncing:
        return Icons.cloud_sync;
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.error:
        return Icons.cloud_off;
    }
  }

  Color? _getSyncColor(SyncStatus status, BuildContext context) {
    switch (status) {
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Theme.of(context).colorScheme.error;
      default:
        return null;
    }
  }

  String _getSyncStatusText(SyncEngine engine) {
    switch (engine.status) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.syncing:
        return 'Syncing... ${engine.syncProgress}%';
      case SyncStatus.success:
        return 'Synced successfully';
      case SyncStatus.error:
        return 'Error: ${engine.errorMessage ?? "Unknown error"}';
    }
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  Future<void> _showSignOutDialog(
    BuildContext context,
    AuthSessionManager authManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Unsync changes will be kept locally until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authManager.signOut();
    }
  }

  Future<void> _showFullResyncDialog(
    BuildContext context,
    SyncEngine syncEngine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Resync'),
        content: const Text(
          'This will clear all local notes and re-download from the server. Any unsynced local changes will be lost. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Resync'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await syncEngine.fullResync();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Full resync completed')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resync failed: $e')),
          );
        }
      }
    }
  }
}
