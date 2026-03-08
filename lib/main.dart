import 'package:flutter/material.dart';

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _foodItems = <String>[];

  Future<void> _addFoodItem() async {
    String draftValue = '';
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add food item'),
          content: TextField(
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'e.g. Pasta'),
            onSubmitted: (String submittedValue) {
              Navigator.of(context).pop(submittedValue);
            },
            onChanged: (String changedValue) {
              draftValue = changedValue;
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftValue),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    final String? trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return;
    }

    setState(() {
      _foodItems.add(trimmedValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _foodItems.isEmpty
          ? const Center(child: Text('No food items yet. Tap + to add one.'))
          : ListView.separated(
              itemCount: _foodItems.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final String item = _foodItems[index];
                return ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(item),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFoodItem,
        tooltip: 'Add food item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
