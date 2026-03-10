import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_window.dart';

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
      initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case GroceryTripPage.routeName:
            return MaterialPageRoute<void>(
              builder: (BuildContext context) => const GroceryTripPage(),
              settings: settings,
            );
          case '/':
          default:
            return MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  const MyHomePage(title: 'Family eating'),
              settings: settings,
            );
        }
      },
    );
  }
}

class FoodItem {
  const FoodItem({
    required this.name,
    required this.proteins,
    this.ingredients = const <String>[],
    this.cookingLogs = const <CookingLog>[],
    this.defaultPortions = 4,
  });

  final String name;
  final List<ProteinType> proteins;
  final List<String> ingredients;
  final List<CookingLog> cookingLogs;
  final int defaultPortions;

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
      defaultPortions: _parseDefaultPortions(json['defaultPortions']),
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
      'defaultPortions': defaultPortions,
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
    int? defaultPortions,
  }) {
    return FoodItem(
      name: name ?? this.name,
      proteins: proteins ?? this.proteins,
      ingredients: ingredients ?? this.ingredients,
      cookingLogs: cookingLogs ?? this.cookingLogs,
      defaultPortions: defaultPortions ?? this.defaultPortions,
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

  static int _parseDefaultPortions(dynamic rawValue) {
    final int parsed = rawValue is num
        ? rawValue.toInt()
        : int.tryParse('$rawValue') ?? 4;
    return parsed > 0 ? parsed : 4;
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
    required this.defaultPortions,
  });

  final String name;
  final List<ProteinType> proteins;
  final List<String> ingredients;
  final int defaultPortions;
}

class GroceryTripDishSelection {
  const GroceryTripDishSelection({required this.item, required this.portions});

  final FoodItem item;
  final int portions;

  GroceryTripDishSelection copyWith({FoodItem? item, int? portions}) {
    return GroceryTripDishSelection(
      item: item ?? this.item,
      portions: portions ?? this.portions,
    );
  }
}

class GroceryListItem {
  const GroceryListItem({required this.label, this.normalizedKey});

  final String label;
  final String? normalizedKey;
}

enum _IngredientUnitGroup { weight, volume, spoon, countLike }

class _IngredientUnit {
  const _IngredientUnit({
    required this.key,
    required this.group,
    required this.factorToBase,
    required this.singularLabel,
    required this.pluralLabel,
    required this.aliases,
    this.attachToAmount = false,
  });

  final String key;
  final _IngredientUnitGroup group;
  final double factorToBase;
  final String singularLabel;
  final String pluralLabel;
  final List<String> aliases;
  final bool attachToAmount;

  static const List<_IngredientUnit> values = <_IngredientUnit>[
    _IngredientUnit(
      key: 'g',
      group: _IngredientUnitGroup.weight,
      factorToBase: 1,
      singularLabel: 'g',
      pluralLabel: 'g',
      aliases: <String>['g', 'gram', 'grams'],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'kg',
      group: _IngredientUnitGroup.weight,
      factorToBase: 1000,
      singularLabel: 'kg',
      pluralLabel: 'kg',
      aliases: <String>['kg', 'kgs', 'kilo', 'kilos', 'kilogram', 'kilograms'],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'ml',
      group: _IngredientUnitGroup.volume,
      factorToBase: 1,
      singularLabel: 'ml',
      pluralLabel: 'ml',
      aliases: <String>[
        'ml',
        'milliliter',
        'milliliters',
        'millilitre',
        'millilitres',
      ],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'cl',
      group: _IngredientUnitGroup.volume,
      factorToBase: 10,
      singularLabel: 'cl',
      pluralLabel: 'cl',
      aliases: <String>[
        'cl',
        'centiliter',
        'centiliters',
        'centilitre',
        'centilitres',
      ],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'dl',
      group: _IngredientUnitGroup.volume,
      factorToBase: 100,
      singularLabel: 'dl',
      pluralLabel: 'dl',
      aliases: <String>[
        'dl',
        'deciliter',
        'deciliters',
        'decilitre',
        'decilitres',
      ],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'l',
      group: _IngredientUnitGroup.volume,
      factorToBase: 1000,
      singularLabel: 'l',
      pluralLabel: 'l',
      aliases: <String>['l', 'liter', 'liters', 'litre', 'litres'],
      attachToAmount: true,
    ),
    _IngredientUnit(
      key: 'tsp',
      group: _IngredientUnitGroup.spoon,
      factorToBase: 1,
      singularLabel: 'tsp',
      pluralLabel: 'tsp',
      aliases: <String>['tsp', 'tsp.', 'teaspoon', 'teaspoons'],
    ),
    _IngredientUnit(
      key: 'tbsp',
      group: _IngredientUnitGroup.spoon,
      factorToBase: 3,
      singularLabel: 'tbsp',
      pluralLabel: 'tbsp',
      aliases: <String>['tbsp', 'tbsp.', 'tablespoon', 'tablespoons'],
    ),
    _IngredientUnit(
      key: 'package',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'package',
      pluralLabel: 'packages',
      aliases: <String>[
        'package',
        'packages',
        'pack',
        'packs',
        'pkg',
        'pkgs',
        'packet',
        'packets',
      ],
    ),
    _IngredientUnit(
      key: 'bag',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'bag',
      pluralLabel: 'bags',
      aliases: <String>['bag', 'bags'],
    ),
    _IngredientUnit(
      key: 'bottle',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'bottle',
      pluralLabel: 'bottles',
      aliases: <String>['bottle', 'bottles'],
    ),
    _IngredientUnit(
      key: 'can',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'can',
      pluralLabel: 'cans',
      aliases: <String>['can', 'cans', 'tin', 'tins'],
    ),
    _IngredientUnit(
      key: 'jar',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'jar',
      pluralLabel: 'jars',
      aliases: <String>['jar', 'jars'],
    ),
    _IngredientUnit(
      key: 'piece',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'pc',
      pluralLabel: 'pcs',
      aliases: <String>['pc', 'pcs', 'piece', 'pieces'],
    ),
    _IngredientUnit(
      key: 'clove',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'clove',
      pluralLabel: 'cloves',
      aliases: <String>['clove', 'cloves'],
    ),
    _IngredientUnit(
      key: 'slice',
      group: _IngredientUnitGroup.countLike,
      factorToBase: 1,
      singularLabel: 'slice',
      pluralLabel: 'slices',
      aliases: <String>['slice', 'slices'],
    ),
  ];

  static final Map<String, _IngredientUnit> _byAlias =
      <String, _IngredientUnit>{
        for (final _IngredientUnit unit in values)
          for (final String alias in unit.aliases) _normalizeToken(alias): unit,
      };

  static _IngredientUnit? fromToken(String token) {
    return _byAlias[_normalizeToken(token)];
  }

  static String _normalizeToken(String token) {
    return token.trim().toLowerCase().replaceAll(RegExp(r'[.,]$'), '');
  }
}

class _ParsedIngredient {
  const _ParsedIngredient({
    required this.baseAmount,
    required this.displayName,
    required this.normalizedName,
    this.unit,
  });

  final double baseAmount;
  final String displayName;
  final String normalizedName;
  final _IngredientUnit? unit;

  String get normalizedKey {
    final String prefix = switch (unit?.group) {
      _IngredientUnitGroup.weight => 'weight',
      _IngredientUnitGroup.volume => 'volume',
      _IngredientUnitGroup.spoon => 'spoon',
      _IngredientUnitGroup.countLike => unit!.key,
      null => 'count',
    };
    return '$prefix|$normalizedName';
  }

  String formatWithAmount(double totalBaseAmount) {
    if (unit == null) {
      final String noun = _isSingular(totalBaseAmount)
          ? normalizedName
          : _pluralizePhrase(normalizedName);
      return '${_formatScaledAmount(totalBaseAmount)} $noun';
    }

    switch (unit!.group) {
      case _IngredientUnitGroup.weight:
        return _formatWithUnit(
          displayUnit: totalBaseAmount >= 1000
              ? _IngredientUnit.values.firstWhere(
                  (_IngredientUnit candidate) => candidate.key == 'kg',
                )
              : _IngredientUnit.values.firstWhere(
                  (_IngredientUnit candidate) => candidate.key == 'g',
                ),
          amount: totalBaseAmount >= 1000
              ? totalBaseAmount / 1000
              : totalBaseAmount,
          name: displayName,
        );
      case _IngredientUnitGroup.volume:
        if (totalBaseAmount >= 1000) {
          return _formatWithUnit(
            displayUnit: _IngredientUnit.values.firstWhere(
              (_IngredientUnit candidate) => candidate.key == 'l',
            ),
            amount: totalBaseAmount / 1000,
            name: displayName,
          );
        }
        if (totalBaseAmount >= 100 && _isNearHalf(totalBaseAmount / 100)) {
          return _formatWithUnit(
            displayUnit: _IngredientUnit.values.firstWhere(
              (_IngredientUnit candidate) => candidate.key == 'dl',
            ),
            amount: totalBaseAmount / 100,
            name: displayName,
          );
        }
        return _formatWithUnit(
          displayUnit: _IngredientUnit.values.firstWhere(
            (_IngredientUnit candidate) => candidate.key == 'ml',
          ),
          amount: totalBaseAmount,
          name: displayName,
        );
      case _IngredientUnitGroup.spoon:
        final double tablespoons = totalBaseAmount / 3;
        if (totalBaseAmount >= 3 && _isNearHalf(tablespoons)) {
          return _formatWithUnit(
            displayUnit: _IngredientUnit.values.firstWhere(
              (_IngredientUnit candidate) => candidate.key == 'tbsp',
            ),
            amount: tablespoons,
            name: displayName,
          );
        }
        return _formatWithUnit(
          displayUnit: _IngredientUnit.values.firstWhere(
            (_IngredientUnit candidate) => candidate.key == 'tsp',
          ),
          amount: totalBaseAmount,
          name: displayName,
        );
      case _IngredientUnitGroup.countLike:
        return _formatWithUnit(
          displayUnit: unit!,
          amount: totalBaseAmount,
          name: displayName,
        );
    }
  }

  String _formatWithUnit({
    required _IngredientUnit displayUnit,
    required double amount,
    required String name,
  }) {
    final String formattedAmount = _formatScaledAmount(amount);
    final String unitLabel = _isSingular(amount)
        ? displayUnit.singularLabel
        : displayUnit.pluralLabel;
    if (displayUnit.attachToAmount) {
      return '$formattedAmount$unitLabel $name';
    }
    return '$formattedAmount $unitLabel $name';
  }

  static bool _isSingular(double value) => (value - 1).abs() < 0.0001;

  static bool _isNearHalf(double value) {
    final double rounded = (value * 2).roundToDouble() / 2;
    return (value - rounded).abs() < 0.0001;
  }

  static String _formatScaledAmount(double value) {
    final double rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0001) {
      return rounded.toInt().toString();
    }
    String text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }

  static String _pluralizePhrase(String value) {
    final List<String> words = value.split(' ');
    if (words.isEmpty) {
      return value;
    }
    final int lastWordIndex = words.lastIndexWhere((String word) {
      return word.trim().isNotEmpty;
    });
    if (lastWordIndex == -1) {
      return value;
    }
    words[lastWordIndex] = _pluralizeWord(words[lastWordIndex]);
    return words.join(' ');
  }

  static String singularizePhrase(String value) {
    final List<String> words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || value.trim().isEmpty) {
      return value.trim();
    }
    words[words.length - 1] = _singularizeWord(words.last);
    return words.join(' ');
  }

  static String _pluralizeWord(String value) {
    final String lower = value.toLowerCase();
    if (lower.endsWith('y') && lower.length > 1) {
      final String beforeY = lower[lower.length - 2];
      if (!'aeiou'.contains(beforeY)) {
        return '${lower.substring(0, lower.length - 1)}ies';
      }
    }
    if (lower.endsWith('o') && lower.length > 1) {
      final String beforeO = lower[lower.length - 2];
      if (!'aeiou'.contains(beforeO)) {
        return '${lower}es';
      }
    }
    if (lower.endsWith('s') ||
        lower.endsWith('x') ||
        lower.endsWith('z') ||
        lower.endsWith('ch') ||
        lower.endsWith('sh')) {
      return '${lower}es';
    }
    return '${lower}s';
  }

  static String _singularizeWord(String value) {
    final String lower = value.toLowerCase();
    if (lower.endsWith('ies') && lower.length > 3) {
      return '${lower.substring(0, lower.length - 3)}y';
    }
    if ((lower.endsWith('ches') ||
            lower.endsWith('shes') ||
            lower.endsWith('xes') ||
            lower.endsWith('zes') ||
            lower.endsWith('ses') ||
            lower.endsWith('oes')) &&
        lower.length > 2) {
      return lower.substring(0, lower.length - 2);
    }
    if (lower.endsWith('s') && !lower.endsWith('ss') && lower.length > 1) {
      return lower.substring(0, lower.length - 1);
    }
    return lower;
  }
}

class _IngredientAccumulator {
  _IngredientAccumulator(this.template) : totalAmount = 0;

  final _ParsedIngredient template;
  double totalAmount;
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
  static const int currentVersion = 6;

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

  int? _parsePositiveInt(String value) {
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
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

  Future<void> _openGroceryTrip() async {
    if (_isLoading || _loadError != null) {
      return;
    }

    if (openRouteInNewWindow(GroceryTripPage.routeName)) {
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(GroceryTripPage.routeName);
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
    required int initialDefaultPortions,
  }) async {
    String draftName = initialName;
    final Set<ProteinType> selectedProteins = Set<ProteinType>.from(
      initialProteins,
    );
    String ingredientsInput = initialIngredients.join('\n');
    String defaultPortionsInput = initialDefaultPortions.toString();
    String? defaultPortionsError;

    return showDialog<DishEditorResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final int? parsedDefaultPortions = _parsePositiveInt(
              defaultPortionsInput,
            );
            final bool canAdd =
                draftName.trim().isNotEmpty &&
                selectedProteins.isNotEmpty &&
                parsedDefaultPortions != null;

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
                              defaultPortions: parsedDefaultPortions,
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
                        key: const ValueKey<String>('default_portions_field'),
                        initialValue: defaultPortionsInput,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Recipe portions',
                          hintText: 'e.g. 4',
                          errorText: defaultPortionsError,
                        ),
                        onChanged: (String value) {
                          setDialogState(() {
                            defaultPortionsInput = value;
                            defaultPortionsError = null;
                          });
                        },
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
                          hintText: 'One per line, e.g. 500g minced meat',
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
                          final int? validatedPortions = _parsePositiveInt(
                            defaultPortionsInput,
                          );
                          if (validatedPortions == null) {
                            setDialogState(() {
                              defaultPortionsError =
                                  'Enter a whole number above 0';
                            });
                            return;
                          }
                          Navigator.of(context).pop(
                            DishEditorResult(
                              name: draftName.trim(),
                              proteins: ProteinType.values
                                  .where(selectedProteins.contains)
                                  .toList(growable: false),
                              ingredients: _parseIngredients(ingredientsInput),
                              defaultPortions: validatedPortions,
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
      initialDefaultPortions: 4,
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
          defaultPortions: value.defaultPortions,
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
      initialDefaultPortions: item.defaultPortions,
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
        defaultPortions: edited.defaultPortions,
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
      body = Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey<String>('open_grocery_trip_button'),
                onPressed: _openGroceryTrip,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Grocery trip'),
              ),
            ),
          ),
          const Expanded(
            child: Center(child: Text('No food items yet. Tap + to add one.')),
          ),
        ],
      );
    } else {
      final List<FoodItem> visibleFoodItems = _filteredFoodItems();
      if (visibleFoodItems.isEmpty) {
        body = Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('open_grocery_trip_button'),
                  onPressed: _openGroceryTrip,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Grocery trip'),
                ),
              ),
            ),
            Expanded(
              child: Center(
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
              ),
            ),
          ],
        );
      } else {
        body = Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('open_grocery_trip_button'),
                  onPressed: _openGroceryTrip,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Grocery trip'),
                ),
              ),
            ),
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
                          Text('Recipe portions: ${item.defaultPortions}'),
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

class GroceryTripPage extends StatefulWidget {
  const GroceryTripPage({super.key});

  static const String routeName = '/grocery-trip';

  @override
  State<GroceryTripPage> createState() => _GroceryTripPageState();
}

class _GroceryTripPageState extends State<GroceryTripPage> {
  final FoodDataStore _dataStore = FoodDataStore();
  final List<FoodItem> _foodItems = <FoodItem>[];
  final Map<String, GroceryTripDishSelection> _selectedDishes =
      <String, GroceryTripDishSelection>{};
  final Map<String, TextEditingController> _portionControllers =
      <String, TextEditingController>{};

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _portionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFoodItems() async {
    try {
      final List<FoodItem> loadedItems = await _dataStore.load();
      loadedItems.sort((FoodItem a, FoodItem b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _foodItems
          ..clear()
          ..addAll(loadedItems);
        _isLoading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load dishes for the grocery trip.';
      });
    }
  }

  bool _isSelected(FoodItem item) => _selectedDishes.containsKey(item.name);

  TextEditingController _controllerFor(FoodItem item) {
    return _portionControllers.putIfAbsent(item.name, () {
      final int portions =
          _selectedDishes[item.name]?.portions ?? item.defaultPortions;
      return TextEditingController(text: portions.toString());
    });
  }

  void _toggleDishSelection(FoodItem item) {
    setState(() {
      if (_isSelected(item)) {
        _selectedDishes.remove(item.name);
        _portionControllers.remove(item.name)?.dispose();
        return;
      }

      final GroceryTripDishSelection selection = GroceryTripDishSelection(
        item: item,
        portions: item.defaultPortions,
      );
      _selectedDishes[item.name] = selection;
      _controllerFor(item).text = item.defaultPortions.toString();
    });
  }

  void _changePortions(FoodItem item, int nextValue) {
    if (nextValue <= 0 || !_isSelected(item)) {
      return;
    }

    setState(() {
      final GroceryTripDishSelection current = _selectedDishes[item.name]!;
      _selectedDishes[item.name] = current.copyWith(portions: nextValue);
      _controllerFor(item).text = nextValue.toString();
    });
  }

  void _setPortionsFromInput(FoodItem item, String value) {
    if (!_isSelected(item)) {
      return;
    }

    final int? parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return;
    }

    setState(() {
      final GroceryTripDishSelection current = _selectedDishes[item.name]!;
      _selectedDishes[item.name] = current.copyWith(portions: parsed);
    });
  }

  double _portionFactor(GroceryTripDishSelection selection) {
    final int basePortions = selection.item.defaultPortions;
    if (basePortions <= 0) {
      return 1;
    }
    return selection.portions / basePortions;
  }

  _ParsedIngredient? _parseIngredientLine(String value) {
    final String input = _normalizeFractionCharacters(value.trim());
    if (input.isEmpty) {
      return null;
    }

    final RegExp amountPattern = RegExp(
      r'^((?:\d+/\d+|\d+(?:[.,]\d+)?)(?:\s+\d+/\d+)?)\s*(.+)$',
    );
    final RegExpMatch? amountMatch = amountPattern.firstMatch(input);
    if (amountMatch == null) {
      return null;
    }

    final double? amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) {
      return null;
    }

    final String remainder = amountMatch.group(2)!.trim();
    if (remainder.isEmpty) {
      return null;
    }

    final List<String> tokens = remainder.split(RegExp(r'\s+'));
    final String firstToken = tokens.first;
    final _IngredientUnit? unit = _IngredientUnit.fromToken(firstToken);
    if (unit != null) {
      final String name = remainder.substring(firstToken.length).trim();
      if (name.isEmpty) {
        return null;
      }
      return _ParsedIngredient(
        baseAmount: amount * unit.factorToBase,
        displayName: name,
        normalizedName: _normalizeIngredientName(name),
        unit: unit,
      );
    }

    return _ParsedIngredient(
      baseAmount: amount,
      displayName: _ParsedIngredient.singularizePhrase(remainder),
      normalizedName: _normalizeIngredientName(remainder),
    );
  }

  double? _parseAmount(String rawAmount) {
    final List<String> parts = rawAmount
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }

    double total = 0;
    for (final String part in parts) {
      if (part.contains('/')) {
        final List<String> fractionParts = part.split('/');
        if (fractionParts.length != 2) {
          return null;
        }
        final double? numerator = double.tryParse(
          fractionParts[0].replaceAll(',', '.'),
        );
        final double? denominator = double.tryParse(
          fractionParts[1].replaceAll(',', '.'),
        );
        if (numerator == null || denominator == null || denominator == 0) {
          return null;
        }
        total += numerator / denominator;
        continue;
      }

      final double? value = double.tryParse(part.replaceAll(',', '.'));
      if (value == null) {
        return null;
      }
      total += value;
    }
    return total;
  }

  String _normalizeFractionCharacters(String value) {
    const Map<String, String> replacements = <String, String>{
      '¼': '1/4',
      '½': '1/2',
      '¾': '3/4',
      '⅐': '1/7',
      '⅑': '1/9',
      '⅒': '1/10',
      '⅓': '1/3',
      '⅔': '2/3',
      '⅕': '1/5',
      '⅖': '2/5',
      '⅗': '3/5',
      '⅘': '4/5',
      '⅙': '1/6',
      '⅚': '5/6',
      '⅛': '1/8',
      '⅜': '3/8',
      '⅝': '5/8',
      '⅞': '7/8',
    };

    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < value.length; index++) {
      final String char = value[index];
      final String? replacement = replacements[char];
      if (replacement == null) {
        buffer.write(char);
        continue;
      }

      if (index > 0 && RegExp(r'\d').hasMatch(value[index - 1])) {
        buffer.write(' ');
      }
      buffer.write(replacement);
    }
    return buffer.toString();
  }

  String _normalizeIngredientName(String value) {
    final String normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return _ParsedIngredient.singularizePhrase(normalized);
  }

  List<GroceryListItem> _buildGroceryListItems() {
    final Map<String, _IngredientAccumulator> scalableItems =
        <String, _IngredientAccumulator>{};
    final Map<String, int> textCounts = <String, int>{};
    final Map<String, String> textLabels = <String, String>{};

    for (final GroceryTripDishSelection selection in _selectedDishes.values) {
      final double factor = _portionFactor(selection);
      for (final String ingredient in selection.item.ingredients) {
        final _ParsedIngredient? parsed = _parseIngredientLine(ingredient);
        if (parsed != null) {
          final _IngredientAccumulator accumulator = scalableItems.putIfAbsent(
            parsed.normalizedKey,
            () => _IngredientAccumulator(parsed),
          );
          accumulator.totalAmount += parsed.baseAmount * factor;
          continue;
        }

        final String normalized = ingredient.toLowerCase();
        textLabels.putIfAbsent(normalized, () => ingredient);
        textCounts.update(
          normalized,
          (int count) => count + 1,
          ifAbsent: () {
            return 1;
          },
        );
      }
    }

    final List<GroceryListItem> result = <GroceryListItem>[
      ...scalableItems.values.map((_IngredientAccumulator accumulator) {
        return GroceryListItem(
          label: accumulator.template.formatWithAmount(accumulator.totalAmount),
          normalizedKey: accumulator.template.normalizedKey,
        );
      }),
      ...textCounts.entries.map((MapEntry<String, int> entry) {
        final String label = textLabels[entry.key]!;
        if (entry.value <= 1) {
          return GroceryListItem(label: label, normalizedKey: entry.key);
        }
        return GroceryListItem(
          label: '${entry.value} x $label',
          normalizedKey: entry.key,
        );
      }),
    ];

    result.sort((GroceryListItem a, GroceryListItem b) {
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return result;
  }

  String _selectedIngredientsText(Map<String, bool> checkedItems) {
    final List<String> lines = _buildGroceryListItems()
        .where((GroceryListItem item) => checkedItems[item.label] ?? false)
        .map((GroceryListItem item) => item.label)
        .toList(growable: false);
    return lines.join('\n');
  }

  Future<void> _showIngredientListDialog() async {
    final List<GroceryListItem> items = _buildGroceryListItems();
    if (items.isEmpty) {
      return;
    }

    final Map<String, bool> checkedItems = <String, bool>{
      for (final GroceryListItem item in items) item.label: true,
    };

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String outputText = _selectedIngredientsText(checkedItems);

            Future<void> copySelectedItems() async {
              if (outputText.isEmpty) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: outputText));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selected ingredients copied as text.'),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Ingredients list'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: items
                            .map((GroceryListItem item) {
                              return CheckboxListTile(
                                key: ValueKey<String>(
                                  'grocery_item_${item.label}',
                                ),
                                value: checkedItems[item.label] ?? false,
                                title: Text(item.label),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    checkedItems[item.label] = value ?? false;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Copy this into Microsoft To Do'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        outputText.isEmpty
                            ? 'No ingredients selected.'
                            : outputText,
                        key: const ValueKey<String>(
                          'selected_ingredients_text',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (supportsTextFileDownload)
                  TextButton(
                    onPressed: outputText.isEmpty
                        ? null
                        : () {
                            final bool didDownload = downloadTextFile(
                              filename: 'grocery-list.txt',
                              contents: outputText,
                            );
                            if (!didDownload) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Downloaded grocery-list.txt'),
                              ),
                            );
                          },
                    child: const Text('Download .txt'),
                  ),
                FilledButton(
                  onPressed: outputText.isEmpty ? null : copySelectedItems,
                  child: const Text('Copy selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<GroceryTripDishSelection> _currentSelections() {
    return _selectedDishes.values.toList(growable: false);
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
      body = const Center(
        child: Text('Add dishes before planning a grocery trip.'),
      );
    } else {
      final List<GroceryTripDishSelection> selections = _currentSelections();
      final List<GroceryListItem> groceryItems = _buildGroceryListItems();

      body = Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Selected dishes: ${selections.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selections.isEmpty
                          ? 'Pick dishes below. Each selected dish starts with its saved recipe portions.'
                          : selections
                                .map((GroceryTripDishSelection selection) {
                                  return '${selection.item.name} (${selection.portions})';
                                })
                                .join(', '),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey<String>(
                          'get_ingredients_list_button',
                        ),
                        onPressed: groceryItems.isEmpty
                            ? null
                            : _showIngredientListDialog,
                        child: const Text('Get ingredients list'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _foodItems.length,
              itemBuilder: (BuildContext context, int index) {
                final FoodItem item = _foodItems[index];
                final bool selected = _isSelected(item);
                final GroceryTripDishSelection? selection =
                    _selectedDishes[item.name];
                final TextEditingController? controller = selected
                    ? _controllerFor(item)
                    : null;

                return Card(
                  key: ValueKey<String>('grocery_dish_${item.name}'),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recipe portions: ${item.defaultPortions}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.ingredients.isEmpty
                                        ? 'No ingredients listed'
                                        : item.ingredients.join(', '),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              key: ValueKey<String>(
                                'grocery_toggle_${item.name}',
                              ),
                              onPressed: () => _toggleDishSelection(item),
                              icon: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.add_circle,
                              ),
                              label: Text(selected ? 'Selected' : 'Add'),
                            ),
                          ],
                        ),
                        if (selected && selection != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              IconButton(
                                onPressed: selection.portions <= 1
                                    ? null
                                    : () => _changePortions(
                                        item,
                                        selection.portions - 1,
                                      ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 96,
                                child: TextField(
                                  key: ValueKey<String>(
                                    'grocery_portions_${item.name}',
                                  ),
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Portions',
                                  ),
                                  onChanged: (String value) {
                                    _setPortionsFromInput(item, value);
                                  },
                                ),
                              ),
                              IconButton(
                                onPressed: () => _changePortions(
                                  item,
                                  selection.portions + 1,
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grocery trip')),
      body: body,
    );
  }
}
