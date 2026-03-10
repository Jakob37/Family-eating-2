import 'dart:convert';

import 'package:family_food/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Adds a food item with proteins and baseline stats', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('No food items yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_name_field')),
      'Apples',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredients_field')),
      'Apple\nCinnamon',
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Chicken'));
    await tester.tap(find.widgetWithText(FilterChip, 'Egg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Apples'), findsOneWidget);
    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('Egg'), findsOneWidget);
    expect(find.text('Cooked 0 times'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('No cooking time logged'), findsOneWidget);
    expect(find.text('Recipe portions: 4'), findsOneWidget);
    expect(find.text('Ingredients: Apple, Cinnamon'), findsOneWidget);
  });

  testWidgets('Dish menu logs rating/time and updates ranking', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Pasta',
            'proteins': <String>['egg'],
            'ingredients': <String>[],
            'cookingLogs': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'name': 'Soup',
            'proteins': <String>['fish'],
            'ingredients': <String>[],
            'cookingLogs': <Map<String, dynamic>>[
              <String, dynamic>{
                'cookedAt': '2026-03-08T10:00:00.000Z',
                'rating': 4.0,
                'durationMinutes': 20,
              },
            ],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    double pastaY() => tester
        .getTopLeft(find.byKey(const ValueKey<String>('dish_card_Pasta')))
        .dy;
    double soupY() => tester
        .getTopLeft(find.byKey(const ValueKey<String>('dish_card_Soup')))
        .dy;

    expect(pastaY(), greaterThan(soupY()));

    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Pasta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Pasta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I cooked this'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cooked 2 times'), findsOneWidget);
    expect(find.text('Avg rating: 3.0/5'), findsOneWidget);
    expect(find.text('Avg time: 30.0 min'), findsOneWidget);
    expect(pastaY(), lessThan(soupY()));
  });

  testWidgets('Filtering menu applies protein, rating, and time constraints', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Fish Curry',
            'proteins': <String>['fish'],
            'ingredients': <String>['Fish', 'Curry paste'],
            'cookingLogs': <Map<String, dynamic>>[
              <String, dynamic>{
                'cookedAt': '2026-03-08T10:00:00.000Z',
                'rating': 4.5,
                'durationMinutes': 40,
              },
            ],
          },
          <String, dynamic>{
            'name': 'Chicken Pasta',
            'proteins': <String>['chicken'],
            'ingredients': <String>['Chicken'],
            'cookingLogs': <Map<String, dynamic>>[
              <String, dynamic>{
                'cookedAt': '2026-03-08T11:00:00.000Z',
                'rating': 3.5,
                'durationMinutes': 25,
              },
            ],
          },
          <String, dynamic>{
            'name': 'Tofu Bowl',
            'proteins': <String>['tofu'],
            'ingredients': <String>['Tofu'],
            'cookingLogs': <Map<String, dynamic>>[
              <String, dynamic>{
                'cookedAt': '2026-03-08T12:00:00.000Z',
                'rating': 4.0,
                'durationMinutes': 35,
              },
            ],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter dishes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Fish'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('min_rating_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4.0+').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('min_time_field')),
      '30',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('max_time_field')),
      '50',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Fish Curry'), findsOneWidget);
    expect(find.text('Chicken Pasta'), findsNothing);
    expect(find.text('Tofu Bowl'), findsNothing);
  });

  testWidgets('Can edit a dish and manage ingredients list', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 5,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Soup',
            'proteins': <String>['fish'],
            'ingredients': <String>['Water'],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Soup')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit dish'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_name_field')),
      'Tomato Soup',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredients_field')),
      'Tomato\nOnion\nGarlic',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('default_portions_field')),
      '6',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tomato Soup'), findsOneWidget);
    expect(find.text('Soup'), findsNothing);
    expect(find.text('Recipe portions: 6'), findsOneWidget);
    expect(find.text('Ingredients: Tomato, Onion, Garlic'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('family_eating.food_data');
    expect(stored, isNotNull);
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored!) as Map,
    );
    final List<dynamic> items = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> firstItem = Map<String, dynamic>.from(
      items.first as Map,
    );
    expect(firstItem['name'], 'Tomato Soup');
    expect(firstItem['defaultPortions'], 6);
    expect(firstItem['ingredients'], <String>['Tomato', 'Onion', 'Garlic']);
  });

  testWidgets('Grocery trip builds copyable ingredient list from selections', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 6,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Bolognese',
            'proteins': <String>['meat'],
            'defaultPortions': 4,
            'ingredients': <String>['500g minced meat', '1 onion', 'Salt'],
            'cookingLogs': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'name': 'Meatballs',
            'proteins': <String>['meat'],
            'defaultPortions': 2,
            'ingredients': <String>['250g minced meat', '2 onion', 'Pepper'],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open_grocery_trip_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grocery trip'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_toggle_Bolognese')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_toggle_Meatballs')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('grocery_portions_Bolognese')),
      '8',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('get_ingredients_list_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.25kg minced meat'), findsOneWidget);
    expect(find.text('4 onions'), findsOneWidget);
    expect(find.text('Salt'), findsOneWidget);
    expect(find.text('Pepper'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('grocery_item_Pepper')));
    await tester.pumpAndSettle();

    final SelectableText output = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('selected_ingredients_text')),
    );
    expect(output.data, contains('1.25kg minced meat'));
    expect(output.data, contains('4 onions'));
    expect(output.data, contains('Salt'));
    expect(output.data, isNot(contains('Pepper')));
  });

  testWidgets(
    'Grocery trip normalizes fractions, packages, volumes, and spoon units',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'family_eating.food_data': jsonEncode(<String, dynamic>{
          'schemaVersion': 6,
          'foodItems': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Tray Bake',
              'proteins': <String>['cheese'],
              'defaultPortions': 2,
              'ingredients': <String>[
                '1/2 kg potatoes',
                '2 packages tortillas',
                '1 tbsp oil',
                '1 onion',
                '1 1/2 dl cream',
              ],
              'cookingLogs': <Map<String, dynamic>>[],
            },
            <String, dynamic>{
              'name': 'Soup',
              'proteins': <String>['beans'],
              'defaultPortions': 4,
              'ingredients': <String>[
                '500g potatoes',
                '1 pkg tortilla',
                '3 tsp oil',
                '2 onions',
                '250 ml cream',
              ],
              'cookingLogs': <Map<String, dynamic>>[],
            },
          ],
        }),
      });

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('open_grocery_trip_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('grocery_toggle_Tray Bake')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('grocery_toggle_Soup')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('grocery_portions_Tray Bake')),
        '4',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('get_ingredients_list_button')),
      );
      await tester.pumpAndSettle();

      final SelectableText output = tester.widget<SelectableText>(
        find.byKey(const ValueKey<String>('selected_ingredients_text')),
      );
      expect(output.data, contains('1.5kg potatoes'));
      expect(output.data, contains('5 packages tortillas'));
      expect(output.data, contains('3 tbsp oil'));
      expect(output.data, contains('4 onions'));
      expect(output.data, contains('5.5dl cream'));
    },
  );

  testWidgets('Migrates legacy food names automatically', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_names': <String>['Legacy Soup'],
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Legacy Soup'), findsOneWidget);
    expect(find.text('Cooked 0 times'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('No cooking time logged'), findsOneWidget);
    expect(find.text('No proteins selected'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? migrated = prefs.getString('family_eating.food_data');
    expect(migrated, isNotNull);

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(migrated!) as Map,
    );
    expect(payload['schemaVersion'], FoodDataMigrator.currentVersion);
    expect(prefs.getStringList('family_eating.food_names'), isNull);
  });

  testWidgets('Migrates schema version 2 data to current version', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 2,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Old Dish',
            'proteins': <String>['chicken'],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Old Dish'), findsOneWidget);
    expect(find.text('Cooked 0 times'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? migrated = prefs.getString('family_eating.food_data');
    expect(migrated, isNotNull);

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(migrated!) as Map,
    );
    expect(payload['schemaVersion'], FoodDataMigrator.currentVersion);
    final List<dynamic> foodItems = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> firstItem = Map<String, dynamic>.from(
      foodItems.first as Map,
    );
    expect(firstItem['cookingLogs'], isEmpty);
    expect(firstItem['ingredients'], isEmpty);
  });

  testWidgets('Migrates schema version 3 data and preserves cooked count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 3,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Old Favorite',
            'proteins': <String>['fish'],
            'cookedCount': 2,
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Old Favorite'), findsOneWidget);
    expect(find.text('Cooked 2 times'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? migrated = prefs.getString('family_eating.food_data');
    expect(migrated, isNotNull);

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(migrated!) as Map,
    );
    expect(payload['schemaVersion'], FoodDataMigrator.currentVersion);
    final List<dynamic> foodItems = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> firstItem = Map<String, dynamic>.from(
      foodItems.first as Map,
    );
    expect((firstItem['cookingLogs'] as List<dynamic>).length, 2);
    expect(firstItem['ingredients'], isEmpty);
  });

  testWidgets('Migrates schema version 4 data and adds ingredients list', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 4,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Legacy Four',
            'proteins': <String>['egg'],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Legacy Four'), findsOneWidget);
    expect(find.text('No ingredients listed'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? migrated = prefs.getString('family_eating.food_data');
    expect(migrated, isNotNull);

    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(migrated!) as Map,
    );
    expect(payload['schemaVersion'], FoodDataMigrator.currentVersion);
    final List<dynamic> foodItems = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> firstItem = Map<String, dynamic>.from(
      foodItems.first as Map,
    );
    expect(firstItem['ingredients'], isEmpty);
  });

  testWidgets('Recovers from malformed stored payload', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': 'not-valid-json',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Could not load saved food items.'), findsNothing);
    expect(find.text('No food items yet. Tap + to add one.'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('family_eating.food_data'), isNull);
  });
}
