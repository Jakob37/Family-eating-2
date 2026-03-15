import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_window.dart';
import 'cloud_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppCloudSync.instance.initialize();
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
        final Uri routeUri =
            Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');
        switch (routeUri.path) {
          case GroceryTripPage.routeName:
            return MaterialPageRoute<void>(
              builder: (BuildContext context) => const GroceryTripPage(),
              settings: settings,
            );
          case GroceryTripPage.weekRouteName:
            return MaterialPageRoute<void>(
              builder: (BuildContext context) => GroceryTripPage(
                preloadWeekPlan: true,
                preloadWeekStart: routeUri.queryParameters['weekStart'],
              ),
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

class FamilyEatingData {
  const FamilyEatingData({
    this.foodItems = const <FoodItem>[],
    this.routineItems = const <RoutineFoodItem>[],
    this.weekPlans = const <WeekPlan>[],
  });

  final List<FoodItem> foodItems;
  final List<RoutineFoodItem> routineItems;
  final List<WeekPlan> weekPlans;
}

class FoodItem {
  const FoodItem({
    required this.name,
    required this.proteins,
    this.ingredients = const <IngredientEntry>[],
    this.cookingLogs = const <CookingLog>[],
    this.defaultPortions = 4,
    this.recipeUrl,
  });

  final String name;
  final List<ProteinType> proteins;
  final List<IngredientEntry> ingredients;
  final List<CookingLog> cookingLogs;
  final int defaultPortions;
  final String? recipeUrl;

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
    final List<IngredientEntry> ingredients = rawIngredients is List
        ? rawIngredients
              .map(IngredientEntry.fromDynamic)
              .where((IngredientEntry entry) => entry.name.isNotEmpty)
              .toList(growable: false)
        : <IngredientEntry>[];

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
      recipeUrl: _normalizeRecipeUrl(json['recipeUrl']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'proteins': proteins
          .map((ProteinType protein) => protein.storageValue)
          .toList(growable: false),
      'ingredients': ingredients
          .map((IngredientEntry ingredient) => ingredient.toJson())
          .toList(growable: false),
      'cookingLogs': cookingLogs
          .map((CookingLog log) => log.toJson())
          .toList(growable: false),
      'defaultPortions': defaultPortions,
      'recipeUrl': recipeUrl,
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
    List<IngredientEntry>? ingredients,
    List<CookingLog>? cookingLogs,
    int? defaultPortions,
    String? recipeUrl,
  }) {
    return FoodItem(
      name: name ?? this.name,
      proteins: proteins ?? this.proteins,
      ingredients: ingredients ?? this.ingredients,
      cookingLogs: cookingLogs ?? this.cookingLogs,
      defaultPortions: defaultPortions ?? this.defaultPortions,
      recipeUrl: recipeUrl ?? this.recipeUrl,
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
    return (clamped * 10).round() / 10;
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

class DishEditorResult {
  const DishEditorResult({
    required this.name,
    required this.proteins,
    required this.ingredients,
    required this.defaultPortions,
    required this.recipeUrl,
  });

  final String name;
  final List<ProteinType> proteins;
  final List<IngredientEntry> ingredients;
  final int defaultPortions;
  final String? recipeUrl;
}

class WeekPlan {
  const WeekPlan({required this.weekStart, required this.entries});

  final String weekStart;
  final List<WeekPlanEntry> entries;

  bool get isEmpty => entries.isEmpty;

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    final String weekStart = (json['weekStart'] ?? '').toString().trim();
    final dynamic rawEntries = json['entries'];
    final List<WeekPlanEntry> entries = rawEntries is List
        ? rawEntries
              .whereType<Map>()
              .map(
                (Map entry) =>
                    WeekPlanEntry.fromJson(Map<String, dynamic>.from(entry)),
              )
              .where((WeekPlanEntry entry) => entry.dishName.trim().isNotEmpty)
              .toList(growable: false)
        : <WeekPlanEntry>[];
    return WeekPlan(weekStart: weekStart, entries: entries);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weekStart': weekStart,
      'entries': entries.map((WeekPlanEntry entry) => entry.toJson()).toList(),
    };
  }

  WeekPlan copyWith({String? weekStart, List<WeekPlanEntry>? entries}) {
    return WeekPlan(
      weekStart: weekStart ?? this.weekStart,
      entries: entries ?? this.entries,
    );
  }
}

class WeekPlanEntry {
  const WeekPlanEntry({
    required this.dishName,
    required this.portions,
    this.isCooked = false,
  });

  final String dishName;
  final int portions;
  final bool isCooked;

  factory WeekPlanEntry.fromJson(Map<String, dynamic> json) {
    final String dishName = (json['dishName'] ?? '').toString().trim();
    final int portions = FoodItem._parseDefaultPortions(json['portions']);
    final bool isCooked = json['isCooked'] == true;
    return WeekPlanEntry(
      dishName: dishName,
      portions: portions,
      isCooked: isCooked,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dishName': dishName,
      'portions': portions,
      'isCooked': isCooked,
    };
  }

  WeekPlanEntry copyWith({String? dishName, int? portions, bool? isCooked}) {
    return WeekPlanEntry(
      dishName: dishName ?? this.dishName,
      portions: portions ?? this.portions,
      isCooked: isCooked ?? this.isCooked,
    );
  }
}

class RoutineFoodItem {
  const RoutineFoodItem({required this.id, required this.ingredient});

  final String id;
  final IngredientEntry ingredient;

  factory RoutineFoodItem.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString().trim();
    final IngredientEntry ingredient = IngredientEntry.fromDynamic(
      json['ingredient'] ?? json['item'] ?? json['label'],
    );
    return RoutineFoodItem(
      id: id.isEmpty ? _createLocalId() : id,
      ingredient: ingredient,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'ingredient': ingredient.toJson()};
  }

  RoutineFoodItem copyWith({String? id, IngredientEntry? ingredient}) {
    return RoutineFoodItem(
      id: id ?? this.id,
      ingredient: ingredient ?? this.ingredient,
    );
  }
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

  static _IngredientUnit? fromKey(String key) {
    for (final _IngredientUnit unit in values) {
      if (unit.key == key) {
        return unit;
      }
    }
    return null;
  }

  static String _normalizeToken(String token) {
    return token.trim().toLowerCase().replaceAll(RegExp(r'[.,]$'), '');
  }
}

class IngredientEntry {
  const IngredientEntry({required this.name, this.amount, this.unitKey});

  final String name;
  final double? amount;
  final String? unitKey;

  _IngredientUnit? get _unit {
    if (unitKey == null || unitKey!.isEmpty) {
      return null;
    }
    return _IngredientUnit.fromKey(unitKey!);
  }

  String get displayLabel {
    final _ParsedIngredient? parsed = _toParsedIngredient();
    if (parsed == null) {
      return name;
    }
    return parsed.formatWithAmount(parsed.baseAmount);
  }

  factory IngredientEntry.fromDynamic(dynamic rawValue) {
    if (rawValue is Map) {
      return IngredientEntry.fromJson(Map<String, dynamic>.from(rawValue));
    }
    return IngredientEntry.fromLegacyText('$rawValue');
  }

  factory IngredientEntry.fromJson(Map<String, dynamic> json) {
    final String directName = (json['name'] ?? '').toString().trim();
    if (directName.isEmpty && json['label'] != null) {
      return IngredientEntry.fromLegacyText('${json['label']}');
    }
    final double? amount = _parseOptionalAmount(json['amount']);
    final String? unitKey = _normalizeUnitKey(json['unit'] ?? json['unitKey']);
    return IngredientEntry(
      name: directName,
      amount: amount,
      unitKey: amount == null ? null : unitKey,
    );
  }

  factory IngredientEntry.fromLegacyText(String rawValue) {
    final String trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const IngredientEntry(name: '');
    }
    final _ParsedIngredient? parsed = _parseIngredientText(trimmed);
    if (parsed == null) {
      return IngredientEntry(name: trimmed);
    }
    return IngredientEntry(
      name: parsed.displayName,
      amount: parsed.unit == null
          ? parsed.baseAmount
          : parsed.baseAmount / parsed.unit!.factorToBase,
      unitKey: parsed.unit?.key,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'amount': amount,
      'unitKey': amount == null ? null : unitKey,
    };
  }

  _ParsedIngredient? _toParsedIngredient() {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty || amount == null) {
      return null;
    }
    final _IngredientUnit? ingredientUnit = _unit;
    return _ParsedIngredient(
      baseAmount: ingredientUnit == null
          ? amount!
          : amount! * ingredientUnit.factorToBase,
      displayName: ingredientUnit == null
          ? _ParsedIngredient.singularizePhrase(trimmedName)
          : trimmedName,
      normalizedName: _normalizeIngredientName(trimmedName),
      unit: ingredientUnit,
    );
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

class _IngredientDraft {
  _IngredientDraft({required this.name, this.amountInput = '', this.unitKey});

  String name;
  String amountInput;
  String? unitKey;

  factory _IngredientDraft.fromEntry(IngredientEntry entry) {
    return _IngredientDraft(
      name: entry.name,
      amountInput: entry.amount == null
          ? ''
          : _ParsedIngredient._formatScaledAmount(entry.amount!),
      unitKey: entry.amount == null ? null : entry.unitKey,
    );
  }

  bool get isCompletelyEmpty {
    return name.trim().isEmpty &&
        amountInput.trim().isEmpty &&
        (unitKey == null || unitKey!.isEmpty);
  }

  IngredientEntry? toIngredientEntry() {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return null;
    }
    final double? parsedAmount = _parseOptionalAmount(amountInput);
    return IngredientEntry(
      name: trimmedName,
      amount: parsedAmount,
      unitKey: parsedAmount == null ? null : unitKey,
    );
  }
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

double? _parseCompositeAmount(String rawAmount) {
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

double? _parseOptionalAmount(dynamic rawValue) {
  final String normalized = '$rawValue'.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final double? parsed = _parseCompositeAmount(
    _normalizeFractionCharacters(normalized),
  );
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

String? _normalizeUnitKey(dynamic rawValue) {
  final String normalized = '$rawValue'.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return _IngredientUnit.fromToken(normalized)?.key;
}

String _normalizeIngredientName(String value) {
  final String normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  return _ParsedIngredient.singularizePhrase(normalized);
}

_ParsedIngredient? _parseIngredientText(String value) {
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

  final double? amount = _parseCompositeAmount(amountMatch.group(1)!);
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

String? _normalizeRecipeUrl(String rawValue) {
  final String trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final String candidate = trimmed.contains('://')
      ? trimmed
      : 'https://$trimmed';
  final Uri? parsed = Uri.tryParse(candidate);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return null;
  }
  if (parsed.scheme != 'http' && parsed.scheme != 'https') {
    return null;
  }
  return parsed.toString();
}

String _createLocalId() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

DateTime _startOfWeek(DateTime value) {
  final DateTime localMidnight = DateTime(value.year, value.month, value.day);
  final int daysFromMonday = localMidnight.weekday - DateTime.monday;
  return localMidnight.subtract(Duration(days: daysFromMonday));
}

String _formatWeekStartKey(DateTime value) {
  final DateTime weekStart = _startOfWeek(value);
  final String month = weekStart.month.toString().padLeft(2, '0');
  final String day = weekStart.day.toString().padLeft(2, '0');
  return '${weekStart.year}-$month-$day';
}

String _currentWeekStartKey() {
  return _formatWeekStartKey(DateTime.now());
}

DateTime? _parseWeekStartKey(String value) {
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _shiftWeekStartKey(String value, int weekOffset) {
  final DateTime base =
      _parseWeekStartKey(value) ?? _startOfWeek(DateTime.now());
  return _formatWeekStartKey(base.add(Duration(days: 7 * weekOffset)));
}

String _monthShortLabel(int month) {
  const List<String> labels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[month - 1];
}

String _weekLabel(String weekStart) {
  final DateTime? parsed = _parseWeekStartKey(weekStart);
  if (parsed == null) {
    return weekStart;
  }
  final DateTime current = _startOfWeek(DateTime.now());
  final int dayDifference = parsed.difference(current).inDays;
  if (dayDifference == 0) {
    return 'This week';
  }
  if (dayDifference == -7) {
    return 'Last week';
  }
  if (dayDifference == 7) {
    return 'Next week';
  }
  final DateTime end = parsed.add(const Duration(days: 6));
  return '${_monthShortLabel(parsed.month)} ${parsed.day} - ${_monthShortLabel(end.month)} ${end.day}';
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
  static const int currentVersion = 10;

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
    final Map<String, dynamic> payload = <String, dynamic>{
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
    };
    await prefs.setString(_dataKey, jsonEncode(payload));
    if (pushRemote) {
      await AppCloudSync.instance.pushLatestSnapshot(payload);
    }
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
  final List<RoutineFoodItem> _routineItems = <RoutineFoodItem>[];
  final Set<String> _expandedDishNames = <String>{};
  final List<WeekPlan> _weekPlans = <WeekPlan>[];
  String _selectedWeekStart = _currentWeekStartKey();

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
        .where((FoodItem item) => _matchesFilter(item, _activeFilter))
        .toList(growable: false);
  }

  bool _matchesFilter(FoodItem item, DishFilter filter) {
    if (filter.selectedProteins.isNotEmpty) {
      final bool hasProteinMatch = item.proteins.any(
        filter.selectedProteins.contains,
      );
      if (!hasProteinMatch) {
        return false;
      }
    }

    if (filter.minRating > 0) {
      final double? averageRating = item.averageRating;
      if (averageRating == null || averageRating < filter.minRating) {
        return false;
      }
    }

    if (filter.minCookingTimeMinutes != null) {
      final double? averageDuration = item.averageDurationMinutes;
      if (averageDuration == null ||
          averageDuration < filter.minCookingTimeMinutes!) {
        return false;
      }
    }

    if (filter.maxCookingTimeMinutes != null) {
      final double? averageDuration = item.averageDurationMinutes;
      if (averageDuration == null ||
          averageDuration > filter.maxCookingTimeMinutes!) {
        return false;
      }
    }

    return true;
  }

  Future<DishFilter?> _showDishFilterDialog({
    required DishFilter initialFilter,
    String title = 'Filter dishes',
  }) async {
    Set<ProteinType> selectedProteins = Set<ProteinType>.from(
      initialFilter.selectedProteins,
    );
    double minRating = initialFilter.minRating;
    String minTimeInput = initialFilter.minCookingTimeMinutes?.toString() ?? '';
    String maxTimeInput = initialFilter.maxCookingTimeMinutes?.toString() ?? '';
    String? minTimeError;
    String? maxTimeError;

    return showDialog<DishFilter>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(title),
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
                      Text(
                        minRating == 0
                            ? 'Minimum average rating: none'
                            : 'Minimum average rating: ${minRating.toStringAsFixed(1)}',
                      ),
                      Slider(
                        key: const ValueKey<String>('min_rating_slider'),
                        value: minRating,
                        min: 0,
                        max: 5,
                        divisions: 50,
                        label: minRating == 0
                            ? 'No minimum'
                            : minRating.toStringAsFixed(1),
                        onChanged: (double value) {
                          setDialogState(() {
                            minRating = (value * 10).round() / 10;
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
  }

  Future<void> _openFilterMenu() async {
    final DishFilter? nextFilter = await _showDishFilterDialog(
      initialFilter: _activeFilter,
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

  String _cloudStatusSummary(AppCloudSync cloudSync) {
    if (cloudSync.initError != null) {
      return 'Cloud setup failed: ${cloudSync.initError}';
    }
    if (!cloudSync.isConfigured) {
      return 'Local-only mode. Add Supabase keys to enable sign-in and sync.';
    }
    if (!cloudSync.hasSession) {
      return 'Cloud is configured, but no one is signed in.';
    }
    if (!cloudSync.hasActiveHousehold) {
      return 'Signed in as ${cloudSync.currentUserEmail}, but no household is linked.';
    }
    final String syncedAt = cloudSync.lastSyncedAt == null
        ? 'No sync yet'
        : 'Last sync ${cloudSync.lastSyncedAt!.toLocal()}';
    return '${cloudSync.activeHouseholdName} connected. $syncedAt';
  }

  Future<void> _showAccountAndSyncDialog() async {
    final AppCloudSync cloudSync = AppCloudSync.instance;
    final TextEditingController emailController = TextEditingController(
      text: cloudSync.currentUserEmail ?? '',
    );
    final TextEditingController householdNameController =
        TextEditingController();
    final TextEditingController inviteCodeController = TextEditingController();
    String? actionMessage;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            Future<void> runAction(Future<String?> Function() action) async {
              setDialogState(() {
                actionMessage = null;
              });
              final String? result = await action();
              if (!context.mounted) {
                return;
              }
              setDialogState(() {
                actionMessage =
                    result ??
                    'Done. If you used email sign-in, open the link from your inbox on this device.';
              });
              setState(() {
                _isLoading = true;
                _loadError = null;
              });
              _loadFoodItems();
            }

            return AnimatedBuilder(
              animation: cloudSync,
              builder: (BuildContext context, Widget? child) {
                return AlertDialog(
                  title: const Text('Account & sync'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(_cloudStatusSummary(cloudSync)),
                          if (cloudSync.lastSyncError != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              'Latest sync error: ${cloudSync.lastSyncError}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          if (actionMessage != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(actionMessage!),
                          ],
                          const SizedBox(height: 16),
                          if (!cloudSync.isConfigured) ...<Widget>[
                            const Text(
                              'Supabase is not configured in this build yet. You can keep using the app locally, then add cloud config later.',
                            ),
                          ] else ...<Widget>[
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'you@example.com',
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: cloudSync.isSyncing
                                  ? null
                                  : () {
                                      runAction(
                                        () => cloudSync.signInWithEmailOtp(
                                          emailController.text,
                                        ),
                                      );
                                    },
                              child: const Text('Send sign-in link'),
                            ),
                            if (cloudSync.hasSession) ...<Widget>[
                              const SizedBox(height: 16),
                              TextField(
                                controller: householdNameController,
                                decoration: const InputDecoration(
                                  labelText: 'New household name',
                                  hintText: 'e.g. Family eating',
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: cloudSync.isSyncing
                                    ? null
                                    : () {
                                        runAction(
                                          () => cloudSync.createHousehold(
                                            householdNameController.text,
                                          ),
                                        );
                                      },
                                child: const Text('Create household'),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: inviteCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Invite code',
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: cloudSync.isSyncing
                                    ? null
                                    : () {
                                        runAction(
                                          () => cloudSync.joinHousehold(
                                            inviteCodeController.text,
                                          ),
                                        );
                                      },
                                child: const Text('Join household'),
                              ),
                              if (cloudSync.hasActiveHousehold) ...<Widget>[
                                const SizedBox(height: 16),
                                FilledButton.tonalIcon(
                                  onPressed: cloudSync.isSyncing
                                      ? null
                                      : () {
                                          setState(() {
                                            _isLoading = true;
                                            _loadError = null;
                                          });
                                          _loadFoodItems();
                                          Navigator.of(context).pop();
                                        },
                                  icon: const Icon(Icons.sync),
                                  label: const Text(
                                    'Pull latest household data',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: cloudSync.isSyncing
                                    ? null
                                    : () {
                                        runAction(cloudSync.signOut);
                                      },
                                child: const Text('Sign out'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    emailController.dispose();
    householdNameController.dispose();
    inviteCodeController.dispose();
  }

  FoodItem? _findFoodItemByName(String dishName) {
    for (final FoodItem item in _foodItems) {
      if (item.name == dishName) {
        return item;
      }
    }
    return null;
  }

  WeekPlan? _weekPlanForStart(String weekStart) {
    for (final WeekPlan plan in _weekPlans) {
      if (plan.weekStart == weekStart) {
        return plan;
      }
    }
    return null;
  }

  WeekPlan? get _selectedWeekPlan => _weekPlanForStart(_selectedWeekStart);

  void _upsertWeekPlan(WeekPlan plan) {
    final int existingIndex = _weekPlans.indexWhere(
      (WeekPlan existing) => existing.weekStart == plan.weekStart,
    );
    if (existingIndex == -1) {
      _weekPlans.add(plan);
    } else {
      _weekPlans[existingIndex] = plan;
    }
    _weekPlans.sort(
      (WeekPlan a, WeekPlan b) => a.weekStart.compareTo(b.weekStart),
    );
  }

  void _removeWeekPlan(String weekStart) {
    _weekPlans.removeWhere((WeekPlan plan) => plan.weekStart == weekStart);
  }

  Future<WeekPlan?> _showWeekPlanEditorDialog() async {
    final WeekPlan? existingPlan = _selectedWeekPlan;
    final Map<String, int> selectedPortions = <String, int>{
      for (final WeekPlanEntry entry
          in existingPlan?.entries ?? <WeekPlanEntry>[])
        entry.dishName: entry.portions,
    };
    final Map<String, bool> cookedStates = <String, bool>{
      for (final WeekPlanEntry entry
          in existingPlan?.entries ?? <WeekPlanEntry>[])
        entry.dishName: entry.isCooked,
    };
    DishFilter plannerFilter = DishFilter.empty;
    final Map<String, TextEditingController> controllers =
        <String, TextEditingController>{
          for (final FoodItem item in _foodItems)
            item.name: TextEditingController(
              text: (selectedPortions[item.name] ?? item.defaultPortions)
                  .toString(),
            ),
        };

    return showDialog<WeekPlan>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final Set<String> selectedNames = selectedPortions.keys.toSet();
            final List<FoodItem> visibleItems = _foodItems
                .where((FoodItem item) {
                  return selectedNames.contains(item.name) ||
                      _matchesFilter(item, plannerFilter);
                })
                .toList(growable: false);
            final List<WeekPlanEntry> entries = _foodItems
                .where(
                  (FoodItem item) => selectedPortions.containsKey(item.name),
                )
                .map((FoodItem item) {
                  return WeekPlanEntry(
                    dishName: item.name,
                    portions:
                        selectedPortions[item.name] ?? item.defaultPortions,
                    isCooked: cookedStates[item.name] ?? false,
                  );
                })
                .toList(growable: false);

            return AlertDialog(
              title: Text('Plan ${_weekLabel(_selectedWeekStart)}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            plannerFilter.hasActiveFilters
                                ? 'Showing filtered dishes and selected dishes'
                                : 'Showing all dishes',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final DishFilter? nextFilter =
                                await _showDishFilterDialog(
                                  initialFilter: plannerFilter,
                                  title: 'Filter week planner',
                                );
                            if (nextFilter == null) {
                              return;
                            }
                            setDialogState(() {
                              plannerFilter = nextFilter;
                            });
                          },
                          icon: Icon(
                            plannerFilter.hasActiveFilters
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                          ),
                          label: const Text('Filter'),
                        ),
                      ],
                    ),
                    if (plannerFilter.hasActiveFilters)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            if (plannerFilter.selectedProteins.isNotEmpty)
                              Chip(
                                label: Text(
                                  'Proteins: ${plannerFilter.selectedProteins.map((ProteinType protein) => protein.label).join(', ')}',
                                ),
                              ),
                            if (plannerFilter.minRating > 0)
                              Chip(
                                label: Text(
                                  'Min rating: ${plannerFilter.minRating.toStringAsFixed(1)}',
                                ),
                              ),
                            if (plannerFilter.minCookingTimeMinutes != null)
                              Chip(
                                label: Text(
                                  'Min time: ${plannerFilter.minCookingTimeMinutes} min',
                                ),
                              ),
                            if (plannerFilter.maxCookingTimeMinutes != null)
                              Chip(
                                label: Text(
                                  'Max time: ${plannerFilter.maxCookingTimeMinutes} min',
                                ),
                              ),
                            ActionChip(
                              label: const Text('Clear'),
                              onPressed: () {
                                setDialogState(() {
                                  plannerFilter = DishFilter.empty;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: visibleItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          final FoodItem item = visibleItems[index];
                          final bool selected = selectedPortions.containsKey(
                            item.name,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Checkbox(
                                          key: ValueKey<String>(
                                            'week_planner_select_${item.name}',
                                          ),
                                          value: selected,
                                          onChanged: (bool? value) {
                                            setDialogState(() {
                                              if (value ?? false) {
                                                selectedPortions[item.name] =
                                                    item.defaultPortions;
                                                controllers[item.name]!.text =
                                                    item.defaultPortions
                                                        .toString();
                                              } else {
                                                selectedPortions.remove(
                                                  item.name,
                                                );
                                                cookedStates.remove(item.name);
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        if (selected)
                                          SizedBox(
                                            width: 92,
                                            child: TextField(
                                              controller:
                                                  controllers[item.name],
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Portions',
                                              ),
                                              onChanged: (String value) {
                                                final int? parsed =
                                                    int.tryParse(value.trim());
                                                if (parsed == null ||
                                                    parsed <= 0) {
                                                  return;
                                                }
                                                selectedPortions[item.name] =
                                                    parsed;
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        item.ingredients.isEmpty
                                            ? 'No ingredients listed'
                                            : _ingredientSummary(item),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entries.isEmpty
                            ? 'No dishes selected.'
                            : 'Selected: ${entries.length}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                          WeekPlan(
                            weekStart: _selectedWeekStart,
                            entries: entries,
                          ),
                        ),
                  child: const Text('Save week'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      for (final TextEditingController controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  Future<void> _editWeekPlan() async {
    final WeekPlan? nextWeekPlan = await _showWeekPlanEditorDialog();
    if (nextWeekPlan == null) {
      return;
    }
    setState(() {
      _upsertWeekPlan(nextWeekPlan);
    });
    await _persistData();
  }

  Future<void> _clearWeekPlan() async {
    setState(() {
      _removeWeekPlan(_selectedWeekStart);
    });
    await _persistData();
  }

  Future<void> _addDishToCurrentWeekPlan(FoodItem item) async {
    final String currentWeekStart = _currentWeekStartKey();
    final WeekPlan? existingPlan = _weekPlanForStart(currentWeekStart);
    final bool alreadyPlanned =
        existingPlan?.entries.any(
          (WeekPlanEntry entry) => entry.dishName == item.name,
        ) ??
        false;

    if (alreadyPlanned) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} is already in This week.')),
      );
      return;
    }

    final List<WeekPlanEntry> nextEntries = <WeekPlanEntry>[
      ...(existingPlan?.entries ?? const <WeekPlanEntry>[]),
      WeekPlanEntry(dishName: item.name, portions: item.defaultPortions),
    ];

    setState(() {
      _upsertWeekPlan(
        WeekPlan(weekStart: currentWeekStart, entries: nextEntries),
      );
    });
    await _persistData();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added ${item.name} to This week.')));
  }

  Future<void> _toggleWeekEntryCooked(
    WeekPlanEntry entry,
    bool isCooked,
  ) async {
    final WeekPlan? selectedPlan = _selectedWeekPlan;
    if (selectedPlan == null) {
      return;
    }
    setState(() {
      _upsertWeekPlan(
        selectedPlan.copyWith(
          entries: selectedPlan.entries
              .map((WeekPlanEntry current) {
                if (current.dishName != entry.dishName) {
                  return current;
                }
                return current.copyWith(isCooked: isCooked);
              })
              .toList(growable: false),
        ),
      );
    });
    await _persistData();
  }

  void _moveSelectedWeek(int weekOffset) {
    setState(() {
      _selectedWeekStart = _shiftWeekStartKey(_selectedWeekStart, weekOffset);
    });
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
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadFoodItems();
  }

  Future<void> _openWeekGroceryTrip() async {
    final WeekPlan? selectedPlan = _selectedWeekPlan;
    if (_isLoading || _loadError != null || selectedPlan == null) {
      return;
    }

    final String routeName =
        '${GroceryTripPage.weekRouteName}?weekStart=${selectedPlan.weekStart}';

    if (openRouteInNewWindow(routeName)) {
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(routeName);
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadFoodItems();
  }

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  Future<void> _loadFoodItems() async {
    try {
      final FamilyEatingData data = await _dataStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _foodItems
          ..clear()
          ..addAll(data.foodItems);
        _routineItems
          ..clear()
          ..addAll(data.routineItems);
        _weekPlans
          ..clear()
          ..addAll(data.weekPlans);
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

  Future<void> _persistData() async {
    try {
      await _dataStore.save(
        FamilyEatingData(
          foodItems: _foodItems,
          routineItems: _routineItems,
          weekPlans: _weekPlans,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save changes.')));
    }
  }

  String? _validateIngredientDrafts(List<_IngredientDraft> drafts) {
    for (final _IngredientDraft draft in drafts) {
      if (draft.isCompletelyEmpty) {
        continue;
      }
      if (draft.name.trim().isEmpty) {
        return 'Each ingredient needs a name.';
      }
      final bool hasAmount = draft.amountInput.trim().isNotEmpty;
      if ((draft.unitKey ?? '').isNotEmpty && !hasAmount) {
        return 'Enter an amount when a unit is selected.';
      }
      if (hasAmount && _parseOptionalAmount(draft.amountInput) == null) {
        return 'Ingredient amounts must be above 0.';
      }
    }
    return null;
  }

  List<IngredientEntry> _ingredientEntriesFromDrafts(
    List<_IngredientDraft> drafts,
  ) {
    return drafts
        .map((_IngredientDraft draft) => draft.toIngredientEntry())
        .whereType<IngredientEntry>()
        .toList(growable: false);
  }

  Future<DishEditorResult?> _showDishEditorDialog({
    required String title,
    required String saveLabel,
    required String initialName,
    required List<ProteinType> initialProteins,
    required List<IngredientEntry> initialIngredients,
    required int initialDefaultPortions,
    required String? initialRecipeUrl,
  }) async {
    String draftName = initialName;
    final Set<ProteinType> selectedProteins = Set<ProteinType>.from(
      initialProteins,
    );
    final List<_IngredientDraft> ingredientDrafts = initialIngredients.isEmpty
        ? <_IngredientDraft>[_IngredientDraft(name: '')]
        : initialIngredients
              .map(_IngredientDraft.fromEntry)
              .toList(growable: true);
    String defaultPortionsInput = initialDefaultPortions.toString();
    String recipeUrlInput = initialRecipeUrl ?? '';
    String? defaultPortionsError;
    String? recipeUrlError;
    String? ingredientsError;

    return showDialog<DishEditorResult>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final int? parsedDefaultPortions = _parsePositiveInt(
              defaultPortionsInput,
            );
            final bool canSave =
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
                        initialValue: draftName,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Pasta',
                          labelText: 'Dish',
                        ),
                        onChanged: (String value) {
                          setDialogState(() {
                            draftName = value;
                          });
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
                        key: const ValueKey<String>('recipe_url_field'),
                        initialValue: recipeUrlInput,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Recipe URL',
                          hintText: 'https://example.com/recipe',
                          errorText: recipeUrlError,
                        ),
                        onChanged: (String value) {
                          setDialogState(() {
                            recipeUrlInput = value;
                            recipeUrlError = null;
                          });
                        },
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
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Ingredients',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                ingredientDrafts.add(
                                  _IngredientDraft(name: ''),
                                );
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add row'),
                          ),
                        ],
                      ),
                      if (ingredientsError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          ingredientsError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ...List<Widget>.generate(ingredientDrafts.length, (
                        int index,
                      ) {
                        final _IngredientDraft draft = ingredientDrafts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'Ingredient ${index + 1}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove ingredient',
                                        onPressed: ingredientDrafts.length == 1
                                            ? null
                                            : () {
                                                setDialogState(() {
                                                  ingredientDrafts.removeAt(
                                                    index,
                                                  );
                                                  ingredientsError = null;
                                                });
                                              },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: <Widget>[
                                      SizedBox(
                                        width: 88,
                                        child: TextFormField(
                                          key: ValueKey<String>(
                                            'ingredient_amount_$index',
                                          ),
                                          initialValue: draft.amountInput,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: const InputDecoration(
                                            labelText: 'Amount',
                                          ),
                                          onChanged: (String value) {
                                            draft.amountInput = value;
                                            if (ingredientsError != null) {
                                              setDialogState(() {
                                                ingredientsError = null;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String?>(
                                          key: ValueKey<String>(
                                            'ingredient_unit_$index',
                                          ),
                                          initialValue: draft.unitKey,
                                          decoration: const InputDecoration(
                                            labelText: 'Unit',
                                          ),
                                          items: <DropdownMenuItem<String?>>[
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text('None'),
                                            ),
                                            ..._IngredientUnit.values.map((
                                              _IngredientUnit unit,
                                            ) {
                                              return DropdownMenuItem<String?>(
                                                value: unit.key,
                                                child: Text(unit.singularLabel),
                                              );
                                            }),
                                          ],
                                          onChanged: (String? value) {
                                            setDialogState(() {
                                              draft.unitKey = value;
                                              ingredientsError = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: ValueKey<String>(
                                      'ingredient_name_$index',
                                    ),
                                    initialValue: draft.name,
                                    decoration: const InputDecoration(
                                      labelText: 'Ingredient name',
                                      hintText: 'e.g. minced meat',
                                    ),
                                    onChanged: (String value) {
                                      draft.name = value;
                                      if (ingredientsError != null) {
                                        setDialogState(() {
                                          ingredientsError = null;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      Text(
                        'Leave amount empty for non-scaled items.',
                        style: Theme.of(context).textTheme.bodySmall,
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
                  onPressed: !canSave
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
                          final String? validatedRecipeUrl =
                              _normalizeRecipeUrl(recipeUrlInput);
                          if (recipeUrlInput.trim().isNotEmpty &&
                              validatedRecipeUrl == null) {
                            setDialogState(() {
                              recipeUrlError =
                                  'Enter a valid http or https URL';
                            });
                            return;
                          }
                          final String? validatedIngredients =
                              _validateIngredientDrafts(ingredientDrafts);
                          if (validatedIngredients != null) {
                            setDialogState(() {
                              ingredientsError = validatedIngredients;
                            });
                            return;
                          }
                          Navigator.of(context).pop(
                            DishEditorResult(
                              name: draftName.trim(),
                              proteins: ProteinType.values
                                  .where(selectedProteins.contains)
                                  .toList(growable: false),
                              ingredients: _ingredientEntriesFromDrafts(
                                ingredientDrafts,
                              ),
                              defaultPortions: validatedPortions,
                              recipeUrl: validatedRecipeUrl,
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
      initialIngredients: const <IngredientEntry>[],
      initialDefaultPortions: 4,
      initialRecipeUrl: null,
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
          recipeUrl: value.recipeUrl,
        ),
      );
      _sortFoodItemsByRanking();
    });
    await _persistData();
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
      initialRecipeUrl: item.recipeUrl,
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
        recipeUrl: edited.recipeUrl,
      );
      for (int index = 0; index < _weekPlans.length; index++) {
        final WeekPlan plan = _weekPlans[index];
        _weekPlans[index] = plan.copyWith(
          entries: plan.entries
              .map((WeekPlanEntry entry) {
                if (entry.dishName != existingItem.name) {
                  return entry;
                }
                return entry.copyWith(dishName: edited.name);
              })
              .toList(growable: false),
        );
      }
      _sortFoodItemsByRanking();
    });
    await _persistData();
  }

  Future<void> _logCookingForDish(FoodItem item) async {
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
    await _persistData();
  }

  Future<bool> _confirmDeleteDish(FoodItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove dish?'),
          content: Text('Delete "${item.name}" from the list?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _removeDish(FoodItem item) async {
    final int itemIndex = _foodItems.indexOf(item);
    if (itemIndex == -1) {
      return;
    }
    setState(() {
      _foodItems.removeAt(itemIndex);
      _expandedDishNames.remove(item.name);
      for (int index = _weekPlans.length - 1; index >= 0; index--) {
        final WeekPlan plan = _weekPlans[index];
        final List<WeekPlanEntry> remainingEntries = plan.entries
            .where((WeekPlanEntry entry) => entry.dishName != item.name)
            .toList(growable: false);
        if (remainingEntries.isEmpty) {
          _weekPlans.removeAt(index);
          continue;
        }
        _weekPlans[index] = plan.copyWith(entries: remainingEntries);
      }
    });
    await _persistData();
  }

  void _toggleDishExpansion(FoodItem item) {
    setState(() {
      if (_expandedDishNames.contains(item.name)) {
        _expandedDishNames.remove(item.name);
      } else {
        _expandedDishNames.add(item.name);
      }
    });
  }

  Future<void> _handleRecipeUrlTap(String recipeUrl) async {
    if (openExternalUrl(recipeUrl, windowName: 'recipe-link')) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: recipeUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe URL copied to clipboard.')),
    );
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
                    divisions: 50,
                    label: _formatRating(rating),
                    onChanged: (double value) {
                      setDialogState(() {
                        rating = (value * 10).round() / 10;
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

  Widget _buildCompactMetric({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.secondaryContainer),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  String _ingredientSummary(FoodItem item) {
    if (item.ingredients.isEmpty) {
      return 'No ingredients listed';
    }
    return item.ingredients
        .map((IngredientEntry entry) => entry.displayLabel)
        .join(', ');
  }

  Widget _buildDishCard(FoodItem item, int ranking) {
    final bool isExpanded = _expandedDishNames.contains(item.name);
    final ProteinType? primaryProtein = item.proteins.isEmpty
        ? null
        : item.proteins.first;

    return Dismissible(
      key: ValueKey<String>('dish_card_${item.name}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _addDishToCurrentWeekPlan(item);
          return false;
        }
        return _confirmDeleteDish(item);
      },
      onDismissed: (_) {
        _removeDish(item);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: Icon(
          Icons.calendar_month_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleDishExpansion(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 20,
                      child: primaryProtein == null
                          ? const Icon(Icons.restaurant_menu, size: 18)
                          : FaIcon(primaryProtein.icon, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                '#$ranking',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _buildCompactMetric(
                                icon: Icons.history,
                                label: item.cookedCount.toString(),
                              ),
                              _buildCompactMetric(
                                icon: Icons.star_rounded,
                                label: item.averageRating == null
                                    ? '--'
                                    : _formatRating(item.averageRating!),
                                color: Colors.amber.shade100,
                              ),
                              _buildCompactMetric(
                                icon: Icons.people_outline,
                                label: '${item.defaultPortions}p',
                              ),
                              if (item.averageDurationMinutes != null)
                                _buildCompactMetric(
                                  icon: Icons.schedule_outlined,
                                  label:
                                      '${item.averageDurationMinutes!.round()}m',
                                ),
                              if (item.recipeUrl != null)
                                _buildCompactMetric(
                                  icon: Icons.link,
                                  label: 'Recipe',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: <Widget>[
                        IconButton(
                          key: ValueKey<String>('dish_log_${item.name}'),
                          tooltip: 'Log cooking',
                          onPressed: () => _logCookingForDish(item),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                        IconButton(
                          key: ValueKey<String>('dish_edit_${item.name}'),
                          tooltip: 'Edit dish',
                          onPressed: () => _editDish(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (item.proteins.isNotEmpty) ...<Widget>[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: item.proteins
                                .map((ProteinType protein) {
                                  return Chip(
                                    avatar: FaIcon(protein.icon, size: 12),
                                    label: Text(protein.label),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                })
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(_cookedCountText(item.cookedCount)),
                        const SizedBox(height: 4),
                        Text(_averageRatingText(item)),
                        const SizedBox(height: 2),
                        Text(_averageDurationText(item)),
                        const SizedBox(height: 12),
                        Text(
                          'Ingredients',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(_ingredientSummary(item)),
                        if (item.recipeUrl != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            'Recipe URL',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _handleRecipeUrlTap(item.recipeUrl!),
                            child: Text(
                              item.recipeUrl!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekPlanCard() {
    final WeekPlan? weekPlan = _selectedWeekPlan;
    final bool isCurrentWeek = _selectedWeekStart == _currentWeekStartKey();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Previous week',
                    onPressed: () => _moveSelectedWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Week plan',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _weekLabel(_selectedWeekStart),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next week',
                    onPressed: () => _moveSelectedWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: _editWeekPlan,
                    child: Text(weekPlan == null ? 'Create' : 'Edit'),
                  ),
                ],
              ),
              if (!isCurrentWeek)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedWeekStart = _currentWeekStartKey();
                      });
                    },
                    child: const Text('Jump to this week'),
                  ),
                ),
              if (weekPlan == null) ...<Widget>[
                const SizedBox(height: 6),
                const Text('No plan saved for this week yet.'),
              ] else ...<Widget>[
                const SizedBox(height: 6),
                ...weekPlan.entries.map((WeekPlanEntry entry) {
                  final FoodItem? item = _findFoodItemByName(entry.dishName);
                  return CheckboxListTile(
                    key: ValueKey<String>('week_entry_${entry.dishName}'),
                    value: entry.isCooked,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(entry.dishName),
                    subtitle: Text(
                      item == null
                          ? 'Dish missing'
                          : 'Portions: ${entry.portions}',
                    ),
                    onChanged: item == null
                        ? null
                        : (bool? value) {
                            _toggleWeekEntryCooked(entry, value ?? false);
                          },
                  );
                }),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      key: const ValueKey<String>('week_grocery_trip_button'),
                      onPressed: _openWeekGroceryTrip,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Week grocery trip'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final String nextWeekStart = _shiftWeekStartKey(
                          _selectedWeekStart,
                          1,
                        );
                        setState(() {
                          _upsertWeekPlan(
                            weekPlan.copyWith(
                              weekStart: nextWeekStart,
                              entries: weekPlan.entries
                                  .map((WeekPlanEntry entry) {
                                    return entry.copyWith(isCooked: false);
                                  })
                                  .toList(growable: false),
                            ),
                          );
                          _selectedWeekStart = nextWeekStart;
                        });
                        await _persistData();
                      },
                      child: const Text('Copy to next week'),
                    ),
                    OutlinedButton(
                      onPressed: _clearWeekPlan,
                      child: const Text('Clear week'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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
          _buildWeekPlanCard(),
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
            _buildWeekPlanCard(),
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
            _buildWeekPlanCard(),
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
                  return _buildDishCard(item, index + 1);
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
          AnimatedBuilder(
            animation: AppCloudSync.instance,
            builder: (BuildContext context, Widget? child) {
              final AppCloudSync cloudSync = AppCloudSync.instance;
              return IconButton(
                tooltip: 'Account & sync',
                icon: Icon(
                  !cloudSync.isConfigured
                      ? Icons.cloud_off_outlined
                      : cloudSync.hasActiveHousehold
                      ? Icons.cloud_done_outlined
                      : cloudSync.hasSession
                      ? Icons.cloud_queue_outlined
                      : Icons.cloud_outlined,
                ),
                onPressed: _showAccountAndSyncDialog,
              );
            },
          ),
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
  const GroceryTripPage({
    super.key,
    this.preloadWeekPlan = false,
    this.preloadWeekStart,
  });

  static const String routeName = '/grocery-trip';
  static const String weekRouteName = '/grocery-trip/week';

  final bool preloadWeekPlan;
  final String? preloadWeekStart;

  @override
  State<GroceryTripPage> createState() => _GroceryTripPageState();
}

class _GroceryTripPageState extends State<GroceryTripPage> {
  final FoodDataStore _dataStore = FoodDataStore();
  final List<FoodItem> _foodItems = <FoodItem>[];
  final List<RoutineFoodItem> _routineItems = <RoutineFoodItem>[];
  final Map<String, GroceryTripDishSelection> _selectedDishes =
      <String, GroceryTripDishSelection>{};
  final Set<String> _selectedRoutineItemIds = <String>{};
  final Map<String, TextEditingController> _portionControllers =
      <String, TextEditingController>{};
  final List<WeekPlan> _weekPlans = <WeekPlan>[];

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
      final FamilyEatingData data = await _dataStore.load();
      final List<FoodItem> loadedItems = List<FoodItem>.from(data.foodItems)
        ..sort((FoodItem a, FoodItem b) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      final List<RoutineFoodItem> routineItems =
          List<RoutineFoodItem>.from(data.routineItems)
            ..sort((RoutineFoodItem a, RoutineFoodItem b) {
              return a.ingredient.displayLabel.toLowerCase().compareTo(
                b.ingredient.displayLabel.toLowerCase(),
              );
            });
      if (!mounted) {
        return;
      }
      setState(() {
        _foodItems
          ..clear()
          ..addAll(loadedItems);
        _routineItems
          ..clear()
          ..addAll(routineItems);
        _weekPlans
          ..clear()
          ..addAll(data.weekPlans);
        _selectedRoutineItemIds.removeWhere((String id) {
          return !_routineItems.any((RoutineFoodItem item) => item.id == id);
        });
        if (widget.preloadWeekPlan) {
          _applyWeekPlanSelections(widget.preloadWeekStart);
        }
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

  Future<void> _persistData() async {
    try {
      await _dataStore.save(
        FamilyEatingData(
          foodItems: _foodItems,
          routineItems: _routineItems,
          weekPlans: _weekPlans,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save routine foods.')),
      );
    }
  }

  bool _isSelected(FoodItem item) => _selectedDishes.containsKey(item.name);

  WeekPlan? _weekPlanForStart(String? weekStart) {
    if (weekStart == null) {
      return null;
    }
    for (final WeekPlan plan in _weekPlans) {
      if (plan.weekStart == weekStart) {
        return plan;
      }
    }
    return null;
  }

  void _applyWeekPlanSelections(String? weekStart) {
    _selectedDishes.clear();
    for (final TextEditingController controller in _portionControllers.values) {
      controller.dispose();
    }
    _portionControllers.clear();
    final WeekPlan? weekPlan = _weekPlanForStart(weekStart);
    if (weekPlan == null) {
      return;
    }
    for (final WeekPlanEntry entry in weekPlan.entries) {
      FoodItem? matchingItem;
      for (final FoodItem item in _foodItems) {
        if (item.name == entry.dishName) {
          matchingItem = item;
          break;
        }
      }
      if (matchingItem == null) {
        continue;
      }
      _selectedDishes[matchingItem.name] = GroceryTripDishSelection(
        item: matchingItem,
        portions: entry.portions,
      );
      _portionControllers[matchingItem.name] = TextEditingController(
        text: entry.portions.toString(),
      );
    }
  }

  bool _isRoutineSelected(RoutineFoodItem item) {
    return _selectedRoutineItemIds.contains(item.id);
  }

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

  void _toggleRoutineSelection(RoutineFoodItem item) {
    setState(() {
      if (_selectedRoutineItemIds.contains(item.id)) {
        _selectedRoutineItemIds.remove(item.id);
      } else {
        _selectedRoutineItemIds.add(item.id);
      }
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

  void _accumulateIngredient({
    required IngredientEntry ingredient,
    required double factor,
    required Map<String, _IngredientAccumulator> scalableItems,
    required Map<String, int> textCounts,
    required Map<String, String> textLabels,
  }) {
    final _ParsedIngredient? parsed = ingredient._toParsedIngredient();
    if (parsed != null) {
      final _IngredientAccumulator accumulator = scalableItems.putIfAbsent(
        parsed.normalizedKey,
        () => _IngredientAccumulator(parsed),
      );
      accumulator.totalAmount += parsed.baseAmount * factor;
      return;
    }

    final String label = ingredient.displayLabel.trim();
    if (label.isEmpty) {
      return;
    }
    final String normalized = label.toLowerCase();
    textLabels.putIfAbsent(normalized, () => label);
    textCounts.update(normalized, (int count) => count + 1, ifAbsent: () => 1);
  }

  List<GroceryListItem> _buildGroceryListItems() {
    final Map<String, _IngredientAccumulator> scalableItems =
        <String, _IngredientAccumulator>{};
    final Map<String, int> textCounts = <String, int>{};
    final Map<String, String> textLabels = <String, String>{};

    for (final GroceryTripDishSelection selection in _selectedDishes.values) {
      final double factor = _portionFactor(selection);
      for (final IngredientEntry ingredient in selection.item.ingredients) {
        _accumulateIngredient(
          ingredient: ingredient,
          factor: factor,
          scalableItems: scalableItems,
          textCounts: textCounts,
          textLabels: textLabels,
        );
      }
    }

    for (final RoutineFoodItem item in _routineItems) {
      if (!_selectedRoutineItemIds.contains(item.id)) {
        continue;
      }
      _accumulateIngredient(
        ingredient: item.ingredient,
        factor: 1,
        scalableItems: scalableItems,
        textCounts: textCounts,
        textLabels: textLabels,
      );
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

  Future<IngredientEntry?> _showRoutineItemEditorDialog({
    IngredientEntry? initialValue,
  }) async {
    final _IngredientDraft draft = initialValue == null
        ? _IngredientDraft(name: '')
        : _IngredientDraft.fromEntry(initialValue);
    String? errorText;

    return showDialog<IngredientEntry>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                initialValue == null ? 'Add routine food' : 'Edit routine food',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: 88,
                          child: TextFormField(
                            initialValue: draft.amountInput,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                            ),
                            onChanged: (String value) {
                              draft.amountInput = value;
                              if (errorText != null) {
                                setDialogState(() {
                                  errorText = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: draft.unitKey,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None'),
                              ),
                              ..._IngredientUnit.values.map((
                                _IngredientUnit unit,
                              ) {
                                return DropdownMenuItem<String?>(
                                  value: unit.key,
                                  child: Text(unit.singularLabel),
                                );
                              }),
                            ],
                            onChanged: (String? value) {
                              setDialogState(() {
                                draft.unitKey = value;
                                errorText = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: draft.name,
                      decoration: const InputDecoration(
                        labelText: 'Food item',
                        hintText: 'e.g. bananas',
                      ),
                      onChanged: (String value) {
                        draft.name = value;
                        if (errorText != null) {
                          setDialogState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String? validation = _validateSingleRoutineDraft(
                      draft,
                    );
                    if (validation != null) {
                      setDialogState(() {
                        errorText = validation;
                      });
                      return;
                    }
                    Navigator.of(context).pop(draft.toIngredientEntry()!);
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

  String? _validateSingleRoutineDraft(_IngredientDraft draft) {
    if (draft.name.trim().isEmpty) {
      return 'Enter a food item name.';
    }
    final bool hasAmount = draft.amountInput.trim().isNotEmpty;
    if ((draft.unitKey ?? '').isNotEmpty && !hasAmount) {
      return 'Enter an amount when a unit is selected.';
    }
    if (hasAmount && _parseOptionalAmount(draft.amountInput) == null) {
      return 'Amount must be above 0.';
    }
    return null;
  }

  Future<void> _showRoutineItemManager() async {
    final List<RoutineFoodItem> draftItems = _routineItems
        .map(
          (RoutineFoodItem item) => item.copyWith(ingredient: item.ingredient),
        )
        .toList(growable: true);

    final List<RoutineFoodItem>? updatedItems =
        await showDialog<List<RoutineFoodItem>>(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                Future<void> addRoutineItem() async {
                  final IngredientEntry? entry =
                      await _showRoutineItemEditorDialog();
                  if (entry == null) {
                    return;
                  }
                  setDialogState(() {
                    draftItems.add(
                      RoutineFoodItem(id: _createLocalId(), ingredient: entry),
                    );
                  });
                }

                Future<void> editRoutineItem(int index) async {
                  final IngredientEntry? entry =
                      await _showRoutineItemEditorDialog(
                        initialValue: draftItems[index].ingredient,
                      );
                  if (entry == null) {
                    return;
                  }
                  setDialogState(() {
                    draftItems[index] = draftItems[index].copyWith(
                      ingredient: entry,
                    );
                  });
                }

                return AlertDialog(
                  title: const Text('Routine foods'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: addRoutineItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add routine food'),
                        ),
                        const SizedBox(height: 8),
                        if (draftItems.isEmpty)
                          const Text(
                            'No routine foods yet. Add staples you buy often.',
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: draftItems.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final RoutineFoodItem item = draftItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.ingredient.displayLabel),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: () => editRoutineItem(index),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: () {
                                          setDialogState(() {
                                            draftItems.removeAt(index);
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(List<RoutineFoodItem>.from(draftItems));
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        );

    if (updatedItems == null) {
      return;
    }

    setState(() {
      _routineItems
        ..clear()
        ..addAll(updatedItems);
      _routineItems.sort((RoutineFoodItem a, RoutineFoodItem b) {
        return a.ingredient.displayLabel.toLowerCase().compareTo(
          b.ingredient.displayLabel.toLowerCase(),
        );
      });
      _selectedRoutineItemIds.removeWhere((String id) {
        return !_routineItems.any((RoutineFoodItem item) => item.id == id);
      });
    });
    await _persistData();
  }

  String _dishIngredientSummary(FoodItem item) {
    if (item.ingredients.isEmpty) {
      return 'No ingredients listed';
    }
    return item.ingredients
        .map((IngredientEntry entry) => entry.displayLabel)
        .join(', ');
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
                    if (widget.preloadWeekPlan) ...<Widget>[
                      const SizedBox(height: 8),
                      const Text('Loaded from the saved week plan.'),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Routine foods',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: _showRoutineItemManager,
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    if (_routineItems.isEmpty)
                      const Text(
                        'No routine foods yet. Add staples you buy often.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _routineItems
                            .map((RoutineFoodItem item) {
                              return FilterChip(
                                selected: _isRoutineSelected(item),
                                label: Text(item.ingredient.displayLabel),
                                onSelected: (_) =>
                                    _toggleRoutineSelection(item),
                              );
                            })
                            .toList(growable: false),
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
                                    _dishIngredientSummary(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
