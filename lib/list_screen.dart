import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'database.dart';
import 'place.dart';
import 'list.dart';
import 'items.dart';
import 'globals.dart';
import 'move_items_screen.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ItemDialog(
        mode: ItemDialogMode.add,
        dialogContext: ItemDialogContext.list,
        placeId: widget.place.id!,
        existingItems: listItems,
      ),
    );

    if (result == true) {
      loadListItems();
    }
  }

  Future<void> togglePurchased(ListItem item) async {
    final updated = item.copyWith(isPurchased: !item.isPurchased);
    await db.updateListItem(updated);
    loadListItems();
  }

  Future<void> editItem(ListItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ItemDialog(
        mode: ItemDialogMode.edit,
        dialogContext: ItemDialogContext.list,
        placeId: widget.place.id!,
        existingItems: listItems,
        existingItem: item,
      ),
    );

    if (result == true) {
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
    buffer.writeln(); // Empty line after header

    // Add active items
    for (final item in unpurchased) {
      buffer.write('> ${item.displayName}');

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

    // Add completed items only if sharing all items
    if (choice == 'all' && purchased.isNotEmpty) {
      buffer.writeln('-------'); // Divider between sections
      for (final item in purchased) {
        buffer.write('x ${item.displayName}');

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
                    if (unpurchased.isNotEmpty && purchased.isNotEmpty)
                      const Divider(thickness: 1, color: Colors.black),
                    if (purchased.isNotEmpty) ...[
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