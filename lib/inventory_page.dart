// ignore_for_file: invalid_use_of_protected_member

part of 'main.dart';

enum InventoryStorageLocation {
  fridge('fridge', 'Fridge', Icons.kitchen_outlined),
  freezer('freezer', 'Freezer', Icons.ac_unit),
  pantry('pantry', 'Pantry', Icons.inventory_2_outlined),
  other('other', 'Other', Icons.category_outlined);

  const InventoryStorageLocation(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  static InventoryStorageLocation fromStorageValue(String rawValue) {
    for (final InventoryStorageLocation location in values) {
      if (location.storageValue == rawValue) {
        return location;
      }
    }
    return InventoryStorageLocation.fridge;
  }
}

class InventoryReminder {
  const InventoryReminder({
    required this.daysBeforeExpiry,
    required this.hour,
    required this.minute,
  });

  final int daysBeforeExpiry;
  final int hour;
  final int minute;

  factory InventoryReminder.fromJson(Map<String, dynamic> json) {
    final int daysBeforeExpiry = (json['daysBeforeExpiry'] is num)
        ? (json['daysBeforeExpiry'] as num).toInt()
        : int.tryParse('${json['daysBeforeExpiry']}') ?? 1;
    final int hour = (json['hour'] is num)
        ? (json['hour'] as num).toInt()
        : int.tryParse('${json['hour']}') ?? 9;
    final int minute = (json['minute'] is num)
        ? (json['minute'] as num).toInt()
        : int.tryParse('${json['minute']}') ?? 0;
    return InventoryReminder(
      daysBeforeExpiry: daysBeforeExpiry < 0 ? 0 : daysBeforeExpiry,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'daysBeforeExpiry': daysBeforeExpiry,
      'hour': hour,
      'minute': minute,
    };
  }

  InventoryReminder copyWith({
    int? daysBeforeExpiry,
    int? hour,
    int? minute,
  }) {
    return InventoryReminder(
      daysBeforeExpiry: daysBeforeExpiry ?? this.daysBeforeExpiry,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.expiryDate,
    this.quantityLabel = '',
    this.storageLocation = InventoryStorageLocation.fridge,
    this.notes = '',
    this.reminders = const <InventoryReminder>[],
  });

  final String id;
  final String name;
  final DateTime expiryDate;
  final String quantityLabel;
  final InventoryStorageLocation storageLocation;
  final String notes;
  final List<InventoryReminder> reminders;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString().trim();
    final String name = (json['name'] ?? '').toString().trim();
    final DateTime parsedExpiry = DateTime.tryParse(
          '${json['expiryDate'] ?? ''}',
        ) ??
        DateTime.now();
    final dynamic rawReminders = json['reminders'];
    return InventoryItem(
      id: id.isEmpty ? _createLocalId() : id,
      name: name,
      expiryDate: DateUtils.dateOnly(parsedExpiry),
      quantityLabel: (json['quantityLabel'] ?? '').toString().trim(),
      storageLocation: InventoryStorageLocation.fromStorageValue(
        json['storageLocation']?.toString() ?? '',
      ),
      notes: (json['notes'] ?? '').toString().trim(),
      reminders: rawReminders is List
          ? rawReminders
                .whereType<Map>()
                .map(
                  (Map value) =>
                      InventoryReminder.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList(growable: false)
          : const <InventoryReminder>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'expiryDate': DateUtils.dateOnly(expiryDate).toIso8601String(),
      'quantityLabel': quantityLabel,
      'storageLocation': storageLocation.storageValue,
      'notes': notes,
      'reminders': reminders
          .map((InventoryReminder reminder) => reminder.toJson())
          .toList(growable: false),
    };
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    DateTime? expiryDate,
    String? quantityLabel,
    InventoryStorageLocation? storageLocation,
    String? notes,
    List<InventoryReminder>? reminders,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      expiryDate: expiryDate ?? this.expiryDate,
      quantityLabel: quantityLabel ?? this.quantityLabel,
      storageLocation: storageLocation ?? this.storageLocation,
      notes: notes ?? this.notes,
      reminders: reminders ?? this.reminders,
    );
  }
}

extension on _MyHomePageState {
  static const List<int> _inventoryReminderDayOptions = <int>[0, 1, 2, 3, 7];

  void _sortInventoryItems() {
    _inventoryItems.sort((InventoryItem a, InventoryItem b) {
      final int dateCompare = a.expiryDate.compareTo(b.expiryDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _addInventoryItem() async {
    final InventoryItem? created = await _showInventoryItemDialog();
    if (created == null) {
      return;
    }
    final bool notificationsReady = created.reminders.isEmpty
        ? true
        : await AppNotificationScheduler.instance.requestPermissionsIfNeeded();
    setState(() {
      _inventoryItems.add(created);
      _sortInventoryItems();
    });
    await _persistData();
    if (!mounted || notificationsReady || created.reminders.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved item, but notifications are still disabled.'),
      ),
    );
  }

  Future<void> _editInventoryItem(InventoryItem item) async {
    final InventoryItem? edited = await _showInventoryItemDialog(existing: item);
    if (edited == null) {
      return;
    }
    final bool notificationsReady = edited.reminders.isEmpty
        ? true
        : await AppNotificationScheduler.instance.requestPermissionsIfNeeded();
    setState(() {
      final int index = _inventoryItems.indexWhere(
        (InventoryItem current) => current.id == item.id,
      );
      if (index == -1) {
        return;
      }
      _inventoryItems[index] = edited;
      _sortInventoryItems();
    });
    await _persistData();
    if (!mounted || notificationsReady || edited.reminders.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved item, but notifications are still disabled.'),
      ),
    );
  }

  Future<void> _removeInventoryItem(InventoryItem item) async {
    setState(() {
      _inventoryItems.removeWhere((InventoryItem current) => current.id == item.id);
    });
    await _persistData();
  }

  Future<void> _markInventoryItemUsedUp(InventoryItem item) async {
    setState(() {
      _inventoryItems.removeWhere((InventoryItem current) => current.id == item.id);
    });
    await _persistData();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Used up ${item.name}.')));
  }

  int _daysUntilExpiry(DateTime date) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(date).difference(today).inDays;
  }

  String _formatInventoryDate(DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _inventoryExpiryLabel(InventoryItem item) {
    final int daysUntil = _daysUntilExpiry(item.expiryDate);
    if (daysUntil < 0) {
      final int daysAgo = daysUntil.abs();
      return daysAgo == 1 ? 'Expired yesterday' : 'Expired $daysAgo days ago';
    }
    if (daysUntil == 0) {
      return 'Expires today';
    }
    if (daysUntil == 1) {
      return 'Expires tomorrow';
    }
    return 'Expires in $daysUntil days';
  }

  String _inventoryReminderLabel(InventoryReminder reminder) {
    final TimeOfDay time = TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    );
    final String formattedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time);
    final String dayLabel = switch (reminder.daysBeforeExpiry) {
      0 => 'On expiry day',
      1 => '1 day before',
      _ => '${reminder.daysBeforeExpiry} days before',
    };
    return '$dayLabel at $formattedTime';
  }

  Widget _buildInventoryBody() {
    final List<InventoryItem> expiredItems = _inventoryItems
        .where((InventoryItem item) => _daysUntilExpiry(item.expiryDate) < 0)
        .toList(growable: false);
    final List<InventoryItem> expiringSoonItems = _inventoryItems
        .where((InventoryItem item) {
          final int daysUntil = _daysUntilExpiry(item.expiryDate);
          return daysUntil >= 0 && daysUntil <= 3;
        })
        .toList(growable: false);
    final List<InventoryItem> laterItems = _inventoryItems
        .where((InventoryItem item) => _daysUntilExpiry(item.expiryDate) > 3)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: <Widget>[
        Text(
          'Track actual food you have at home and sort it by expiry date.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (_inventoryItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'No expiry items yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add items from the fridge, freezer, or pantry and optionally schedule reminders before they expire.',
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          _buildInventorySection('Expired', expiredItems),
          _buildInventorySection('Expiring soon', expiringSoonItems),
          _buildInventorySection('Later', laterItems),
        ],
      ],
    );
  }

  Widget _buildInventorySection(String title, List<InventoryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Nothing here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...items.map(_buildInventoryCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final int daysUntil = _daysUntilExpiry(item.expiryDate);
    final Color accentColor = switch (daysUntil) {
      < 0 => Theme.of(context).colorScheme.errorContainer,
      <= 3 => Theme.of(context).colorScheme.tertiaryContainer,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: accentColor,
                  child: Icon(item.storageLocation.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_inventoryExpiryLabel(item)} • ${_formatInventoryDate(item.expiryDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  avatar: Icon(item.storageLocation.icon, size: 16),
                  label: Text(item.storageLocation.label),
                ),
                if (item.quantityLabel.isNotEmpty)
                  Chip(label: Text(item.quantityLabel)),
                if (item.reminders.isNotEmpty)
                  Chip(label: Text('${item.reminders.length} reminder(s)')),
              ],
            ),
            if (item.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(item.notes),
            ],
            if (item.reminders.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                item.reminders
                    .map(_inventoryReminderLabel)
                    .join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _editInventoryItem(item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _markInventoryItemUsedUp(item),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Used up'),
                ),
                TextButton.icon(
                  onPressed: () => _removeInventoryItem(item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<InventoryItem?> _showInventoryItemDialog({
    InventoryItem? existing,
  }) async {
    final TextEditingController nameController = TextEditingController(
      text: existing?.name ?? '',
    );
    final TextEditingController quantityController = TextEditingController(
      text: existing?.quantityLabel ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existing?.notes ?? '',
    );
    InventoryStorageLocation selectedLocation =
        existing?.storageLocation ?? InventoryStorageLocation.fridge;
    DateTime expiryDate = DateUtils.dateOnly(
      existing?.expiryDate ?? DateTime.now().add(const Duration(days: 3)),
    );
    List<InventoryReminder> reminders = List<InventoryReminder>.from(
      existing?.reminders ?? const <InventoryReminder>[],
    );
    String? nameError;

    return showDialog<InventoryItem>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add expiry item' : 'Edit expiry item'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          hintText: 'e.g. Greek yogurt',
                          errorText: nameError,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: 'e.g. 2 tubs, 500 g, half bag',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<InventoryStorageLocation>(
                        initialValue: selectedLocation,
                        decoration: const InputDecoration(
                          labelText: 'Where is it?',
                        ),
                        items: InventoryStorageLocation.values
                            .map(
                              (InventoryStorageLocation location) =>
                                  DropdownMenuItem<InventoryStorageLocation>(
                                    value: location,
                                    child: Text(location.label),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (InventoryStorageLocation? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedLocation = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Expiry date'),
                        subtitle: Text(_formatInventoryDate(expiryDate)),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: expiryDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (picked == null) {
                            return;
                          }
                          setDialogState(() {
                            expiryDate = DateUtils.dateOnly(picked);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Optional notes',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Expiry reminders',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                reminders = <InventoryReminder>[
                                  ...reminders,
                                  const InventoryReminder(
                                    daysBeforeExpiry: 1,
                                    hour: 9,
                                    minute: 0,
                                  ),
                                ];
                              });
                            },
                            icon: const Icon(Icons.add_alert_outlined),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      if (reminders.isEmpty)
                        const Text(
                          'No reminders set. Add reminders like 1 day before at 09:00.',
                        )
                      else
                        ...List<Widget>.generate(reminders.length, (int index) {
                          final InventoryReminder reminder = reminders[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: reminder.daysBeforeExpiry,
                                    decoration: const InputDecoration(
                                      labelText: 'When',
                                    ),
                                    items: _inventoryReminderDayOptions
                                        .map(
                                          (int days) => DropdownMenuItem<int>(
                                            value: days,
                                            child: Text(
                                              days == 0
                                                  ? 'On expiry day'
                                                  : days == 1
                                                  ? '1 day before'
                                                  : '$days days before',
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (int? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        reminders[index] = reminder.copyWith(
                                          daysBeforeExpiry: value,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(
                                        hour: reminder.hour,
                                        minute: reminder.minute,
                                      ),
                                    );
                                    if (picked == null) {
                                      return;
                                    }
                                    setDialogState(() {
                                      reminders[index] = reminder.copyWith(
                                        hour: picked.hour,
                                        minute: picked.minute,
                                      );
                                    });
                                  },
                                  child: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatTimeOfDay(
                                      TimeOfDay(
                                        hour: reminder.hour,
                                        minute: reminder.minute,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      reminders = List<InventoryReminder>.from(
                                        reminders,
                                      )..removeAt(index);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String normalizedName = nameController.text.trim();
                    if (normalizedName.isEmpty) {
                      setDialogState(() {
                        nameError = 'Enter a name.';
                      });
                      return;
                    }
                    reminders.sort((InventoryReminder a, InventoryReminder b) {
                      final int daysCompare = b.daysBeforeExpiry.compareTo(
                        a.daysBeforeExpiry,
                      );
                      if (daysCompare != 0) {
                        return daysCompare;
                      }
                      final int hourCompare = a.hour.compareTo(b.hour);
                      if (hourCompare != 0) {
                        return hourCompare;
                      }
                      return a.minute.compareTo(b.minute);
                    });
                    Navigator.of(context).pop(
                      InventoryItem(
                        id: existing?.id ?? _createLocalId(),
                        name: normalizedName,
                        expiryDate: expiryDate,
                        quantityLabel: quantityController.text.trim(),
                        storageLocation: selectedLocation,
                        notes: notesController.text.trim(),
                        reminders: reminders,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      quantityController.dispose();
      notesController.dispose();
    });
  }
}
