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
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
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
      final updatedItem = Item(
        id: item.id,
        name: nameController.text.trim(),
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        sortOrder: item.sortOrder,
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

  void showItemContextMenu(Item item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: clMenu,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(lw('Edit')),
            onTap: () {
              Navigator.pop(context);
              editItem(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(lw('Delete')),
            onTap: () {
              Navigator.pop(context);
              deleteItem(item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> sortAlphabetically() async {
    setState(() {
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      filteredItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    await db.updateItemsOrder(items);
    if (mounted) {
      showMessage(context, lw('Items sorted alphabetically'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lw('Items Dictionary')),
        actions: [
          if (items.isNotEmpty && searchController.text.isEmpty)
            IconButton(
              icon: const Icon(Icons.sort_by_alpha),
              onPressed: sortAlphabetically,
              tooltip: lw('Sort alphabetically'),
            ),
        ],
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
                        return Dismissible(
                          key: ValueKey(item.id),
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Swipe right - edit
                              editItem(item);
                              return false;
                            } else {
                              // Swipe left - delete with confirmation
                              return await showConfirmDialog(
                                context,
                                lw('Delete Item'),
                                lw('Are you sure you want to delete "%s" from dictionary? Items in shopping lists will be converted to manual entries.').replaceAll('%s', item.name),
                              );
                            }
                          },
                          onDismissed: (direction) async {
                            // Only called if confirmDismiss returns true (delete confirmed)
                            final database = await db.database;
                            await database.rawUpdate('''
                              UPDATE lists
                              SET
                                name = (SELECT name FROM items WHERE items.id = lists.item_id),
                                unit = (SELECT unit FROM items WHERE items.id = lists.item_id),
                                item_id = NULL
                              WHERE item_id = ?
                            ''', [item.id]);
                            await db.deleteItem(item.id!);
                            loadItems();
                            if (context.mounted) {
                              showMessage(context, lw('Item deleted from dictionary'));
                            }
                          },
                          child: ListTile(
                            key: ValueKey('tile_${item.id}'),
                            leading: const Icon(Icons.inventory_2),
                            title: Text(item.name),
                            subtitle: item.unit != null ? Text(item.unit!) : null,
                            onLongPress: () => showItemContextMenu(item),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: _listItemHorizontalPadding,
                              vertical: _listItemVerticalPadding,
                            ),
                          ),
                        );
                      },
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.zero,
                      itemCount: filteredItems.length,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = filteredItems.removeAt(oldIndex);
                          filteredItems.insert(newIndex, item);
                          // Update items list as well to keep them in sync
                          items = List.from(filteredItems);
                        });
                        await db.updateItemsOrder(filteredItems);
                      },
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Dismissible(
                          key: ValueKey(item.id),
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Swipe right - edit
                              editItem(item);
                              return false;
                            } else {
                              // Swipe left - delete with confirmation
                              return await showConfirmDialog(
                                context,
                                lw('Delete Item'),
                                lw('Are you sure you want to delete "%s" from dictionary? Items in shopping lists will be converted to manual entries.').replaceAll('%s', item.name),
                              );
                            }
                          },
                          onDismissed: (direction) async {
                            // Only called if confirmDismiss returns true (delete confirmed)
                            final database = await db.database;
                            await database.rawUpdate('''
                              UPDATE lists
                              SET
                                name = (SELECT name FROM items WHERE items.id = lists.item_id),
                                unit = (SELECT unit FROM items WHERE items.id = lists.item_id),
                                item_id = NULL
                              WHERE item_id = ?
                            ''', [item.id]);
                            await db.deleteItem(item.id!);
                            loadItems();
                            if (context.mounted) {
                              showMessage(context, lw('Item deleted from dictionary'));
                            }
                          },
                          child: ListTile(
                            key: ValueKey('tile_${item.id}'),
                            leading: const Icon(Icons.inventory_2),
                            title: Text(item.name),
                            subtitle: item.unit != null ? Text(item.unit!) : null,
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                            onLongPress: () => showItemContextMenu(item),
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: _listItemHorizontalPadding,
                              vertical: _listItemVerticalPadding,
                            ),
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