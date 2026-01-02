import 'package:flutter/material.dart';
import 'database.dart';
import 'items.dart';
import 'globals.dart';

class ItemsDictionaryScreen extends StatefulWidget {
  const ItemsDictionaryScreen({super.key});

  @override
  State<ItemsDictionaryScreen> createState() => _ItemsDictionaryScreenState();
}

class _ItemsDictionaryScreenState extends State<ItemsDictionaryScreen> {
  final db = DatabaseHelper.instance;
  List<Item> items = [];
  List<Item> filteredItems = [];
  bool isLoading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    setState(() => isLoading = true);
    final data = await db.getItems();
    setState(() {
      items = data;
      filteredItems = data;
      isLoading = false;
    });
  }

  void filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredItems = items;
      } else {
        filteredItems = items
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> addItem() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g. Milk, Bread',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'e.g. kg, pcs, liter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newItem = Item(
        name: nameController.text,
        unit: unitController.text.isEmpty ? null : unitController.text,
      );
      await db.insertItem(newItem);
      loadItems();
      if (mounted) {
        showMessage(context, 'Item added to dictionary');
      }
    }
  }

  Future<void> editItem(Item item) async {
    final nameController = TextEditingController(text: item.name);
    final unitController = TextEditingController(text: item.unit ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final updatedItem = item.copyWith(
        name: nameController.text,
        unit: unitController.text.isEmpty ? null : unitController.text,
      );
      await db.updateItem(updatedItem);
      loadItems();
      if (mounted) {
        showMessage(context, 'Item updated');
      }
    }
  }

  Future<void> deleteItem(Item item) async {
    final confirmed = await showConfirmDialog(
      context,
      'Delete Item',
      'Are you sure you want to delete "${item.name}"? This will not affect existing shopping lists.',
    );

    if (confirmed) {
      await db.deleteItem(item.id!);
      loadItems();
      if (mounted) {
        showMessage(context, 'Item deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Items Dictionary'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: filterItems,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredItems.isEmpty
              ? Center(
                  child: Text(
                    searchController.text.isEmpty
                        ? 'No items in dictionary yet.\nAdd one using the + button.'
                        : 'No items found for "${searchController.text}"',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(item.name),
                      subtitle: item.unit != null ? Text(item.unit!) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => deleteItem(item),
                      ),
                      onTap: () => editItem(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}