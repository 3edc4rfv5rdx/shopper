import 'package:flutter/material.dart';
import 'database.dart';
import 'place.dart';
import 'list.dart';
import 'items.dart';
import 'globals.dart';

class ListScreen extends StatefulWidget {
  final Place place;

  const ListScreen({super.key, required this.place});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final db = DatabaseHelper.instance;
  List<ListItem> listItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadListItems();
  }

  Future<void> loadListItems() async {
    setState(() => isLoading = true);
    final data = await db.getListItems(widget.place.id!);
    setState(() {
      listItems = data;
      isLoading = false;
    });
  }

  Future<void> addItem() async {
    final result = await showDialog<ListItem>(
      context: context,
      builder: (context) => AddItemDialog(
        placeId: widget.place.id!,
        existingItems: listItems
      ),
    );

    if (result != null) {
      await db.insertListItem(result);
      loadListItems();
    }
  }

  Future<void> togglePurchased(ListItem item) async {
    final updated = item.copyWith(isPurchased: !item.isPurchased);
    await db.updateListItem(updated);
    loadListItems();
  }

  Future<void> deleteItem(ListItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Delete Item'),
      '${lw('Are you sure you want to delete')} "${item.displayName}"?',
    );

    if (confirmed) {
      await db.deleteListItem(item.id!);
      loadListItems();
    }
  }

  Future<void> deletePurchased() async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Clear Purchased'),
      lw('Delete all purchased items from this list?'),
    );

    if (confirmed) {
      await db.deletePurchasedItems(widget.place.id!);
      loadListItems();
    }
  }

  Future<void> addToItemsDictionary(ListItem listItem) async {
    if (listItem.itemId != null) {
      if (mounted) {
        showMessage(context, lw('Item is already in dictionary'));
      }
      return;
    }

    final newItem = Item(
      name: listItem.name!,
      unit: listItem.unit,
    );
    final itemId = await db.insertItem(newItem);

    // Update list item to reference the new item
    final updated = listItem.copyWith(
      itemId: itemId,
      name: null,
      unit: null,
    );
    await db.updateListItem(updated);
    loadListItems();
    if (mounted) {
      showMessage(context, lw('Added to items dictionary'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpurchased = listItems.where((item) => !item.isPurchased).toList();
    final purchased = listItems.where((item) => item.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
        actions: [
          if (purchased.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: deletePurchased,
              tooltip: lw('Clear purchased'),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : listItems.isEmpty
              ? Center(
                  child: Text(lw('No items yet. Add one using the + button.')),
                )
              : ListView(
                  children: [
                    if (unpurchased.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          lw('To Buy'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unpurchased.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = unpurchased.removeAt(oldIndex);
                            unpurchased.insert(newIndex, item);
                          });
                          await db.updateListItemsOrder(unpurchased);
                        },
                        itemBuilder: (context, index) {
                          final item = unpurchased[index];
                          return ListTile(
                            key: ValueKey(item.id),
                            leading: Checkbox(
                              value: item.isPurchased,
                              onChanged: (_) => togglePurchased(item),
                            ),
                            title: Text(item.displayName),
                            subtitle: Text(
                              '${item.quantity ?? ''} ${item.displayUnit}'.trim(),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.itemId == null)
                                  IconButton(
                                    icon: const Icon(Icons.save_alt),
                                    onPressed: () => addToItemsDictionary(item),
                                    tooltip: lw('Add to dictionary'),
                                  ),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                            onLongPress: () => deleteItem(item),
                          );
                        },
                      ),
                    ],
                    if (purchased.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          lw('Purchased'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: purchased.length,
                        itemBuilder: (context, index) {
                          final item = purchased[index];
                          return ListTile(
                            leading: Checkbox(
                              value: item.isPurchased,
                              onChanged: (_) => togglePurchased(item),
                            ),
                            title: Text(
                              item.displayName,
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity ?? ''} ${item.displayUnit}'.trim(),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => deleteItem(item),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  final int placeId;
  final List<ListItem> existingItems;

  const AddItemDialog({
    super.key,
    required this.placeId,
    required this.existingItems,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final db = DatabaseHelper.instance;
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  Item? selectedItem;
  List<Item> searchResults = [];
  bool isSearching = false;

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    super.dispose();
  }

  Future<void> searchItems(String query) async {
    if (query.length > 1) {
      if (!mounted) return;
      setState(() => isSearching = true);

      try {
        final results = await db.searchItems(query);
        if (mounted) {
          setState(() {
            searchResults = results;
            isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            searchResults = [];
            isSearching = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          searchResults = [];
          isSearching = false;
        });
      }
    }
  }

  void selectItem(Item item) {
    setState(() {
      selectedItem = item;
      nameController.text = item.name;
      unitController.text = item.unit ?? '';
      searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(lw('Add Item')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: lw('Item name'),
                hintText: lw('Search or enter item name'),
              ),
              autofocus: true,
              onChanged: searchItems,
            ),
            const SizedBox(height: 8),
            if (searchResults.isNotEmpty)
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: item.unit != null ? Text(item.unit!) : null,
                        dense: true,
                        onTap: () => selectItem(item),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: lw('Quantity'),
                      hintText: lw('e.g. 2'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: lw('Unit'),
                      hintText: lw('e.g. kg, pcs'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lw('Cancel')),
        ),
        TextButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              // Check for duplicates (case-insensitive)
              final itemName = nameController.text.trim();
              final duplicate = widget.existingItems.any((item) =>
                  item.displayName.toLowerCase() == itemName.toLowerCase());

              if (duplicate) {
                if (context.mounted) {
                  showMessage(
                    context,
                    '${lw('Item')} "$itemName" ${lw('already exists in this list')}',
                  );
                }
                return;
              }

              final newItem = ListItem(
                placeId: widget.placeId,
                itemId: selectedItem?.id,
                name: selectedItem == null ? nameController.text : null,
                unit: selectedItem == null ? unitController.text : null,
                quantity: quantityController.text,
                sortOrder: 0,
              );
              Navigator.pop(context, newItem);
            }
          },
          child: Text(lw('Add')),
        ),
      ],
    );
  }
}