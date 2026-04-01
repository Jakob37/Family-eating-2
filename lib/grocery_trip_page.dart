part of 'main.dart';

enum GroceryTripDishSort {
  alpha('A-Z'),
  rating('Rating'),
  duration('Cook time'),
  cooked('Most cooked');

  const GroceryTripDishSort(this.label);

  final String label;
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
  final TextEditingController _dishSearchController = TextEditingController();
  final List<FoodItem> _foodItems = <FoodItem>[];
  final List<RoutineFoodItem> _routineItems = <RoutineFoodItem>[];
  final List<GroceryChecklistItem> _groceryChecklistItems =
      <GroceryChecklistItem>[];
  final List<InventoryItem> _inventoryItems = <InventoryItem>[];
  final Map<String, GroceryTripDishSelection> _selectedDishes =
      <String, GroceryTripDishSelection>{};
  final Set<String> _selectedRoutineItemIds = <String>{};
  final Map<String, TextEditingController> _portionControllers =
      <String, TextEditingController>{};
  final List<WeekPlan> _weekPlans = <WeekPlan>[];

  bool _isLoading = true;
  bool _isSummaryCollapsed = false;
  bool _isDishSearchVisible = false;
  String? _loadError;
  String _dishSearchQuery = '';
  DishFilter _activeFilter = DishFilter.empty;
  GroceryTripDishSort _sortMode = GroceryTripDishSort.alpha;

  @override
  void initState() {
    super.initState();
    _loadFoodItems();
  }

  @override
  void dispose() {
    _dishSearchController.dispose();
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
        _groceryChecklistItems
          ..clear()
          ..addAll(data.groceryChecklistItems);
        _inventoryItems
          ..clear()
          ..addAll(data.inventoryItems);
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
          groceryChecklistItems: _groceryChecklistItems,
          inventoryItems: _inventoryItems,
        ),
      );
      if (!mounted) {
        return;
      }
      final AppCloudSync cloudSync = AppCloudSync.instance;
      final String? syncError = cloudSync.lastSyncError;
      if (cloudSync.hasActiveHousehold && syncError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved locally. $syncError')));
      }
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

  bool get _hasActiveDishSearch => _dishSearchQuery.trim().isNotEmpty;

  void _setDishSearchQuery(String value) {
    setState(() {
      _dishSearchQuery = value;
    });
  }

  void _clearDishSearch() {
    _dishSearchController.clear();
    _setDishSearchQuery('');
  }

  bool _matchesDishSearch(FoodItem item) {
    final String query = _dishSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    if (item.name.toLowerCase().contains(query)) {
      return true;
    }
    return item.ingredients.any(
      (IngredientEntry entry) =>
          entry.displayLabel.toLowerCase().contains(query),
    );
  }

  bool _matchesFilter(FoodItem item, DishFilter filter) {
    if (filter.selectedCategories.isNotEmpty &&
        !filter.selectedCategories.contains(item.category)) {
      return false;
    }
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

  int _searchMatchScore(FoodItem item, String normalizedQuery) {
    final String normalizedName = item.name.toLowerCase();
    if (normalizedName.startsWith(normalizedQuery)) {
      return 0;
    }
    if (normalizedName
        .split(RegExp(r'\s+'))
        .any((String part) => part.startsWith(normalizedQuery))) {
      return 1;
    }
    return 2;
  }

  int _compareBySortMode(FoodItem a, FoodItem b) {
    switch (_sortMode) {
      case GroceryTripDishSort.alpha:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case GroceryTripDishSort.rating:
        final int ratingCompare = (b.averageRating ?? -1).compareTo(
          a.averageRating ?? -1,
        );
        if (ratingCompare != 0) {
          return ratingCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case GroceryTripDishSort.duration:
        final int durationCompare = (a.averageDurationMinutes ?? 1 << 30)
            .compareTo(b.averageDurationMinutes ?? 1 << 30);
        if (durationCompare != 0) {
          return durationCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case GroceryTripDishSort.cooked:
        final int cookedCompare = b.cookedCount.compareTo(a.cookedCount);
        if (cookedCompare != 0) {
          return cookedCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  }

  List<FoodItem> _visibleFoodItems() {
    final String normalizedQuery = _dishSearchQuery.trim().toLowerCase();
    final List<FoodItem> items = _foodItems
        .where((FoodItem item) => _matchesFilter(item, _activeFilter))
        .where(_matchesDishSearch)
        .toList(growable: false);
    items.sort((FoodItem a, FoodItem b) {
      if (normalizedQuery.isNotEmpty) {
        final int scoreCompare = _searchMatchScore(
          a,
          normalizedQuery,
        ).compareTo(_searchMatchScore(b, normalizedQuery));
        if (scoreCompare != 0) {
          return scoreCompare;
        }
      }
      return _compareBySortMode(a, b);
    });
    return items;
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

  void _openSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GroceryTripDishSort.values.map((GroceryTripDishSort mode) {
              final bool selected = mode == _sortMode;
              return ListTile(
                title: Text(mode.label),
                trailing: selected ? const Icon(Icons.check) : null,
                selected: selected,
                onTap: () {
                  setState(() {
                    _sortMode = mode;
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(growable: false),
          ),
        );
      },
    );
  }

  Future<DishFilter?> _showDishFilterDialog({
    required DishFilter initialFilter,
  }) async {
    Set<FoodCategory> selectedCategories = Set<FoodCategory>.from(
      initialFilter.selectedCategories,
    );
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
              title: const Text('Filter grocery trip dishes'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FoodCategory.values.map((FoodCategory category) {
                          final bool isSelected = selectedCategories.contains(
                            category,
                          );
                          return FilterChip(
                            label: Text(category.label),
                            selected: isSelected,
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  selectedCategories.add(category);
                                } else {
                                  selectedCategories.remove(category);
                                }
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Proteins',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ProteinType.values.map((ProteinType protein) {
                          final bool isSelected = selectedProteins.contains(
                            protein,
                          );
                          return FilterChip(
                            label: Text(protein.label),
                            selected: isSelected,
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  selectedProteins.add(protein);
                                } else {
                                  selectedProteins.remove(protein);
                                }
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Minimum rating',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
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
                        initialValue: minTimeInput,
                        keyboardType: TextInputType.number,
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
                        initialValue: maxTimeInput,
                        keyboardType: TextInputType.number,
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
                        selectedCategories: Set<FoodCategory>.from(
                          selectedCategories,
                        ),
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

  Widget _buildDishSearchBar() {
    final bool showSearch = _isDishSearchVisible || _hasActiveDishSearch;
    final int matchCount = _visibleFoodItems().length;
    final String normalizedQuery = _dishSearchQuery.trim();
    final String summary = normalizedQuery.isEmpty
        ? '$matchCount dishes'
        : matchCount == 1
        ? '1 match'
        : '$matchCount matches';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: !showSearch
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey<String>('grocery_dish_search_container'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>('grocery_dish_search_field'),
                    controller: _dishSearchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search grocery trip dishes',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _hasActiveDishSearch
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearDishSearch,
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _setDishSearchQuery,
                  ),
                  const SizedBox(height: 6),
                  Text(summary, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
    );
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

  String _selectionSummaryText(List<GroceryTripDishSelection> selections) {
    if (selections.isEmpty) {
      return 'Pick dishes below.';
    }
    return selections
        .map((GroceryTripDishSelection selection) => selection.item.name)
        .join(', ');
  }

  Widget _buildSummaryCard({
    required List<GroceryTripDishSelection> selections,
    required List<GroceryListItem> groceryItems,
  }) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = widget.preloadWeekPlan
        ? '${selections.length} selected - Loaded from saved week plan'
        : '${selections.length} selected';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
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
                            'Selected dishes',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      key: const ValueKey<String>('grocery_summary_toggle'),
                      onPressed: () {
                        setState(() {
                          _isSummaryCollapsed = !_isSummaryCollapsed;
                        });
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(_isSummaryCollapsed ? 'Show' : 'Hide'),
                    ),
                  ],
                ),
                if (!_isSummaryCollapsed) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _selectionSummaryText(selections),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>(
                          'get_ingredients_list_button',
                        ),
                        onPressed: groceryItems.isEmpty
                            ? null
                            : _showIngredientListDialog,
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                        ),
                        label: const Text('Ingredients'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showRoutineItemManager,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Routine foods'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_routineItems.isEmpty)
                    Text(
                      'No routine foods yet. Add staples you buy often.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _routineItems
                          .map((RoutineFoodItem item) {
                            return FilterChip(
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              selected: _isRoutineSelected(item),
                              label: Text(item.ingredient.displayLabel),
                              onSelected: (_) => _toggleRoutineSelection(item),
                            );
                          })
                          .toList(growable: false),
                    ),
                ],
              ],
            ),
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
      body = const Center(
        child: Text('Add dishes before planning a grocery trip.'),
      );
    } else {
      final List<GroceryTripDishSelection> selections = _currentSelections();
      final List<GroceryListItem> groceryItems = _buildGroceryListItems();
      final List<FoodItem> visibleFoodItems = _visibleFoodItems();

      body = Column(
        children: <Widget>[
          _buildSummaryCard(selections: selections, groceryItems: groceryItems),
          _buildDishSearchBar(),
          if (_activeFilter.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ..._buildActiveFilterChipsFrom(_activeFilter),
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
      appBar: AppBar(
        title: const Text('Grocery trip'),
        actions: <Widget>[
          IconButton(
            tooltip: _isDishSearchVisible || _hasActiveDishSearch
                ? 'Close search'
                : 'Search dishes',
            icon: Icon(
              _isDishSearchVisible || _hasActiveDishSearch
                  ? Icons.close
                  : Icons.search,
            ),
            onPressed: () {
              setState(() {
                if (_isDishSearchVisible || _hasActiveDishSearch) {
                  _isDishSearchVisible = false;
                  _clearDishSearch();
                } else {
                  _isDishSearchVisible = true;
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Filter dishes',
            icon: Icon(
              _activeFilter.hasActiveFilters
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: _openFilterMenu,
          ),
          IconButton(
            tooltip: 'Sort dishes',
            icon: const Icon(Icons.sort),
            onPressed: _openSortMenu,
          ),
        ],
      ),
      body: body,
    );
  }

  List<Widget> _buildActiveFilterChipsFrom(DishFilter filter) {
    return <Widget>[
      ...filter.selectedCategories.map(
        (FoodCategory category) => Chip(label: Text(category.label)),
      ),
      ...filter.selectedProteins.map(
        (ProteinType protein) => Chip(label: Text(protein.label)),
      ),
      if (filter.minRating > 0)
        Chip(label: Text('Min rating ${filter.minRating.toStringAsFixed(1)}')),
      if (filter.minCookingTimeMinutes != null)
        Chip(label: Text('Min ${filter.minCookingTimeMinutes} min')),
      if (filter.maxCookingTimeMinutes != null)
        Chip(label: Text('Max ${filter.maxCookingTimeMinutes} min')),
    ];
  }
}
