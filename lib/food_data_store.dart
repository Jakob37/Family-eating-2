part of 'main.dart';

class FoodDataMigrator {
  static const int currentVersion = 11;

  Map<String, dynamic> migrate(Map<String, dynamic> source) {
    int version = _readVersion(source);
    if (version > currentVersion) {
      throw FormatException(
        'Unsupported data version $version. Current version is $currentVersion.',
      );
    }

    Map<String, dynamic> working = Map<String, dynamic>.from(source);
    while (version < currentVersion) {
      switch (version) {
        case 1:
          working = _migrateV1ToV2(working);
          version = 2;
        case 2:
          working = _migrateV2ToV3(working);
          version = 3;
        case 3:
          working = _migrateV3ToV4(working);
          version = 4;
        case 4:
          working = _migrateV4ToV5(working);
          version = 5;
        case 5:
          working = _migrateV5ToV6(working);
          version = 6;
        case 6:
          working = _migrateV6ToV7(working);
          version = 7;
        case 7:
          working = _migrateV7ToV8(working);
          version = 8;
        case 8:
          working = _migrateV8ToV9(working);
          version = 9;
        case 9:
          working = _migrateV9ToV10(working);
          version = 10;
        case 10:
          working = _migrateV10ToV11(working);
          version = 11;
        default:
          throw FormatException(
            'No migration registered from version $version.',
          );
      }
    }
    return working;
  }

  int _readVersion(Map<String, dynamic> source) {
    final dynamic versionValue = source['schemaVersion'];
    if (versionValue is num) {
      return versionValue.toInt();
    }
    return 1;
  }

  Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> source) {
    final dynamic rawItems =
        source['foodItems'] ?? source['items'] ?? <dynamic>[];
    final List<dynamic> list = rawItems is List ? rawItems : <dynamic>[];

    final List<Map<String, dynamic>> migratedItems = list
        .map<Map<String, dynamic>>((dynamic item) {
          if (item is String) {
            return <String, dynamic>{
              'name': item.trim(),
              'proteins': <String>[],
            };
          }
          if (item is Map) {
            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
              item,
            );
            final String name = (itemMap['name'] ?? '').toString().trim();
            final dynamic rawProteins = itemMap['proteins'];
            final List<String> proteinIds = rawProteins is List
                ? rawProteins
                      .map(
                        (dynamic protein) => ProteinType.fromStorageValue(
                          '$protein',
                        )?.storageValue,
                      )
                      .whereType<String>()
                      .toList(growable: false)
                : <String>[];
            return <String, dynamic>{'name': name, 'proteins': proteinIds};
          }
          return <String, dynamic>{'name': '$item', 'proteins': <String>[]};
        })
        .where((Map<String, dynamic> item) {
          return (item['name'] as String).isNotEmpty;
        })
        .toList(growable: false);

    return <String, dynamic>{'schemaVersion': 2, 'foodItems': migratedItems};
  }

  Map<String, dynamic> _migrateV2ToV3(Map<String, dynamic> source) {
    final dynamic rawItems = source['foodItems'] ?? <dynamic>[];
    final List<dynamic> list = rawItems is List ? rawItems : <dynamic>[];

    final List<Map<String, dynamic>> migratedItems = list
        .map<Map<String, dynamic>>((dynamic item) {
          if (item is String) {
            return <String, dynamic>{
              'name': item.trim(),
              'proteins': <String>[],
              'cookedCount': 0,
            };
          }
          if (item is Map) {
            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
              item,
            );
            final String name = (itemMap['name'] ?? '').toString().trim();
            final dynamic rawProteins = itemMap['proteins'];
            final List<String> proteinIds = rawProteins is List
                ? rawProteins
                      .map(
                        (dynamic protein) => ProteinType.fromStorageValue(
                          '$protein',
                        )?.storageValue,
                      )
                      .whereType<String>()
                      .toList(growable: false)
                : <String>[];
            return <String, dynamic>{
              'name': name,
              'proteins': proteinIds,
              'cookedCount': _parseCookedCount(itemMap['cookedCount']),
            };
          }
          return <String, dynamic>{
            'name': '$item',
            'proteins': <String>[],
            'cookedCount': 0,
          };
        })
        .where((Map<String, dynamic> item) {
          return (item['name'] as String).isNotEmpty;
        })
        .toList(growable: false);

    return <String, dynamic>{'schemaVersion': 3, 'foodItems': migratedItems};
  }

  Map<String, dynamic> _migrateV3ToV4(Map<String, dynamic> source) {
    final dynamic rawItems = source['foodItems'] ?? <dynamic>[];
    final List<dynamic> list = rawItems is List ? rawItems : <dynamic>[];

    final List<Map<String, dynamic>> migratedItems = list
        .map<Map<String, dynamic>>((dynamic item) {
          if (item is String) {
            return <String, dynamic>{
              'name': item.trim(),
              'proteins': <String>[],
              'cookingLogs': <Map<String, dynamic>>[],
            };
          }
          if (item is! Map) {
            return <String, dynamic>{
              'name': '$item',
              'proteins': <String>[],
              'cookingLogs': <Map<String, dynamic>>[],
            };
          }

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String name = (itemMap['name'] ?? '').toString().trim();
          final dynamic rawProteins = itemMap['proteins'];
          final List<String> proteinIds = rawProteins is List
              ? rawProteins
                    .map(
                      (dynamic protein) => ProteinType.fromStorageValue(
                        '$protein',
                      )?.storageValue,
                    )
                    .whereType<String>()
                    .toList(growable: false)
              : <String>[];
          final int cookedCount = _parseCookedCount(itemMap['cookedCount']);

          final List<Map<String, dynamic>> placeholderLogs =
              List<Map<String, dynamic>>.generate(cookedCount, (int index) {
                return <String, dynamic>{
                  'cookedAt': DateTime.fromMillisecondsSinceEpoch(
                    0,
                    isUtc: true,
                  ).toIso8601String(),
                  'rating': null,
                  'durationMinutes': null,
                };
              }, growable: false);

          return <String, dynamic>{
            'name': name,
            'proteins': proteinIds,
            'cookingLogs': placeholderLogs,
          };
        })
        .where((Map<String, dynamic> item) {
          return (item['name'] as String).isNotEmpty;
        })
        .toList(growable: false);

    return <String, dynamic>{'schemaVersion': 4, 'foodItems': migratedItems};
  }

  Map<String, dynamic> _migrateV4ToV5(Map<String, dynamic> source) {
    final dynamic rawItems = source['foodItems'] ?? <dynamic>[];
    final List<dynamic> list = rawItems is List ? rawItems : <dynamic>[];

    final List<Map<String, dynamic>> migratedItems = list
        .map<Map<String, dynamic>>((dynamic item) {
          if (item is String) {
            return <String, dynamic>{
              'name': item.trim(),
              'proteins': <String>[],
              'ingredients': <String>[],
              'cookingLogs': <Map<String, dynamic>>[],
            };
          }
          if (item is! Map) {
            return <String, dynamic>{
              'name': '$item',
              'proteins': <String>[],
              'ingredients': <String>[],
              'cookingLogs': <Map<String, dynamic>>[],
            };
          }

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String name = (itemMap['name'] ?? '').toString().trim();
          final dynamic rawProteins = itemMap['proteins'];
          final List<String> proteinIds = rawProteins is List
              ? rawProteins
                    .map(
                      (dynamic protein) => ProteinType.fromStorageValue(
                        '$protein',
                      )?.storageValue,
                    )
                    .whereType<String>()
                    .toList(growable: false)
              : <String>[];

          final dynamic rawIngredients = itemMap['ingredients'];
          final List<String> ingredients = rawIngredients is List
              ? rawIngredients
                    .map((dynamic value) => '$value'.trim())
                    .where((String value) => value.isNotEmpty)
                    .toList(growable: false)
              : <String>[];

          final dynamic rawLogs = itemMap['cookingLogs'];
          final List<Map<String, dynamic>> cookingLogs = rawLogs is List
              ? rawLogs
                    .whereType<Map>()
                    .map((Map log) => Map<String, dynamic>.from(log))
                    .toList(growable: false)
              : <Map<String, dynamic>>[];

          return <String, dynamic>{
            'name': name,
            'proteins': proteinIds,
            'ingredients': ingredients,
            'cookingLogs': cookingLogs,
          };
        })
        .where((Map<String, dynamic> item) {
          return (item['name'] as String).isNotEmpty;
        })
        .toList(growable: false);

    return <String, dynamic>{'schemaVersion': 5, 'foodItems': migratedItems};
  }

  Map<String, dynamic> _migrateV5ToV6(Map<String, dynamic> source) {
    final dynamic rawItems = source['foodItems'] ?? <dynamic>[];
    final List<dynamic> list = rawItems is List ? rawItems : <dynamic>[];

    final List<Map<String, dynamic>> migratedItems = list
        .map<Map<String, dynamic>>((dynamic item) {
          if (item is! Map) {
            return <String, dynamic>{
              'name': '$item',
              'proteins': <String>[],
              'ingredients': <String>[],
              'cookingLogs': <Map<String, dynamic>>[],
              'defaultPortions': 4,
            };
          }

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          return <String, dynamic>{
            ...itemMap,
            'defaultPortions': FoodItem._parseDefaultPortions(
              itemMap['defaultPortions'],
            ),
          };
        })
        .where((Map<String, dynamic> item) {
          return (item['name'] ?? '').toString().trim().isNotEmpty;
        })
        .toList(growable: false);

    return <String, dynamic>{'schemaVersion': 6, 'foodItems': migratedItems};
  }

  Map<String, dynamic> _migrateV6ToV7(Map<String, dynamic> source) {
    return <String, dynamic>{
      ...source,
      'schemaVersion': 7,
      'foodItems': source['foodItems'] ?? <dynamic>[],
    };
  }

  Map<String, dynamic> _migrateV7ToV8(Map<String, dynamic> source) {
    return <String, dynamic>{
      ...source,
      'schemaVersion': 8,
      'foodItems': source['foodItems'] ?? <dynamic>[],
      'routineItems': source['routineItems'] ?? <dynamic>[],
    };
  }

  Map<String, dynamic> _migrateV8ToV9(Map<String, dynamic> source) {
    return <String, dynamic>{
      ...source,
      'schemaVersion': 9,
      'foodItems': source['foodItems'] ?? <dynamic>[],
      'routineItems': source['routineItems'] ?? <dynamic>[],
      'weekPlan': source['weekPlan'],
    };
  }

  Map<String, dynamic> _migrateV9ToV10(Map<String, dynamic> source) {
    final dynamic rawWeekPlan = source['weekPlan'];
    final List<dynamic> weekPlans = rawWeekPlan is Map
        ? <dynamic>[
            <String, dynamic>{
              'weekStart': _currentWeekStartKey(),
              ...Map<String, dynamic>.from(rawWeekPlan),
            },
          ]
        : <dynamic>[];
    return <String, dynamic>{
      ...source,
      'schemaVersion': 10,
      'foodItems': source['foodItems'] ?? <dynamic>[],
      'routineItems': source['routineItems'] ?? <dynamic>[],
      'weekPlans': source['weekPlans'] ?? weekPlans,
    };
  }

  Map<String, dynamic> _migrateV10ToV11(Map<String, dynamic> source) {
    return <String, dynamic>{
      ...source,
      'schemaVersion': 11,
      'foodItems': source['foodItems'] ?? <dynamic>[],
      'routineItems': source['routineItems'] ?? <dynamic>[],
      'weekPlans': source['weekPlans'] ?? <dynamic>[],
      'groceryChecklistItems': source['groceryChecklistItems'] ?? <dynamic>[],
    };
  }

  int _parseCookedCount(dynamic rawValue) {
    final int value = rawValue is num
        ? rawValue.toInt()
        : int.tryParse('$rawValue') ?? 0;
    return value < 0 ? 0 : value;
  }
}

class FoodDataStore {
  static const String _dataKey = 'family_eating.food_data';
  static const String _legacyFoodNamesKey = 'family_eating.food_names';

  final FoodDataMigrator _migrator = FoodDataMigrator();
  final FoodBackupService _backupService = const FoodBackupService();
  final FoodBackupPreferences _backupPreferences =
      const FoodBackupPreferences();

  Future<FamilyEatingData> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool needsWriteBack = false;

    Map<String, dynamic> source;
    final String? rawPayload = prefs.getString(_dataKey);

    if (rawPayload != null) {
      final dynamic decoded = _tryDecodeJson(rawPayload);
      if (decoded is Map) {
        source = Map<String, dynamic>.from(decoded);
      } else if (decoded is List) {
        source = <String, dynamic>{'schemaVersion': 1, 'foodItems': decoded};
        needsWriteBack = true;
      } else {
        await _clearStoredData(prefs);
        return const FamilyEatingData();
      }
    } else {
      final List<String>? legacyFoodNames = prefs.getStringList(
        _legacyFoodNamesKey,
      );
      if (legacyFoodNames == null) {
        return const FamilyEatingData();
      }
      source = <String, dynamic>{
        'schemaVersion': 1,
        'foodItems': legacyFoodNames,
      };
      needsWriteBack = true;
    }

    final int initialVersion = _readVersion(source);
    final Map<String, dynamic> migrated;
    try {
      migrated = _migrator.migrate(source);
    } on FormatException {
      await _clearStoredData(prefs);
      return const FamilyEatingData();
    }
    final FamilyEatingData data = FamilyEatingData(
      foodItems: _decodeFoodItems(migrated['foodItems']),
      routineItems: _decodeRoutineItems(migrated['routineItems']),
      weekPlans: _decodeWeekPlans(
        migrated['weekPlans'] ?? migrated['weekPlan'],
      ),
      groceryChecklistItems: _decodeGroceryChecklistItems(
        migrated['groceryChecklistItems'],
      ),
    );

    final CloudSnapshot? remoteSnapshot = await AppCloudSync.instance
        .fetchLatestSnapshot();
    if (remoteSnapshot != null) {
      try {
        final Map<String, dynamic> remoteMigrated = _migrator.migrate(
          remoteSnapshot.data,
        );
        final FamilyEatingData remoteData = FamilyEatingData(
          foodItems: _decodeFoodItems(remoteMigrated['foodItems']),
          routineItems: _decodeRoutineItems(remoteMigrated['routineItems']),
          weekPlans: _decodeWeekPlans(
            remoteMigrated['weekPlans'] ?? remoteMigrated['weekPlan'],
          ),
          groceryChecklistItems: _decodeGroceryChecklistItems(
            remoteMigrated['groceryChecklistItems'],
          ),
        );
        await save(remoteData, pushRemote: false);
        await prefs.remove(_legacyFoodNamesKey);
        return remoteData;
      } on FormatException {
        // Ignore malformed cloud payload and keep the local cache.
      }
    }

    if (needsWriteBack || initialVersion != FoodDataMigrator.currentVersion) {
      await save(data);
      await prefs.remove(_legacyFoodNamesKey);
    }

    return data;
  }

  Future<void> save(FamilyEatingData data, {bool pushRemote = true}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = _payloadFromData(data);
    final String encodedPayload = jsonEncode(payload);
    await prefs.setString(_dataKey, encodedPayload);
    if (await _backupPreferences.loadAutomaticBackupsEnabled()) {
      await _backupService.saveAutomaticBackup(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
    }
    if (pushRemote) {
      await AppCloudSync.instance.pushLatestSnapshot(payload);
    }
  }

  String exportAsJsonString(FamilyEatingData data) {
    return const JsonEncoder.withIndent('  ').convert(_payloadFromData(data));
  }

  Future<FamilyEatingData> importFromJsonString(
    String rawPayload, {
    bool pushRemote = true,
  }) async {
    final dynamic decoded = _tryDecodeJson(rawPayload);

    Map<String, dynamic> source;
    if (decoded is Map) {
      source = Map<String, dynamic>.from(decoded);
    } else if (decoded is List) {
      source = <String, dynamic>{'schemaVersion': 1, 'foodItems': decoded};
    } else {
      throw const FormatException('Invalid JSON payload.');
    }

    final Map<String, dynamic> migrated = _migrator.migrate(source);
    final FamilyEatingData data = FamilyEatingData(
      foodItems: _decodeFoodItems(migrated['foodItems']),
      routineItems: _decodeRoutineItems(migrated['routineItems']),
      weekPlans: _decodeWeekPlans(
        migrated['weekPlans'] ?? migrated['weekPlan'],
      ),
      groceryChecklistItems: _decodeGroceryChecklistItems(
        migrated['groceryChecklistItems'],
      ),
    );
    await save(data, pushRemote: pushRemote);
    return data;
  }

  Future<bool> loadAutomaticBackupsEnabled() {
    return _backupPreferences.loadAutomaticBackupsEnabled();
  }

  Future<void> saveAutomaticBackupsEnabled(bool enabled) {
    return _backupPreferences.saveAutomaticBackupsEnabled(enabled);
  }

  Future<void> saveAutomaticBackupNow(FamilyEatingData data) {
    return _backupService.saveAutomaticBackup(
      exportAsJsonString(data),
      force: true,
    );
  }

  Future<List<FoodBackupEntry>> listAutomaticBackups() {
    return _backupService.listBackups();
  }

  Future<FamilyEatingData> restoreAutomaticBackup(String backupId) async {
    final String backupJson = await _backupService.readBackup(backupId);
    final FamilyEatingData data = await importFromJsonString(
      backupJson,
      pushRemote: false,
    );
    if (await _backupPreferences.loadAutomaticBackupsEnabled()) {
      await saveAutomaticBackupNow(data);
    }
    return data;
  }

  Future<void> _clearStoredData(SharedPreferences prefs) async {
    await prefs.remove(_dataKey);
    await prefs.remove(_legacyFoodNamesKey);
  }

  Map<String, dynamic> _payloadFromData(FamilyEatingData data) {
    return <String, dynamic>{
      'schemaVersion': FoodDataMigrator.currentVersion,
      'foodItems': data.foodItems
          .map((FoodItem item) => item.toJson())
          .toList(),
      'routineItems': data.routineItems
          .map((RoutineFoodItem item) => item.toJson())
          .toList(),
      'weekPlans': data.weekPlans
          .map((WeekPlan plan) => plan.toJson())
          .toList(),
      'groceryChecklistItems': data.groceryChecklistItems
          .map((GroceryChecklistItem item) => item.toJson())
          .toList(),
    };
  }

  dynamic _tryDecodeJson(String rawPayload) {
    try {
      return jsonDecode(rawPayload);
    } on FormatException {
      return null;
    }
  }

  int _readVersion(Map<String, dynamic> source) {
    final dynamic versionValue = source['schemaVersion'];
    if (versionValue is num) {
      return versionValue.toInt();
    }
    return 1;
  }

  List<FoodItem> _decodeFoodItems(dynamic rawItems) {
    if (rawItems is! List) {
      return <FoodItem>[];
    }
    return rawItems
        .map<FoodItem>((dynamic item) {
          if (item is Map) {
            return FoodItem.fromJson(Map<String, dynamic>.from(item));
          }
          return FoodItem(name: '$item', proteins: const <ProteinType>[]);
        })
        .where((FoodItem item) => item.name.trim().isNotEmpty)
        .toList();
  }

  List<RoutineFoodItem> _decodeRoutineItems(dynamic rawItems) {
    if (rawItems is! List) {
      return <RoutineFoodItem>[];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (Map item) =>
              RoutineFoodItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((RoutineFoodItem item) => item.ingredient.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<WeekPlan> _decodeWeekPlans(dynamic rawValue) {
    if (rawValue is Map) {
      final WeekPlan decoded = WeekPlan.fromJson(
        Map<String, dynamic>.from(rawValue),
      );
      return decoded.isEmpty || decoded.weekStart.isEmpty
          ? <WeekPlan>[]
          : <WeekPlan>[decoded];
    }
    if (rawValue is! List) {
      return <WeekPlan>[];
    }
    final List<WeekPlan> plans = rawValue
        .whereType<Map>()
        .map((Map item) => WeekPlan.fromJson(Map<String, dynamic>.from(item)))
        .where((WeekPlan plan) => plan.weekStart.isNotEmpty && !plan.isEmpty)
        .toList(growable: false);
    final List<WeekPlan> sorted = List<WeekPlan>.from(plans)
      ..sort((WeekPlan a, WeekPlan b) => a.weekStart.compareTo(b.weekStart));
    return sorted;
  }

  List<GroceryChecklistItem> _decodeGroceryChecklistItems(dynamic rawItems) {
    if (rawItems is! List) {
      return <GroceryChecklistItem>[];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (Map item) =>
              GroceryChecklistItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((GroceryChecklistItem item) => item.label.isNotEmpty)
        .toList(growable: false);
  }
}
