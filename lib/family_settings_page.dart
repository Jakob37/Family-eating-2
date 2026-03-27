part of 'main.dart';

class FamilySettingsPage extends StatefulWidget {
  const FamilySettingsPage({
    super.key,
    this.cloudStatusSummary,
    this.onExportJsonData,
    this.onImportJsonData,
    this.loadAutomaticBackupsEnabled,
    this.onAutomaticBackupsEnabledChanged,
    this.onListAutomaticBackups,
    this.onRestoreAutomaticBackup,
    this.onPullLatestHouseholdData,
    this.onReloadData,
  });

  static const String routeName = '/settings';

  final String Function(AppCloudSync cloudSync)? cloudStatusSummary;
  final Future<String?> Function()? onExportJsonData;
  final Future<String?> Function()? onImportJsonData;
  final Future<bool> Function()? loadAutomaticBackupsEnabled;
  final Future<String?> Function(bool enabled)?
  onAutomaticBackupsEnabledChanged;
  final Future<List<FoodBackupEntry>> Function()? onListAutomaticBackups;
  final Future<String?> Function(String backupId)? onRestoreAutomaticBackup;
  final Future<String?> Function()? onPullLatestHouseholdData;
  final Future<void> Function()? onReloadData;

  @override
  State<FamilySettingsPage> createState() => _FamilySettingsPageState();
}

class _FamilySettingsPageState extends State<FamilySettingsPage> {
  static final Uri _changelogUri = Uri.parse(kAppChangelogUrl);

  final TextEditingController _emailController = TextEditingController(
    text: AppCloudSync.instance.currentUserEmail ?? '',
  );
  final TextEditingController _householdNameController =
      TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  String? _actionMessage;
  HouseholdInvite? _latestInvite;
  bool _automaticBackupsEnabled = false;
  bool _isLoadingAutomaticBackupsPreference = false;

  AppCloudSync get _cloudSync => AppCloudSync.instance;

  @override
  void initState() {
    super.initState();
    _loadAutomaticBackupPreference();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _householdNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAutomaticBackupPreference() async {
    final Future<bool> Function()? loader = widget.loadAutomaticBackupsEnabled;
    if (loader == null) {
      return;
    }

    setState(() {
      _isLoadingAutomaticBackupsPreference = true;
    });
    final bool enabled = await loader();
    if (!mounted) {
      return;
    }
    setState(() {
      _automaticBackupsEnabled = enabled;
      _isLoadingAutomaticBackupsPreference = false;
    });
  }

  Future<void> _runAction(
    Future<String?> Function() action, {
    String? successMessage,
    bool reloadData = true,
  }) async {
    setState(() {
      _actionMessage = null;
    });
    final String? result = await action();
    if (!mounted) {
      return;
    }
    setState(() {
      _actionMessage =
          result ??
          successMessage ??
          'Done. If you used email sign-in, open the link from your inbox on this device.';
    });
    if (reloadData) {
      await widget.onReloadData?.call();
    }
  }

  Future<void> _createInviteCode() async {
    setState(() {
      _actionMessage = null;
    });
    final HouseholdInvite? invite = await _cloudSync.createInvite();
    if (!mounted) {
      return;
    }
    setState(() {
      _latestInvite = invite;
      _actionMessage = invite == null
          ? _cloudSync.lastSyncError ?? 'Could not create invite code.'
          : 'Invite code ready to share.';
    });
  }

  Future<void> _copyInviteCode() async {
    final HouseholdInvite? latestInvite = _latestInvite;
    if (latestInvite == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: latestInvite.code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite code copied.')));
  }

  Future<void> _openChangelog() async {
    final bool didLaunch = await launchUrl(
      _changelogUri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open changelog.')),
      );
    }
  }

  String _backupTimeLabel(BuildContext context, DateTime savedAt) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return '${localizations.formatFullDate(savedAt)} at '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(savedAt))}';
  }

  Future<void> _toggleAutomaticBackups(bool enabled) async {
    final Future<String?> Function(bool enabled)? onChanged =
        widget.onAutomaticBackupsEnabledChanged;
    if (onChanged == null) {
      return;
    }

    setState(() {
      _actionMessage = null;
      _automaticBackupsEnabled = enabled;
    });

    final String? result = await onChanged(enabled);
    if (!mounted) {
      return;
    }

    setState(() {
      _actionMessage =
          result ??
          (enabled
              ? 'Automatic backups enabled.'
              : 'Automatic backups disabled.');
    });
  }

  Future<bool> _confirmAutomaticBackupRestore(FoodBackupEntry backup) async {
    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: Text(
            'Restore "${backup.fileName}"? This replaces the current local data.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    return shouldRestore ?? false;
  }

  Future<void> _restoreAutomaticBackup() async {
    final Future<List<FoodBackupEntry>> Function()? listBackups =
        widget.onListAutomaticBackups;
    final Future<String?> Function(String backupId)? restoreBackup =
        widget.onRestoreAutomaticBackup;
    if (listBackups == null || restoreBackup == null) {
      return;
    }

    final List<FoodBackupEntry> backups = await listBackups();
    if (!mounted) {
      return;
    }

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No automatic backups are available yet.'),
        ),
      );
      return;
    }

    final FoodBackupEntry? selectedBackup =
        await showModalBottomSheet<FoodBackupEntry>(
          context: context,
          builder: (BuildContext bottomSheetContext) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const ListTile(
                    title: Text(
                      'Restore Automatic Backup',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Choose a recent local JSON snapshot'),
                  ),
                  const Divider(height: 1),
                  for (final FoodBackupEntry backup in backups)
                    ListTile(
                      leading: const Icon(Icons.history_outlined),
                      title: Text(
                        _backupTimeLabel(bottomSheetContext, backup.savedAt),
                      ),
                      subtitle: Text(backup.fileName),
                      onTap: () => Navigator.of(bottomSheetContext).pop(backup),
                    ),
                ],
              ),
            );
          },
        );

    if (!mounted || selectedBackup == null) {
      return;
    }

    final bool shouldRestore = await _confirmAutomaticBackupRestore(
      selectedBackup,
    );
    if (!mounted || !shouldRestore) {
      return;
    }

    final String? result = await restoreBackup(selectedBackup.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _actionMessage =
          result ?? 'Automatic backup restored. Current data was replaced.';
    });
  }

  String _cloudSummary() {
    final String Function(AppCloudSync cloudSync)? summary =
        widget.cloudStatusSummary;
    if (summary == null) {
      return '';
    }
    return summary(_cloudSync);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cloudSync,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _SettingsSection(
                title: 'App',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App version'),
                  subtitle: const Text(
                    'Open the GitHub changelog for this build',
                  ),
                  trailing: _VersionChip(
                    version: kAppVersionLabel,
                    onTap: _openChangelog,
                  ),
                  onTap: _openChangelog,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Data backup',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_actionMessage != null) ...<Widget>[
                      Text(_actionMessage!),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          key: const ValueKey<String>(
                            'open_json_export_button',
                          ),
                          onPressed: widget.onExportJsonData == null
                              ? null
                              : () => _runAction(widget.onExportJsonData!),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(
                            appDataFileAccess.supportsFilePickerFlow
                                ? 'Export JSON file'
                                : 'Export JSON',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey<String>(
                            'open_json_import_button',
                          ),
                          onPressed: widget.onImportJsonData == null
                              ? null
                              : () => _runAction(widget.onImportJsonData!),
                          icon: const Icon(Icons.download_outlined),
                          label: Text(
                            appDataFileAccess.supportsFilePickerFlow
                                ? 'Import JSON file'
                                : 'Import JSON',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.backup_outlined),
                      title: const Text('Automatic JSON backups'),
                      subtitle: const Text(
                        'Keep up to 20 recent local snapshots and update them automatically',
                      ),
                      value: _automaticBackupsEnabled,
                      onChanged:
                          widget.onAutomaticBackupsEnabledChanged == null ||
                              _isLoadingAutomaticBackupsPreference
                          ? null
                          : _toggleAutomaticBackups,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restore_outlined),
                      title: const Text('Restore from automatic backup'),
                      subtitle: const Text(
                        'Choose one of the recent local snapshots and replace current data',
                      ),
                      enabled:
                          widget.onListAutomaticBackups != null &&
                          widget.onRestoreAutomaticBackup != null,
                      onTap:
                          widget.onListAutomaticBackups == null ||
                              widget.onRestoreAutomaticBackup == null
                          ? null
                          : _restoreAutomaticBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Cloud & sync',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_cloudSummary()),
                    if (_cloudSync.lastSyncError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Latest sync error: ${_cloudSync.lastSyncError}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_cloudSync.isConfigured)
                      const Text(
                        'Supabase is not configured in this build yet. You can keep using the app locally, then add cloud config later.',
                      )
                    else ...<Widget>[
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _cloudSync.isSyncing
                            ? null
                            : () => _runAction(
                                () => _cloudSync.signInWithEmailOtp(
                                  _emailController.text,
                                ),
                                successMessage:
                                    'Sign-in link sent. Open it from your inbox on this device.',
                              ),
                        child: const Text('Send sign-in link'),
                      ),
                      if (_cloudSync.hasSession) ...<Widget>[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _householdNameController,
                          decoration: const InputDecoration(
                            labelText: 'New household name',
                            hintText: 'e.g. Family eating',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _cloudSync.isSyncing
                              ? null
                              : () => _runAction(
                                  () => _cloudSync.createHousehold(
                                    _householdNameController.text,
                                  ),
                                  successMessage:
                                      'Household created and connected.',
                                ),
                          child: const Text('Create household'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _inviteCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Invite code',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _cloudSync.isSyncing
                              ? null
                              : () => _runAction(
                                  () => _cloudSync.joinHousehold(
                                    _inviteCodeController.text,
                                  ),
                                  successMessage:
                                      'Joined household successfully.',
                                ),
                          child: const Text('Join household'),
                        ),
                        if (_cloudSync.hasActiveHousehold) ...<Widget>[
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: _cloudSync.isSyncing
                                ? null
                                : _createInviteCode,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Create invite code'),
                          ),
                          if (_latestInvite != null) ...<Widget>[
                            const SizedBox(height: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Invite code',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      _latestInvite!.code,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (_latestInvite!.expiresAt != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Expires ${_latestInvite!.expiresAt!.toLocal()}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: _copyInviteCode,
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copy code'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed:
                                _cloudSync.isSyncing ||
                                    widget.onPullLatestHouseholdData == null
                                ? null
                                : () => _runAction(
                                    widget.onPullLatestHouseholdData!,
                                    reloadData: false,
                                  ),
                            icon: const Icon(Icons.sync),
                            label: const Text('Pull latest household data'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _cloudSync.isSyncing
                              ? null
                              : () => _runAction(
                                  _cloudSync.signOut,
                                  successMessage: 'Signed out.',
                                ),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.version, required this.onTap});

  final String version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              version,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
