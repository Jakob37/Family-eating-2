import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family eating',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Family eating'),
    );
  }
}

class FoodItem {
  const FoodItem({
    required this.name,
    required this.proteins,
    this.ingredients = const <String>[],
    this.cookingLogs = const <CookingLog>[],
  });

  final String name;
  final List<ProteinType> proteins;
  final List<String> ingredients;
  final List<CookingLog> cookingLogs;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final String name = (json['name'] ?? '').toString().trim();
    final dynamic rawProteins = json['proteins'];
    final List<ProteinType> proteins = rawProteins is List
        ? rawProteins
              .map((dynamic value) => ProteinType.fromStorageValue('$value'))
              .whereType<ProteinType>()
              .toList(growable: false)
        : <ProteinType>[];
    final dynamic rawIngredients = json['ingredients'];
    final List<String> ingredients = rawIngredients is List
        ? rawIngredients
              .map((dynamic value) => '$value'.trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false)
        : <String>[];

    final dynamic rawCookingLogs = json['cookingLogs'];
    final List<CookingLog> cookingLogs = rawCookingLogs is List
        ? rawCookingLogs
              .map((dynamic entry) {
                if (entry is Map) {
                  return CookingLog.fromJson(Map<String, dynamic>.from(entry));
                }
                return null;
              })
              .whereType<CookingLog>()
              .toList(growable: false)
        : _placeholderCookingLogsFromLegacyCount(json['cookedCount']);

    return FoodItem(
      name: name,
      proteins: proteins,
      ingredients: ingredients,
      cookingLogs: cookingLogs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'proteins': proteins
          .map((ProteinType protein) => protein.storageValue)
          .toList(growable: false),
      'ingredients': ingredients,
      'cookingLogs': cookingLogs
          .map((CookingLog log) => log.toJson())
          .toList(growable: false),
    };
  }

  int get cookedCount => cookingLogs.length;

  double? get averageRating {
    final List<double> ratings = cookingLogs
        .map((CookingLog log) => log.rating)
        .whereType<double>()
        .toList(growable: false);
    if (ratings.isEmpty) {
      return null;
    }
    final double total = ratings.fold<double>(0, (double sum, double value) {
      return sum + value;
    });
    return total / ratings.length;
  }

  double? get averageDurationMinutes {
    final List<int> durations = cookingLogs
        .map((CookingLog log) => log.durationMinutes)
        .whereType<int>()
        .toList(growable: false);
    if (durations.isEmpty) {
      return null;
    }
    final int total = durations.fold<int>(0, (int sum, int value) {
      return sum + value;
    });
    return total / durations.length;
  }

  FoodItem copyWith({
    String? name,
    List<ProteinType>? proteins,
    List<String>? ingredients,
    List<CookingLog>? cookingLogs,
  }) {
    return FoodItem(
      name: name ?? this.name,
      proteins: proteins ?? this.proteins,
      ingredients: ingredients ?? this.ingredients,
      cookingLogs: cookingLogs ?? this.cookingLogs,
    );
  }

  static List<CookingLog> _placeholderCookingLogsFromLegacyCount(
    dynamic rawCookedCount,
  ) {
    final int parsedCount = rawCookedCount is num
        ? rawCookedCount.toInt()
        : int.tryParse('$rawCookedCount') ?? 0;
    final int count = parsedCount < 0 ? 0 : parsedCount;
    return List<CookingLog>.generate(
      count,
      (int index) => CookingLog(
        cookedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      growable: false,
    );
  }
}

class CookingLog {
  const CookingLog({required this.cookedAt, this.rating, this.durationMinutes});

  final DateTime cookedAt;
  final double? rating;
  final int? durationMinutes;

  factory CookingLog.fromJson(Map<String, dynamic> json) {
    final DateTime cookedAt = _parseCookedAt(json['cookedAt']);
    final double? rating = _parseRating(json['rating']);
    final int? durationMinutes = _parseDuration(json['durationMinutes']);
    return CookingLog(
      cookedAt: cookedAt,
      rating: rating,
      durationMinutes: durationMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cookedAt': cookedAt.toUtc().toIso8601String(),
      'rating': rating,
      'durationMinutes': durationMinutes,
    };
  }

  static DateTime _parseCookedAt(dynamic rawCookedAt) {
    final DateTime? parsed = DateTime.tryParse('$rawCookedAt');
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return parsed.toUtc();
  }

  static double? _parseRating(dynamic rawRating) {
    if (rawRating == null) {
      return null;
    }
    final double? parsed = rawRating is num
        ? rawRating.toDouble()
        : double.tryParse('$rawRating');
    if (parsed == null) {
      return null;
    }
    final double clamped = parsed.clamp(0, 5).toDouble();
    return (clamped * 2).round() / 2;
  }

  static int? _parseDuration(dynamic rawDuration) {
    if (rawDuration == null) {
      return null;
    }
    final int? parsed = rawDuration is num
        ? rawDuration.toInt()
        : int.tryParse('$rawDuration');
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }
}

enum DishMenuAction { cooked, edit }

class DishEditorResult {
  const DishEditorResult({
    required this.name,
    required this.proteins,
    required this.ingredients,
  });

  final String name;
  final List<ProteinType> proteins;
  final List<String> ingredients;
}

class DishFilter {
  const DishFilter({
    this.selectedProteins = const <ProteinType>{},
    this.minRating = 0,
    this.minCookingTimeMinutes,
    this.maxCookingTimeMinutes,
  });

  static const DishFilter empty = DishFilter();

  final Set<ProteinType> selectedProteins;
  final double minRating;
  final int? minCookingTimeMinutes;
  final int? maxCookingTimeMinutes;

  bool get hasActiveFilters {
    return selectedProteins.isNotEmpty ||
        minRating > 0 ||
        minCookingTimeMinutes != null ||
        maxCookingTimeMinutes != null;
  }

  DishFilter copyWith({
    Set<ProteinType>? selectedProteins,
    double? minRating,
    int? minCookingTimeMinutes,
    int? maxCookingTimeMinutes,
  }) {
    return DishFilter(
      selectedProteins: selectedProteins ?? this.selectedProteins,
      minRating: minRating ?? this.minRating,
      minCookingTimeMinutes:
          minCookingTimeMinutes ?? this.minCookingTimeMinutes,
      maxCookingTimeMinutes:
          maxCookingTimeMinutes ?? this.maxCookingTimeMinutes,
    );
  }
}

enum ProteinType {
  chicken('chicken', 'Chicken', FontAwesomeIcons.drumstickBite),
  tofu('tofu', 'Tofu', FontAwesomeIcons.cube),
  egg('egg', 'Egg', FontAwesomeIcons.egg),
  meat('meat', 'Meat', FontAwesomeIcons.bacon),
  fish('fish', 'Fish', FontAwesomeIcons.fish),
  beans('beans', 'Beans', FontAwesomeIcons.seedling),
  lentils('lentils', 'Lentils', FontAwesomeIcons.leaf),
  cheese('cheese', 'Cheese', FontAwesomeIcons.cheese);

  const ProteinType(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  static ProteinType? fromStorageValue(String value) {
    final String normalized = value.trim().toLowerCase();
    for (final ProteinType protein in ProteinType.values) {
      if (protein.storageValue == normalized ||
          protein.label.toLowerCase() == normalized) {
        return protein;
      }
    }
    return null;
  }
}

class FoodDataMigrator {
  static const int currentVersion = 5;

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

  Future<List<FoodItem>> load() async {
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
        return <FoodItem>[];
      }
    } else {
      final List<String>? legacyFoodNames = prefs.getStringList(
        _legacyFoodNamesKey,
      );
      if (legacyFoodNames == null) {
        return <FoodItem>[];
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
      return <FoodItem>[];
    }
    final List<FoodItem> items = _decodeFoodItems(migrated['foodItems']);

    if (needsWriteBack || initialVersion != FoodDataMigrator.currentVersion) {
      await save(items);
      await prefs.remove(_legacyFoodNamesKey);
    }

    return items;
  }

  Future<void> save(List<FoodItem> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': FoodDataMigrator.currentVersion,
      'foodItems': items.map((FoodItem item) => item.toJson()).toList(),
    };
    await prefs.setString(_dataKey, jsonEncode(payload));
  }

  Future<void> _clearStoredData(SharedPreferences prefs) async {
    await prefs.remove(_dataKey);
    await prefs.remove(_legacyFoodNamesKey);
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
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FoodDataStore _dataStore = FoodDataStore();
  final List<FoodItem> _foodItems = <FoodItem>[];

  bool _isLoading = true;
  String? _loadError;
  DishFilter _activeFilter = DishFilter.empty;

  int _compareByRanking(FoodItem a, FoodItem b) {
    final int cookedCompare = b.cookedCount.compareTo(a.cookedCount);
    if (cookedCompare != 0) {
      return cookedCompare;
    }
    final double ratingA = a.averageRating ?? -1;
    final double ratingB = b.averageRating ?? -1;
    final int ratingCompare = ratingB.compareTo(ratingA);
    if (ratingCompare != 0) {
      return ratingCompare;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _sortFoodItemsByRanking() {
    _foodItems.sort(_compareByRanking);
  }

  String _cookedCountText(int cookedCount) {
    if (cookedCount == 1) {
      return 'Cooked 1 time';
    }
    return 'Cooked $cookedCount times';
  }

  String _formatRating(double rating) {
    return rating.toStringAsFixed(1);
  }

  String _averageRatingText(FoodItem item) {
    final double? averageRating = item.averageRating;
    if (averageRating == null) {
      return 'No ratings yet';
    }
    return 'Avg rating: ${_formatRating(averageRating)}/5';
  }

  String _averageDurationText(FoodItem item) {
    final double? averageDuration = item.averageDurationMinutes;
    if (averageDuration == null) {
      return 'No cooking time logged';
    }
    return 'Avg time: ${averageDuration.toStringAsFixed(1)} min';
  }

  List<Widget> _buildStarPreview(double rating) {
    return List<Widget>.generate(5, (int index) {
      final double threshold = index + 1;
      if (rating >= threshold) {
        return const Icon(Icons.star, size: 20, color: Colors.amber);
      }
      if (rating >= threshold - 0.5) {
        return const Icon(Icons.star_half, size: 20, color: Colors.amber);
      }
      return const Icon(Icons.star_border, size: 20, color: Colors.amber);
    });
  }

  List<FoodItem> _filteredFoodItems() {
    return _foodItems
        .where((FoodItem item) => _matchesActiveFilter(item))
        .toList(growable: false);
  }

  bool _matchesActiveFilter(FoodItem item) {
    if (_activeFilter.selectedProteins.isNotEmpty) {
      final bool hasProteinMatch = item.proteins.any(
        _activeFilter.selectedProteins.contains,
      );
      if (!hasProteinMatch) {
        return false;
      }
    }

    if (_activeFilter.minRating > 0) {
      final double? averageRating = item.averageRating;
      if (averageRating == null || averageRating < _activeFilter.minRating) {
        return false;
      }
    }

    if (_activeFilter.minCookingTimeMinutes != null) {
      final double? averageDuration = item.averageDurationMinutes;
      if (averageDuration == null ||
          averageDuration < _activeFilter.minCookingTimeMinutes!) {
        return false;
      }
    }

    if (_activeFilter.maxCookingTimeMinutes != null) {
      final double? averageDuration = item.averageDurationMinutes;
      if (averageDuration == null ||
          averageDuration > _activeFilter.maxCookingTimeMinutes!) {
        return false;
      }
    }

    return true;
  }

  Future<void> _openFilterMenu() async {
    Set<ProteinType> selectedProteins = Set<ProteinType>.from(
      _activeFilter.selectedProteins,
    );
    double minRating = _activeFilter.minRating;
    String minTimeInput = _activeFilter.minCookingTimeMinutes?.toString() ?? '';
    String maxTimeInput = _activeFilter.maxCookingTimeMinutes?.toString() ?? '';
    String? minTimeError;
    String? maxTimeError;

    final DishFilter? nextFilter = await showDialog<DishFilter>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Filter dishes'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Only include proteins'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ProteinType.values
                            .map((ProteinType protein) {
                              return FilterChip(
                                selected: selectedProteins.contains(protein),
                                avatar: FaIcon(protein.icon, size: 14),
                                label: Text(protein.label),
                                onSelected: (bool isSelected) {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedProteins.add(protein);
                                    } else {
                                      selectedProteins.remove(protein);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<double>(
                        key: const ValueKey<String>('min_rating_dropdown'),
                        initialValue: minRating,
                        decoration: const InputDecoration(
                          labelText: 'Minimum average rating',
                        ),
                        items: List<DropdownMenuItem<double>>.generate(11, (
                          int index,
                        ) {
                          final double value = index / 2;
                          return DropdownMenuItem<double>(
                            value: value,
                            child: Text(
                              value == 0
                                  ? 'No minimum'
                                  : '${value.toStringAsFixed(1)}+',
                            ),
                          );
                        }, growable: false),
                        onChanged: (double? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            minRating = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey<String>('min_time_field'),
                        keyboardType: TextInputType.number,
                        initialValue: minTimeInput,
                        decoration: InputDecoration(
                          labelText: 'Minimum avg time (minutes)',
                          errorText: minTimeError,
                        ),
                        onChanged: (String value) {
                          minTimeInput = value;
                          if (minTimeError != null) {
                            setDialogState(() {
                              minTimeError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey<String>('max_time_field'),
                        keyboardType: TextInputType.number,
                        initialValue: maxTimeInput,
                        decoration: InputDecoration(
                          labelText: 'Maximum avg time (minutes)',
                          errorText: maxTimeError,
                        ),
                        onChanged: (String value) {
                          maxTimeInput = value;
                          if (maxTimeError != null) {
                            setDialogState(() {
                              maxTimeError = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(DishFilter.empty),
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final int? minMinutes = _parseOptionalMinutes(minTimeInput);
                    final int? maxMinutes = _parseOptionalMinutes(maxTimeInput);

                    setDialogState(() {
                      minTimeError =
                          minTimeInput.trim().isEmpty || minMinutes != null
                          ? null
                          : 'Enter 0 or more';
                      maxTimeError =
                          maxTimeInput.trim().isEmpty || maxMinutes != null
                          ? null
                          : 'Enter 0 or more';
                      if (minMinutes != null &&
                          maxMinutes != null &&
                          minMinutes > maxMinutes) {
                        maxTimeError = 'Must be >= minimum';
                      }
                    });

                    if (minTimeError != null || maxTimeError != null) {
                      return;
                    }

                    Navigator.of(context).pop(
                      DishFilter(
                        selectedProteins: Set<ProteinType>.from(
                          selectedProteins,
                        ),
                        minRating: minRating,
                        minCookingTimeMinutes: minMinutes,
                        maxCookingTimeMinutes: maxMinutes,
                      ),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nextFilter == null || !mounted) {
      return;
    }

    setState(() {
      _activeFilter = nextFilter;
    });
  }

  int? _parseOptionalMinutes(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  List<String> _parseIngredients(String rawValue) {
    final Iterable<String> entries = rawValue
        .split(RegExp(r'[\n,]'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty);
    final Set<String> seen = <String>{};
    final List<String> result = <String>[];
    for (final String entry in entries) {
      final String normalized = entry.toLowerCase();
      if (seen.add(normalized)) {
        result.add(entry);
      }
    }
    return result;
  }

  List<Widget> _buildActiveFilterChips() {
    final List<Widget> chips = <Widget>[];
    if (_activeFilter.selectedProteins.isNotEmpty) {
      final String proteins = _activeFilter.selectedProteins
          .map((ProteinType protein) => protein.label)
          .join(', ');
      chips.add(Chip(label: Text('Proteins: $proteins')));
    }
    if (_activeFilter.minRating > 0) {
      chips.add(
        Chip(
          label: Text(
            'Min rating: ${_activeFilter.minRating.toStringAsFixed(1)}',
          ),
        ),
      );
    }
    if (_activeFilter.minCookingTimeMinutes != null) {
      chips.add(
        Chip(
          label: Text('Min time: ${_activeFilter.minCookingTimeMinutes} min'),
        ),
      );
    }
    if (_activeFilter.maxCookingTimeMinutes != null) {
      chips.add(
        Chip(
          label: Text('Max time: ${_activeFilter.maxCookingTimeMinutes} min'),
        ),
      );
    }
    return chips;
  }

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    try {
      final List<FoodItem> loadedItems = await _dataStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _foodItems
          ..clear()
          ..addAll(loadedItems);
        _sortFoodItemsByRanking();
        _isLoading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load saved food items.';
      });
    }
  }

  Future<void> _persistFoodItems() async {
    try {
      await _dataStore.save(_foodItems);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save changes.')));
    }
  }

  Future<DishEditorResult?> _showDishEditorDialog({
    required String title,
    required String saveLabel,
    required String initialName,
    required List<ProteinType> initialProteins,
    required List<String> initialIngredients,
  }) async {
    String draftName = initialName;
    final Set<ProteinType> selectedProteins = Set<ProteinType>.from(
      initialProteins,
    );
    String ingredientsInput = initialIngredients.join('\n');

    return showDialog<DishEditorResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final bool canAdd =
                draftName.trim().isNotEmpty && selectedProteins.isNotEmpty;

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        key: const ValueKey<String>('dish_name_field'),
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        initialValue: draftName,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Pasta',
                          labelText: 'Food',
                        ),
                        onChanged: (String changedValue) {
                          setDialogState(() {
                            draftName = changedValue;
                          });
                        },
                        onFieldSubmitted: (_) {
                          if (!canAdd) {
                            return;
                          }
                          Navigator.of(context).pop(
                            DishEditorResult(
                              name: draftName.trim(),
                              proteins: ProteinType.values
                                  .where(selectedProteins.contains)
                                  .toList(growable: false),
                              ingredients: _parseIngredients(ingredientsInput),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Protein types'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ProteinType.values
                            .map((ProteinType protein) {
                              return FilterChip(
                                selected: selectedProteins.contains(protein),
                                avatar: FaIcon(protein.icon, size: 14),
                                label: Text(protein.label),
                                onSelected: (bool isSelected) {
                                  setDialogState(() {
                                    if (isSelected) {
                                      selectedProteins.add(protein);
                                    } else {
                                      selectedProteins.remove(protein);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey<String>('ingredients_field'),
                        initialValue: ingredientsInput,
                        minLines: 2,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Ingredients',
                          hintText:
                              'One per line or comma separated, e.g. tomato',
                        ),
                        onChanged: (String value) {
                          ingredientsInput = value;
                        },
                      ),
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
                  onPressed: !canAdd
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            DishEditorResult(
                              name: draftName.trim(),
                              proteins: ProteinType.values
                                  .where(selectedProteins.contains)
                                  .toList(growable: false),
                              ingredients: _parseIngredients(ingredientsInput),
                            ),
                          );
                        },
                  child: Text(saveLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addFoodItem() async {
    final DishEditorResult? value = await _showDishEditorDialog(
      title: 'Add food item',
      saveLabel: 'Add',
      initialName: '',
      initialProteins: const <ProteinType>[],
      initialIngredients: const <String>[],
    );

    if (value == null) {
      return;
    }

    setState(() {
      _foodItems.add(
        FoodItem(
          name: value.name,
          proteins: value.proteins,
          ingredients: value.ingredients,
        ),
      );
      _sortFoodItemsByRanking();
    });
    await _persistFoodItems();
  }

  Future<void> _editDish(FoodItem item) async {
    final int itemIndex = _foodItems.indexOf(item);
    if (itemIndex == -1) {
      return;
    }

    final DishEditorResult? edited = await _showDishEditorDialog(
      title: 'Edit dish',
      saveLabel: 'Save',
      initialName: item.name,
      initialProteins: item.proteins,
      initialIngredients: item.ingredients,
    );
    if (edited == null) {
      return;
    }

    setState(() {
      final FoodItem existingItem = _foodItems[itemIndex];
      _foodItems[itemIndex] = existingItem.copyWith(
        name: edited.name,
        proteins: edited.proteins,
        ingredients: edited.ingredients,
      );
      _sortFoodItemsByRanking();
    });
    await _persistFoodItems();
  }

  Future<void> _openDishContextMenu(FoodItem item) async {
    final DishMenuAction? action = await showModalBottomSheet<DishMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('I cooked this'),
                onTap: () => Navigator.of(context).pop(DishMenuAction.cooked),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit dish'),
                onTap: () => Navigator.of(context).pop(DishMenuAction.edit),
              ),
            ],
          ),
        );
      },
    );

    if (action == DishMenuAction.edit) {
      await _editDish(item);
      return;
    }

    if (action != DishMenuAction.cooked) {
      return;
    }

    final CookingLog? cookingLog = await _showCookingLogDialog();
    if (cookingLog == null) {
      return;
    }

    final int itemIndex = _foodItems.indexOf(item);
    if (itemIndex == -1) {
      return;
    }

    setState(() {
      final FoodItem selectedItem = _foodItems[itemIndex];
      final List<CookingLog> updatedLogs = List<CookingLog>.from(
        selectedItem.cookingLogs,
      )..add(cookingLog);
      _foodItems[itemIndex] = selectedItem.copyWith(cookingLogs: updatedLogs);
      _sortFoodItemsByRanking();
    });
    await _persistFoodItems();
  }

  Future<CookingLog?> _showCookingLogDialog() async {
    double rating = 3.0;
    String durationInput = '';
    String? durationError;

    return showDialog<CookingLog>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Log cooking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Rating: ${_formatRating(rating)} / 5'),
                  const SizedBox(height: 4),
                  Row(children: _buildStarPreview(rating)),
                  Slider(
                    value: rating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _formatRating(rating),
                    onChanged: (double value) {
                      setDialogState(() {
                        rating = value;
                      });
                    },
                  ),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Time in minutes (optional)',
                      errorText: durationError,
                    ),
                    onChanged: (String value) {
                      setDialogState(() {
                        durationInput = value;
                        durationError = null;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String normalizedDuration = durationInput.trim();
                    int? parsedDuration;
                    if (normalizedDuration.isNotEmpty) {
                      parsedDuration = int.tryParse(normalizedDuration);
                      if (parsedDuration == null || parsedDuration <= 0) {
                        setDialogState(() {
                          durationError = 'Enter a whole number above 0';
                        });
                        return;
                      }
                    }

                    Navigator.of(context).pop(
                      CookingLog(
                        cookedAt: DateTime.now().toUtc(),
                        rating: rating,
                        durationMinutes: parsedDuration,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_loadError!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _loadFoodItems();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_foodItems.isEmpty) {
      body = const Center(child: Text('No food items yet. Tap + to add one.'));
    } else {
      final List<FoodItem> visibleFoodItems = _filteredFoodItems();
      if (visibleFoodItems.isEmpty) {
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('No dishes match current filters.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _activeFilter = DishFilter.empty;
                  });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        );
      } else {
        body = Column(
          children: <Widget>[
            if (_activeFilter.hasActiveFilters)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    ..._buildActiveFilterChips(),
                    ActionChip(
                      label: const Text('Clear'),
                      onPressed: () {
                        setState(() {
                          _activeFilter = DishFilter.empty;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: visibleFoodItems.length,
                itemBuilder: (BuildContext context, int index) {
                  final FoodItem item = visibleFoodItems[index];
                  final ProteinType? primaryProtein = item.proteins.isEmpty
                      ? null
                      : item.proteins.first;

                  return Card(
                    key: ValueKey<String>('dish_card_${item.name}'),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      onTap: () => _openDishContextMenu(item),
                      leading: CircleAvatar(
                        child: primaryProtein == null
                            ? const Icon(Icons.restaurant_menu, size: 18)
                            : FaIcon(primaryProtein.icon, size: 16),
                      ),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(height: 4),
                          Text(_cookedCountText(item.cookedCount)),
                          const SizedBox(height: 4),
                          Text(_averageRatingText(item)),
                          const SizedBox(height: 2),
                          Text(_averageDurationText(item)),
                          const SizedBox(height: 2),
                          if (item.ingredients.isEmpty)
                            const Text('No ingredients listed')
                          else
                            Text('Ingredients: ${item.ingredients.join(', ')}'),
                          const SizedBox(height: 8),
                          if (item.proteins.isEmpty)
                            const Text('No proteins selected')
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: item.proteins
                                  .map((ProteinType proteinType) {
                                    return Chip(
                                      avatar: FaIcon(
                                        proteinType.icon,
                                        size: 12,
                                      ),
                                      label: Text(proteinType.label),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                        ],
                      ),
                      trailing: Text(
                        '#${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filter dishes',
            icon: Icon(
              _activeFilter.hasActiveFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: _isLoading || _loadError != null
                ? null
                : _openFilterMenu,
          ),
        ],
      ),
      body: body,
      floatingActionButton: _isLoading || _loadError != null
          ? null
          : FloatingActionButton(
              onPressed: _addFoodItem,
              tooltip: 'Add food item',
              child: const Icon(Icons.add),
            ),
    );
  }
}
