import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'database.dart';
import 'place.dart';
import 'list.dart';
import 'items.dart';
import 'globals.dart';
import 'move_items_screen.dart';

// List spacing constants
const double _sectionPadding = 16.0; // padding around section headers
const double _itemVerticalSpacing = 8.0; // spacing between dialog fields
const double _dialogFieldSpacing = 16.0; // spacing between major dialog sections

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

  Future<void> editItem(ListItem item) async {
    final result = await showDialog<ListItem>(
      context: context,
      builder: (context) => EditItemDialog(
        item: item,
        existingItems: listItems,
      ),
    );

    if (result != null) {
      await db.updateListItem(result);
      loadListItems();
    }
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

  void showItemContextMenu(ListItem item) {
    showTopMenu(
      context: context,
      items: [
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
    );
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

  Future<void> openMoveItems() async {
    if (listItems.isEmpty) {
      showMessage(context, lw('No items yet. Add one using the + button.'), type: MessageType.warning);
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MoveItemsScreen(
          currentPlace: widget.place,
          items: listItems,
        ),
      ),
    );

    // Reload list if items were moved/copied
    if (result == true && mounted) {
      loadListItems();
    }
  }

  Future<void> addToItemsDictionary(ListItem listItem) async {
    if (listItem.itemId != null) {
      if (mounted) {
        showMessage(context, lw('Item is already in dictionary'), type: MessageType.warning);
      }
      return;
    }

    // Get current items count for sortOrder
    final allItems = await db.getItems();

    // Check for duplicates (case-insensitive)
    final itemName = capitalizeFirst(listItem.name!.trim());
    final duplicate = allItems.any((item) =>
        item.name.toLowerCase() == itemName.toLowerCase());

    if (duplicate) {
      if (mounted) {
        showMessage(
          context,
          '${lw('Item')} "$itemName" ${lw('already exists in dictionary')}',
          type: MessageType.warning,
        );
      }
      return;
    }

    final newItem = Item(
      name: itemName,
      unit: (listItem.unit?.trim().isEmpty ?? true) ? null : listItem.unit!.trim(),
      sortOrder: allItems.length,
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
      showMessage(context, lw('Added to items dictionary'), type: MessageType.success);
    }
  }

  Future<void> shareList() async {
    // Show dialog to choose what to share
    final choice = await showShareOptionsDialog(context);

    if (choice == null) return; // User canceled

    // Separate items by purchase status
    final unpurchased = listItems.where((item) => !item.isPurchased).toList();
    final purchased = listItems.where((item) => item.isPurchased).toList();

    // Format the list as plain text
    final StringBuffer buffer = StringBuffer();

    // Add place name as header
    buffer.writeln('${widget.place.name}:');

    // Add "To Buy" section
    if (unpurchased.isNotEmpty) {
      buffer.writeln(); // Empty line before section
      buffer.writeln('* ${lw('To Buy')}');
      for (final item in unpurchased) {
        buffer.write('- ${item.displayName}');

        // Add quantity if present
        if (item.quantity != null && item.quantity!.trim().isNotEmpty) {
          buffer.write(' - ${item.quantity}');

          // Add unit if present
          if (item.displayUnit.isNotEmpty) {
            buffer.write(' ${item.displayUnit}');
          }
        } else if (item.displayUnit.isNotEmpty) {
          // Only unit, no quantity
          buffer.write(' - ${item.displayUnit}');
        }

        buffer.writeln();
      }
    }

    // Add "Purchased" section only if sharing all items
    if (choice == 'all' && purchased.isNotEmpty) {
      buffer.writeln(); // Empty line before section
      buffer.writeln('* ${lw('Purchased')}');
      for (final item in purchased) {
        buffer.write('- ${item.displayName}');

        // Add quantity if present
        if (item.quantity != null && item.quantity!.trim().isNotEmpty) {
          buffer.write(' - ${item.quantity}');

          // Add unit if present
          if (item.displayUnit.isNotEmpty) {
            buffer.write(' ${item.displayUnit}');
          }
        } else if (item.displayUnit.isNotEmpty) {
          // Only unit, no quantity
          buffer.write(' - ${item.displayUnit}');
        }

        buffer.writeln();
      }
    }

    // Check if there are items to share
    final text = buffer.toString().trim();
    if (text == '${widget.place.name}:') {
      if (mounted) {
        showMessage(context, lw('No items to share'), type: MessageType.warning);
      }
      return;
    }

    // Share the text
    await Share.share(text, subject: widget.place.name);
  }

  @override
  Widget build(BuildContext context) {
    final unpurchased = listItems.where((item) => !item.isPurchased).toList();
    final purchased = listItems.where((item) => item.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
        actions: [
          if (listItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.keyboard_double_arrow_right),
              onPressed: openMoveItems,
              tooltip: lw('Move items'),
            ),
          if (listItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: shareList,
              tooltip: lw('Share List'),
            ),
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
                        padding: const EdgeInsets.all(_sectionPadding),
                        child: Text(
                          lw('To Buy'),
                          style: const TextStyle(
                            fontSize: fsMedium,
                            fontWeight: fwBold,
                          ),
                        ),
                      ),
                      ReorderableListView.builder(
                        buildDefaultDragHandles: false,
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
                            // Update main listItems to keep them in sync
                            listItems = [...unpurchased, ...purchased];
                          });
                          await db.updateListItemsOrder(unpurchased);
                        },
                        itemBuilder: (context, index) {
                          final item = unpurchased[index];
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
                                  '${lw('Are you sure you want to delete')} "${item.displayName}"?',
                                );
                              }
                            },
                            onDismissed: (direction) {
                              // Only called if confirmDismiss returns true (delete confirmed)
                              db.deleteListItem(item.id!);
                              loadListItems();
                            },
                            child: ListTile(
                              key: ValueKey('tile_${item.id}'),
                              visualDensity: VisualDensity.compact,
                              leading: Checkbox(
                                value: item.isPurchased,
                                onChanged: (_) => togglePurchased(item),
                              ),
                              title: Text(
                                item.displayName,
                                style: const TextStyle(fontSize: fsLarge),
                              ),
                              subtitle: '${item.quantity ?? ''} ${item.displayUnit}'.trim().isNotEmpty
                                  ? Text(
                                      '${item.quantity ?? ''} ${item.displayUnit}'.trim(),
                                      style: const TextStyle(fontSize: fsNormal),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.itemId == null)
                                    IconButton(
                                      icon: const Icon(Icons.save_alt),
                                      onPressed: () => addToItemsDictionary(item),
                                      tooltip: lw('Add to dictionary'),
                                    ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                ],
                              ),
                              onLongPress: () => showItemContextMenu(item),
                            ),
                          );
                        },
                      ),
                    ],
                    if (purchased.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(_sectionPadding),
                        child: Text(
                          lw('Purchased'),
                          style: const TextStyle(
                            fontSize: fsMedium,
                            fontWeight: fwBold,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: purchased.length,
                        itemBuilder: (context, index) {
                          final item = purchased[index];
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
                                  '${lw('Are you sure you want to delete')} "${item.displayName}"?',
                                );
                              }
                            },
                            onDismissed: (direction) {
                              // Only called if confirmDismiss returns true (delete confirmed)
                              db.deleteListItem(item.id!);
                              loadListItems();
                            },
                            child: ListTile(
                              key: ValueKey('tile_${item.id}'),
                              visualDensity: VisualDensity.compact,
                              leading: Checkbox(
                                value: item.isPurchased,
                                onChanged: (_) => togglePurchased(item),
                              ),
                              title: Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontSize: fsLarge,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: '${item.quantity ?? ''} ${item.displayUnit}'.trim().isNotEmpty
                                  ? Text(
                                      '${item.quantity ?? ''} ${item.displayUnit}'.trim(),
                                      style: const TextStyle(fontSize: fsNormal),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteItem(item),
                              ),
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
        child: SingleChildScrollView(
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
              const SizedBox(height: _itemVerticalSpacing),
              if (searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
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
              const SizedBox(height: _dialogFieldSpacing),
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
                    type: MessageType.warning,
                  );
                }
                return;
              }

              final newItem = ListItem(
                placeId: widget.placeId,
                itemId: selectedItem?.id,
                name: selectedItem == null ? nameController.text : null,
                unit: selectedItem == null && unitController.text.trim().isNotEmpty
                    ? unitController.text.trim()
                    : null,
                quantity: quantityController.text.trim().isNotEmpty
                    ? quantityController.text.trim()
                    : null,
                sortOrder: 0,
              );
              Navigator.pop(context, newItem);
            }
          },
          child: Text(lw('OK')),
        ),
      ],
    );
  }
}

class EditItemDialog extends StatefulWidget {
  final ListItem item;
  final List<ListItem> existingItems;

  const EditItemDialog({
    super.key,
    required this.item,
    required this.existingItems,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  final db = DatabaseHelper.instance;
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  Item? selectedItem;
  List<Item> searchResults = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields with current values
    nameController.text = widget.item.displayName;
    quantityController.text = widget.item.quantity ?? '';
    unitController.text = widget.item.displayUnit;
  }

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
      title: Text(lw('Edit Item')),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
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
              const SizedBox(height: _itemVerticalSpacing),
              if (searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
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
              const SizedBox(height: _dialogFieldSpacing),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lw('Cancel')),
        ),
        TextButton(
          onPressed: () {
            if (nameController.text.isNotEmpty) {
              // Check for duplicates (excluding current item)
              final itemName = nameController.text.trim();
              final duplicate = widget.existingItems.any((item) =>
                  item.id != widget.item.id &&
                  item.displayName.toLowerCase() == itemName.toLowerCase());

              if (duplicate) {
                if (context.mounted) {
                  showMessage(
                    context,
                    '${lw('Item')} "$itemName" ${lw('already exists in this list')}',
                    type: MessageType.warning,
                  );
                }
                return;
              }

              final updatedItem = ListItem(
                id: widget.item.id,
                placeId: widget.item.placeId,
                itemId: selectedItem?.id,
                name: selectedItem == null ? nameController.text.trim() : null,
                unit: selectedItem == null && unitController.text.trim().isNotEmpty
                    ? unitController.text.trim()
                    : null,
                quantity: quantityController.text.trim().isNotEmpty
                    ? quantityController.text.trim()
                    : null,
                isPurchased: widget.item.isPurchased,
                sortOrder: widget.item.sortOrder,
              );
              Navigator.pop(context, updatedItem);
            }
          },
          child: Text(lw('OK')),
        ),
      ],
    );
  }
}