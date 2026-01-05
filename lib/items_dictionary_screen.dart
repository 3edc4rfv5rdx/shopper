import 'package:flutter/material.dart';
import 'database.dart';
import 'items.dart';
import 'globals.dart';

// List spacing constants
const double _searchPadding = 8.0; // padding around search field
const double _dialogFieldSpacing = 16.0; // spacing between dialog fields
const double _listItemVerticalPadding = 2.0; // vertical padding for list items
const double _listItemHorizontalPadding = 16.0; // horizontal padding for list items

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
      // Apply current search filter after loading
      if (searchController.text.isEmpty) {
        filteredItems = data;
      } else {
        filteredItems = data
            .where((item) =>
                item.name.toLowerCase().contains(searchController.text.toLowerCase()))
            .toList();
      }
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
        title: Text(lw('Add Item')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: lw('Item name'),
                hintText: lw('e.g. Milk, Bread'),
              ),
              autofocus: true,
            ),
            const SizedBox(height: _dialogFieldSpacing),
            TextField(
              controller: unitController,
              decoration: InputDecoration(
                labelText: lw('Unit'),
                hintText: lw('e.g. kg, pcs, liter'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lw('Add')),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      // Check for duplicates (case-insensitive)
      final itemName = nameController.text.trim();
      final duplicate = items.any((item) =>
          item.name.toLowerCase() == itemName.toLowerCase());

      if (duplicate) {
        if (mounted) {
          showMessage(
            context,
            '${lw('Item')} "$itemName" ${lw('already exists in dictionary')}',
          );
        }
        return;
      }

      final newItem = Item(
        name: capitalizeFirst(nameController.text.trim()),
        unit: unitController.text.isEmpty ? null : unitController.text,
        sortOrder: items.length,
      );
      await db.insertItem(newItem);
      loadItems();
      if (mounted) {
        showMessage(context, lw('Item added to dictionary'));
      }
    }
  }

  Future<void> editItem(Item item) async {
    final nameController = TextEditingController(text: item.name);
    final unitController = TextEditingController(text: item.unit ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Edit Item')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: lw('Item name')),
              autofocus: true,
            ),
            const SizedBox(height: _dialogFieldSpacing),
            TextField(
              controller: unitController,
              decoration: InputDecoration(labelText: lw('Unit')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lw('Save')),
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
        showMessage(context, lw('Item updated'));
      }
    }
  }

  Future<void> deleteItem(Item item) async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Delete Item'),
      lw('Are you sure you want to delete "%s" from dictionary? Items in shopping lists will be converted to manual entries.').replaceAll('%s', item.name),
    );

    if (confirmed) {
      // First, convert all list items using this item to manual entries
      final database = await db.database;
      await database.rawUpdate('''
        UPDATE lists
        SET
          name = (SELECT name FROM items WHERE items.id = lists.item_id),
          unit = (SELECT unit FROM items WHERE items.id = lists.item_id),
          item_id = NULL
        WHERE item_id = ?
      ''', [item.id]);

      // Then delete the item from dictionary
      await db.deleteItem(item.id!);
      loadItems();
      if (mounted) {
        showMessage(context, lw('Item deleted from dictionary'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lw('Items Dictionary')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(
              left: _searchPadding,
              right: _searchPadding,
              top: _searchPadding,
              bottom: 4,
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: lw('Search items...'),
                prefixIcon: const Icon(Icons.search),
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
                        ? lw('No items in dictionary yet. Add one using the + button.')
                        : '${lw('No items found for')} "${searchController.text}"',
                    textAlign: TextAlign.center,
                  ),
                )
              : searchController.text.isNotEmpty
                  ? ListView.builder(
                      padding: EdgeInsets.zero,
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
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: _listItemHorizontalPadding,
                            vertical: _listItemVerticalPadding,
                          ),
                        );
                      },
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filteredItems.length,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = filteredItems.removeAt(oldIndex);
                          filteredItems.insert(newIndex, item);
                        });
                        await db.updateItemsOrder(filteredItems);
                      },
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          leading: const Icon(Icons.inventory_2),
                          title: Text(item.name),
                          subtitle: item.unit != null ? Text(item.unit!) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteItem(item),
                              ),
                              const Icon(Icons.drag_handle),
                            ],
                          ),
                          onTap: () => editItem(item),
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: _listItemHorizontalPadding,
                            vertical: _listItemVerticalPadding,
                          ),
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