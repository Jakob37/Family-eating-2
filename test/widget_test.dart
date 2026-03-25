import 'dart:convert';

import 'package:family_food/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _weekStartKey(DateTime value) {
  final DateTime localMidnight = DateTime(value.year, value.month, value.day);
  final int daysFromMonday = localMidnight.weekday - DateTime.monday;
  final DateTime monday = localMidnight.subtract(
    Duration(days: daysFromMonday),
  );
  final String month = monday.month.toString().padLeft(2, '0');
  final String day = monday.day.toString().padLeft(2, '0');
  return '${monday.year}-$month-$day';
}

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
    await tester.tap(find.widgetWithText(FilterChip, 'Chicken'));
    await tester.tap(find.widgetWithText(FilterChip, 'Egg'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_0')),
      'Apple',
    );
    await tester.ensureVisible(find.text('Add row'));
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_1')),
      'Cinnamon',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Apples'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Apples')));
    await tester.pumpAndSettle();
    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('Egg'), findsOneWidget);
    expect(find.text('Cooked 0 times'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('No cooking time logged'), findsOneWidget);
    expect(find.text('Apple, Cinnamon'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey<String>('week_plan_toggle')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('dish_card_Soup')),
      200,
    );
    await tester.pumpAndSettle();

    double pastaY() => tester
        .getTopLeft(find.byKey(const ValueKey<String>('dish_card_Pasta')))
        .dy;
    double soupY() => tester
        .getTopLeft(find.byKey(const ValueKey<String>('dish_card_Soup')))
        .dy;

    expect(pastaY(), greaterThan(soupY()));

    await tester.tap(find.byKey(const ValueKey<String>('dish_log_Pasta')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '30',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('dish_log_Pasta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Pasta')));
    await tester.pumpAndSettle();
    expect(find.text('Cooked 2 times'), findsOneWidget);
    expect(find.text('Avg rating: 3.0/5'), findsOneWidget);
    expect(find.text('Avg time: 30.0 min'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Pasta')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('dish_card_Soup')),
      200,
    );
    await tester.pumpAndSettle();
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
    await tester.drag(
      find.byKey(const ValueKey<String>('min_rating_slider')),
      const Offset(240, 0),
    );
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

  testWidgets('Dish search is toggleable, filters the list, and can clear', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Bolognese',
            'proteins': <String>['meat'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 4,
          },
          <String, dynamic>{
            'name': 'Tomato Soup',
            'proteins': <String>['fish'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 2,
          },
          <String, dynamic>{
            'name': 'Taco Tray',
            'proteins': <String>['chicken'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 3,
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dish_search_field')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('toggle_dish_search_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dish_search_field')),
      findsOneWidget,
    );
    expect(find.text('3 dishes'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_search_field')),
      'soup',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 match'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dish_card_Tomato Soup')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dish_card_Bolognese')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dish_card_Taco Tray')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_search_field')),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No dishes match "zzz".'), findsOneWidget);
    expect(find.text('0 matches'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('3 dishes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dish_card_Bolognese')),
      findsOneWidget,
    );
    expect(find.text('No dishes match "zzz".'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('toggle_dish_search_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('dish_search_field')),
      findsNothing,
    );
  });

  testWidgets('Can add a dessert and filter by category', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Pasta',
            'proteins': <String>['egg'],
            'ingredients': <String>['Pasta'],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_name_field')),
      'Brownies',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_category_dessert')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Brownies'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> items = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> brownies = items
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .firstWhere((Map<String, dynamic> item) => item['name'] == 'Brownies');
    expect(brownies['category'], 'dessert');
    expect(brownies['proteins'], isEmpty);

    await tester.tap(find.byTooltip('Filter dishes'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_filter_category_dessert')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Brownies'), findsOneWidget);
    expect(find.text('Pasta'), findsNothing);
  });

  testWidgets('Can export and import app data as JSON', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 11,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Pasta',
            'category': 'main',
            'proteins': <String>['egg'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 4,
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[],
        'groceryChecklistItems': <Map<String, dynamic>>[],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Pasta'), findsOneWidget);

    await tester.tap(find.byTooltip('Account & sync'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open_json_export_button')),
    );
    await tester.pumpAndSettle();

    final SelectableText exportText = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('json_export_text')),
    );
    expect(exportText.data, contains('"schemaVersion": 11'));
    expect(exportText.data, contains('"Pasta"'));

    await tester.tap(
      find.byKey(const ValueKey<String>('close_json_export_button')),
    );
    await tester.pumpAndSettle();

    final String replacementJson = jsonEncode(<String, dynamic>{
      'schemaVersion': 11,
      'foodItems': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Imported Dish',
          'category': 'dessert',
          'proteins': <String>[],
          'ingredients': <Map<String, dynamic>>[],
          'cookingLogs': <Map<String, dynamic>>[],
          'defaultPortions': 6,
        },
      ],
      'routineItems': <Map<String, dynamic>>[],
      'weekPlans': <Map<String, dynamic>>[],
      'groceryChecklistItems': <Map<String, dynamic>>[],
    });

    await tester.tap(
      find.byKey(const ValueKey<String>('open_json_import_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('json_import_field')),
      replacementJson,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm_json_import_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('JSON imported successfully.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('close_account_sync_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imported Dish'), findsOneWidget);
    expect(find.text('Pasta'), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> items = payload['foodItems'] as List<dynamic>;
    expect(items, hasLength(1));
    expect(
      Map<String, dynamic>.from(items.first as Map)['name'],
      'Imported Dish',
    );
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
    await tester.tap(find.byKey(const ValueKey<String>('dish_edit_Soup')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_name_field')),
      'Tomato Soup',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_0')),
      'Tomato',
    );
    await tester.ensureVisible(find.text('Add row'));
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_1')),
      'Onion',
    );
    await tester.ensureVisible(find.text('Add row'));
    await tester.tap(find.text('Add row'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_2')),
      'Garlic',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('default_portions_field')),
      '6',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tomato Soup'), findsOneWidget);
    expect(find.text('Soup'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_card_Tomato Soup')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tomato, Onion, Garlic'), findsOneWidget);

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
    expect(firstItem['ingredients'], <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Tomato', 'amount': null, 'unitKey': null},
      <String, dynamic>{'name': 'Onion', 'amount': null, 'unitKey': null},
      <String, dynamic>{'name': 'Garlic', 'amount': null, 'unitKey': null},
    ]);
  });

  testWidgets('Can edit a dish directly from the week plan', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Soup',
            'proteins': <String>['fish'],
            'defaultPortions': 2,
            'ingredients': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'Water',
                'amount': null,
                'unitKey': null,
              },
            ],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[
          <String, dynamic>{
            'weekStart': _weekStartKey(DateTime.now()),
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{
                'dishName': 'Soup',
                'portions': 2,
                'isCooked': false,
              },
            ],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('week_entry_Soup')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('week_entry_edit_Soup')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('dish_name_field')),
      'Tomato Soup',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ingredient_name_0')),
      'Tomato',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('week_entry_Tomato Soup')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('week_entry_Soup')), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> items = payload['foodItems'] as List<dynamic>;
    final Map<String, dynamic> firstItem = Map<String, dynamic>.from(
      items.first as Map,
    );
    expect(firstItem['name'], 'Tomato Soup');

    final List<dynamic> weekPlans = payload['weekPlans'] as List<dynamic>;
    final Map<String, dynamic> weekPlan = Map<String, dynamic>.from(
      weekPlans.first as Map,
    );
    final List<dynamic> entries = weekPlan['entries'] as List<dynamic>;
    final Map<String, dynamic> firstEntry = Map<String, dynamic>.from(
      entries.first as Map,
    );
    expect(firstEntry['dishName'], 'Tomato Soup');
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

  testWidgets('Week plan persists cooked state and prefills grocery trip', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 9,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Bolognese',
            'proteins': <String>['meat'],
            'defaultPortions': 4,
            'ingredients': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'minced meat',
                'amount': 500,
                'unitKey': 'g',
              },
            ],
            'cookingLogs': <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'name': 'Soup',
            'proteins': <String>['fish'],
            'defaultPortions': 2,
            'ingredients': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'onion', 'amount': 2, 'unitKey': null},
            ],
            'cookingLogs': <Map<String, dynamic>>[],
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlan': <String, dynamic>{
          'entries': <Map<String, dynamic>>[
            <String, dynamic>{
              'dishName': 'Bolognese',
              'portions': 8,
              'isCooked': false,
            },
            <String, dynamic>{
              'dishName': 'Soup',
              'portions': 2,
              'isCooked': false,
            },
          ],
        },
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('week_entry_Bolognese')),
      findsOneWidget,
    );
    expect(find.text('Portions: 8'), findsNothing);
    expect(find.text('Portions: 2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('week_plan_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('week_entry_Bolognese')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('week_plan_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('week_entry_Bolognese')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('week_entry_Bolognese')),
    );
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> weekPlans = payload['weekPlans'] as List<dynamic>;
    final Map<String, dynamic> weekPlan = Map<String, dynamic>.from(
      weekPlans.first as Map,
    );
    final List<dynamic> entries = weekPlan['entries'] as List<dynamic>;
    final Map<String, dynamic> bologneseEntry = Map<String, dynamic>.from(
      entries.first as Map,
    );
    expect(bologneseEntry['isCooked'], true);

    await tester.tap(
      find.byKey(const ValueKey<String>('week_grocery_trip_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected dishes'), findsOneWidget);
    expect(
      find.text('2 selected - Loaded from saved week plan'),
      findsOneWidget,
    );
    expect(find.text('Bolognese, Soup'), findsOneWidget);
    expect(find.text('Bolognese (8), Soup (2)'), findsNothing);
    expect(find.text('Selected'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_summary_toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ingredients'), findsNothing);
    expect(find.text('Bolognese, Soup'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_summary_toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ingredients'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('get_ingredients_list_button')),
    );
    await tester.pumpAndSettle();

    final SelectableText output = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('selected_ingredients_text')),
    );
    expect(output.data, contains('1kg minced meat'));
    expect(output.data, contains('2 onions'));
  });

  testWidgets('Right swipe adds a dish to This week plan', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Swipe Dish',
            'proteins': <String>['egg'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 3,
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey<String>('dish_card_Swipe Dish')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Added Swipe Dish to This week.'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> weekPlans = payload['weekPlans'] as List<dynamic>;
    expect(weekPlans, hasLength(1));
    final Map<String, dynamic> firstPlan = Map<String, dynamic>.from(
      weekPlans.first as Map,
    );
    final List<dynamic> entries = firstPlan['entries'] as List<dynamic>;
    expect(entries, hasLength(1));
    expect(
      Map<String, dynamic>.from(entries.first as Map)['dishName'],
      'Swipe Dish',
    );
  });

  testWidgets('Can navigate between saved weeks', (WidgetTester tester) async {
    final String currentWeek = _weekStartKey(DateTime.now());
    final String previousWeek = _weekStartKey(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Current Dish',
            'proteins': <String>['egg'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 4,
          },
          <String, dynamic>{
            'name': 'Previous Dish',
            'proteins': <String>['fish'],
            'ingredients': <Map<String, dynamic>>[],
            'cookingLogs': <Map<String, dynamic>>[],
            'defaultPortions': 2,
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[
          <String, dynamic>{
            'weekStart': currentWeek,
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{
                'dishName': 'Current Dish',
                'portions': 4,
                'isCooked': false,
              },
            ],
          },
          <String, dynamic>{
            'weekStart': previousWeek,
            'entries': <Map<String, dynamic>>[
              <String, dynamic>{
                'dishName': 'Previous Dish',
                'portions': 2,
                'isCooked': true,
              },
            ],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('week_entry_Current Dish')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('week_entry_Previous Dish')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();

    expect(find.text('Last week - 1 dishes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('week_entry_Previous Dish')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('week_entry_Current Dish')),
      findsNothing,
    );
  });

  testWidgets('Week planner reuses full filtering interface', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_data': jsonEncode(<String, dynamic>{
        'schemaVersion': 10,
        'foodItems': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Fish Curry',
            'proteins': <String>['fish'],
            'ingredients': <Map<String, dynamic>>[],
            'defaultPortions': 4,
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
            'ingredients': <Map<String, dynamic>>[],
            'defaultPortions': 4,
            'cookingLogs': <Map<String, dynamic>>[
              <String, dynamic>{
                'cookedAt': '2026-03-08T11:00:00.000Z',
                'rating': 3.5,
                'durationMinutes': 25,
              },
            ],
          },
        ],
        'routineItems': <Map<String, dynamic>>[],
        'weekPlans': <Map<String, dynamic>>[],
      }),
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create week plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Fish'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('min_rating_slider')),
      const Offset(240, 0),
    );
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

    final Finder dialogFinder = find.byType(AlertDialog).first;
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Fish Curry')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Chicken Pasta')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('week_planner_select_Fish Curry')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Chicken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: dialogFinder, matching: find.text('Fish Curry')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogFinder, matching: find.text('Chicken Pasta')),
      findsOneWidget,
    );
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

  testWidgets('Groceries tab persists checklist items and clears completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('grocery_checklist_field')),
      'Milk',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_checklist_add_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('grocery_checklist_field')),
      'Bread',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_checklist_add_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('grocery_checklist_item_Milk')),
    );
    await tester.pumpAndSettle();

    final double breadY = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('grocery_checklist_item_Bread')),
        )
        .dy;
    final double milkY = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('grocery_checklist_item_Milk')),
        )
        .dy;
    expect(breadY, lessThan(milkY));

    await tester.tap(
      find.byKey(
        const ValueKey<String>('clear_completed_grocery_items_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String stored = prefs.getString('family_eating.food_data')!;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      jsonDecode(stored) as Map,
    );
    final List<dynamic> groceryChecklistItems =
        payload['groceryChecklistItems'] as List<dynamic>;
    expect(groceryChecklistItems, hasLength(1));
    expect(
      Map<String, dynamic>.from(groceryChecklistItems.first as Map)['label'],
      'Bread',
    );
  });

  testWidgets('Migrates legacy food names automatically', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'family_eating.food_names': <String>['Legacy Soup'],
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Legacy Soup'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_card_Legacy Soup')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cooked 0 times'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('No cooking time logged'), findsOneWidget);

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
    await tester.tap(find.byKey(const ValueKey<String>('dish_card_Old Dish')));
    await tester.pumpAndSettle();
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
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_card_Old Favorite')),
    );
    await tester.pumpAndSettle();
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
    await tester.tap(
      find.byKey(const ValueKey<String>('dish_card_Legacy Four')),
    );
    await tester.pumpAndSettle();
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
