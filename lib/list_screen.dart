import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
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
  Set<int> itemsWithPhoto = {};
  bool isLoading = true;
  late Place currentPlace;

  @override
  void initState() {
    super.initState();
    currentPlace = widget.place;
    loadListItems();
  }

  Future<void> loadListItems() async {
    setState(() => isLoading = true);
    final data = await db.getListItems(widget.place.id!);

    // Check which items have photos
    final Set<int> withPhoto = {};
    for (final item in data) {
      if (item.id != null && await hasPhoto(item.id!)) {
        withPhoto.add(item.id!);
      }
    }

    setState(() {
      listItems = data;
      itemsWithPhoto = withPhoto;
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

  Future<void> showPhoto(ListItem item) async {
    if (item.id == null) return;
    final path = await getPhotoPath(item.id!);
    final file = File(path);
    if (!await file.exists() || !mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.file(file),
          ),
        ),
      ),
    );
  }

  Future<void> addOrChangePhoto(ListItem item) async {
    if (item.id == null) return;

    // Show source selection dialog
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Select source')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(lw('Camera')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(lw('Gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final saved = await pickAndSavePhoto(item.id!, source);
    if (saved && mounted) {
      loadListItems();
      showMessage(context, lw('Photo added'), type: MessageType.success);
    }
  }

  Future<void> removePhoto(ListItem item) async {
    if (item.id == null) return;

    final confirmed = await showConfirmDialog(
      context,
      lw('Remove photo'),
      lw('Are you sure you want to remove the photo?'),
    );

    if (confirmed) {
      await deletePhoto(item.id!);
      loadListItems();
      if (mounted) {
        showMessage(context, lw('Photo removed'), type: MessageType.success);
      }
    }
  }

  Future<void> deleteItem(ListItem item) async {
    final hasItemPhoto = item.id != null && await hasPhoto(item.id!);

    if (hasItemPhoto && mounted) {
      // Show dialog with photo options
      final result = await showDeleteItemWithPhotoDialog(context);
      if (result == null) return;

      if (result == 'move') {
        await movePhotoToGallery(item.id!);
      } else {
        await deletePhoto(item.id!);
      }
      await db.deleteListItem(item.id!);
      loadListItems();
    } else {
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
  }

  Future<void> convertItemToList(ListItem item) async {
    // Get all places to determine sort order
    final allPlaces = await db.getPlaces();

    // Create new Place with the item's name
    final newPlace = Place(
      name: item.displayName,
      sortOrder: allPlaces.length,
    );

    final newPlaceId = await db.insertPlace(newPlace);

    // Create a new ListItem that is a place link
    final placeLink = ListItem(
      placeId: widget.place.id!,
      itemId: null,
      name: item.displayName,
      unit: '-$newPlaceId', // Place link format
      quantity: '-1', // Indicates this is a place link
      isPurchased: false,
      sortOrder: item.sortOrder, // Keep the same position
    );

    // Delete the old item and insert the place link
    await db.deleteListItem(item.id!);
    await db.insertListItem(placeLink);

    // Reload list
    loadListItems();

    // Navigate to the new list
    final createdPlace = await db.getPlace(newPlaceId);
    if (createdPlace != null && mounted) {
      await Navigator.pushNamed(
        context,
        '/list',
        arguments: createdPlace,
      );
      // Reload after returning from the new list
      loadListItems();
    }
  }

  Future<void> showItemContextMenu(ListItem item) async {
    final isPlaceLink = item.quantity == '-1';
    final hasItemPhoto = item.id != null && await hasPhoto(item.id!);

    if (!mounted) return;

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
        if (!isPlaceLink)
          ListTile(
            leading: const Icon(Icons.folder_copy),
            title: Text(lw('Convert to list')),
            onTap: () {
              Navigator.pop(context);
              convertItemToList(item);
            },
          ),
        if (!isPlaceLink)
          ListTile(
            leading: Icon(hasItemPhoto ? Icons.photo_library : Icons.add_a_photo),
            title: Text(hasItemPhoto ? lw('Change photo') : lw('Add photo')),
            onTap: () {
              Navigator.pop(context);
              addOrChangePhoto(item);
            },
          ),
        if (hasItemPhoto)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(lw('Remove photo')),
            onTap: () {
              Navigator.pop(context);
              removePhoto(item);
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
    // Get purchased items
    final purchased = listItems.where((item) => item.isPurchased && item.quantity != '-1').toList();
    if (purchased.isEmpty) return;

    // Check if any have photos
    final itemsWithPhotos = <ListItem>[];
    for (final item in purchased) {
      if (item.id != null && await hasPhoto(item.id!)) {
        itemsWithPhotos.add(item);
      }
    }

    if (!mounted) return;

    if (itemsWithPhotos.isNotEmpty) {
      // Show dialog with photo options
      final result = await showDeleteItemWithPhotoDialog(context);
      if (result == null) return;

      // Handle photos
      for (final item in itemsWithPhotos) {
        if (result == 'move') {
          await movePhotoToGallery(item.id!);
        } else {
          await deletePhoto(item.id!);
        }
      }

      await db.deletePurchasedItems(widget.place.id!);
      loadListItems();
    } else {
      final confirmed = await showConfirmDialog(
        context,
        lw('Delete purchased'),
        lw('Delete all purchased items from this list?'),
      );

      if (confirmed) {
        await db.deletePurchasedItems(widget.place.id!);
        loadListItems();
      }
    }
  }

  Future<void> clearPurchasedFlags() async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Clear purchased'),
      lw('Mark all purchased items as unpurchased?'),
    );

    if (confirmed) {
      await db.clearPurchasedFlags(widget.place.id!);
      loadListItems();
      if (mounted) {
        showMessage(context, lw('Purchased flags have been cleared'), type: MessageType.success);
      }
    }
  }

  Future<void> editComment() async {
    final commentController = TextEditingController(text: currentPlace.comment);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Comment')),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(
            labelText: lw('Comment'),
            hintText: lw('Optional note about this list'),
          ),
          maxLines: null,
          minLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lw('OK')),
          ),
        ],
      ),
    );

    if (result == true) {
      final updatedPlace = currentPlace.copyWith(
        comment: commentController.text.isEmpty ? null : commentController.text,
      );
      await db.updatePlace(updatedPlace);

      if (mounted) {
        setState(() {
          currentPlace = updatedPlace;
        });
      }
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

  Future<void> navigateToLinkedPlace(ListItem linkItem) async {
    if (linkItem.quantity != '-1') return;

    // Extract Place ID from unit (format: "-5")
    if (linkItem.unit == null || !linkItem.unit!.startsWith('-')) {
      if (mounted) {
        showMessage(
          context,
          lw('Invalid place link'),
          type: MessageType.error,
        );
      }
      return;
    }

    final placeId = int.tryParse(linkItem.unit!.substring(1)); // Remove minus
    if (placeId == null) {
      if (mounted) {
        showMessage(
          context,
          lw('Invalid place link'),
          type: MessageType.error,
        );
      }
      return;
    }

    // Find Place by ID
    final linkedPlace = await db.getPlace(placeId);

    if (linkedPlace == null) {
      if (mounted) {
        showMessage(
          context,
          lw('Linked place not found or has been deleted'),
          type: MessageType.warning,
        );
      }
      return;
    }

    if (mounted) {
      await Navigator.pushNamed(
        context,
        '/list',
        arguments: linkedPlace,
      );
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

    // Check if auto-sort is enabled
    final autoSortSetting = await db.getSetting('auto_sort_dict');
    if (autoSortSetting == 'true') {
      // Reload all items and sort them alphabetically
      final allItemsReloaded = await db.getItems();
      allItemsReloaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await db.updateItemsOrder(allItemsReloaded);
    }

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

  Future<void> _expandPlaceLink(
    StringBuffer buffer,
    ListItem linkItem,
    String indent,
    Set<int> visitedPlaces,
    String choice,
  ) async {
    // Extract Place ID from unit
    if (linkItem.unit == null || !linkItem.unit!.startsWith('-')) return;

    final placeId = int.tryParse(linkItem.unit!.substring(1));
    if (placeId == null) return;

    // Prevent circular references
    if (visitedPlaces.contains(placeId)) {
      buffer.writeln('$indent* =${linkItem.displayName} [circular reference]');
      return;
    }

    visitedPlaces.add(placeId);

    // Get linked place
    final linkedPlace = await db.getPlace(placeId);
    if (linkedPlace == null) {
      buffer.writeln('$indent* =${linkItem.displayName} [not found]');
      return;
    }

    // Get items from linked place
    final linkedItems = await db.getListItems(placeId);
    // Place links are always treated as unpurchased since they're just references
    final unpurchased = linkedItems.where((item) => !item.isPurchased || item.quantity == '-1').toList();
    final purchased = linkedItems.where((item) => item.isPurchased && item.quantity != '-1').toList();

    // Write place name
    buffer.writeln('$indent* =${linkedPlace.name}:');

    // Items inside this place should have additional indent
    final itemIndent = '$indent  ';

    // Write unpurchased items
    for (final item in unpurchased) {
      final isNestedLink = item.quantity == '-1';

      if (isNestedLink) {
        // Recursively expand nested link
        final nextIndent = '$itemIndent  ';
        await _expandPlaceLink(buffer, item, nextIndent, visitedPlaces, choice);
      } else {
        buffer.write('$itemIndent> ${item.displayName}');

        // Add quantity/unit
        if (item.quantity != null &&
            item.quantity!.trim().isNotEmpty &&
            !item.quantity!.startsWith('-')) {
          buffer.write(' ${item.quantity}');
          if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
            buffer.write(item.displayUnit);
          }
        } else if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
          buffer.write(' ${item.displayUnit}');
        }

        buffer.writeln();
      }
    }

    // Add divider between unpurchased and purchased items if there are both
    if (choice == 'all' && purchased.isNotEmpty && unpurchased.isNotEmpty) {
      buffer.writeln('$itemIndent-------');
    }

    // Write purchased items if choice is 'all'
    if (choice == 'all' && purchased.isNotEmpty) {
      for (final item in purchased) {
        final isNestedLink = item.quantity == '-1';

        if (isNestedLink) {
          final nextIndent = '$itemIndent  ';
          await _expandPlaceLink(buffer, item, nextIndent, visitedPlaces, choice);
        } else {
          buffer.write('${itemIndent}x ${item.displayName}');

          if (item.quantity != null &&
              item.quantity!.trim().isNotEmpty &&
              !item.quantity!.startsWith('-')) {
            buffer.write(' ${item.quantity}');
            if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
              buffer.write(item.displayUnit);
            }
          } else if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
            buffer.write(' ${item.displayUnit}');
          }

          buffer.writeln();
        }
      }
    }

    visitedPlaces.remove(placeId);
  }

  Future<void> shareList() async {
    // Show dialog to choose what to share
    final result = await showShareOptionsDialog(context);

    if (result == null) return; // User canceled

    final choice = result['option'] as String;
    final includeComment = result['includeComment'] as bool;

    // Separate items by purchase status
    // Place links (quantity="-1") are always treated as unpurchased since they're just references
    final unpurchased = listItems.where((item) => !item.isPurchased || item.quantity == '-1').toList();
    final purchased = listItems.where((item) => item.isPurchased && item.quantity != '-1').toList();

    // Format the list as plain text
    final StringBuffer buffer = StringBuffer();

    // Add place name as header
    buffer.writeln('* =${currentPlace.name}:');

    // Track visited places to prevent infinite loops
    final visitedPlaces = <int>{};
    if (widget.place.id != null) {
      visitedPlaces.add(widget.place.id!);
    }

    // Add active items
    for (final item in unpurchased) {
      final isPlaceLink = item.quantity == '-1';

      if (isPlaceLink) {
        // Expand place link recursively with 2 spaces indent
        await _expandPlaceLink(buffer, item, '  ', visitedPlaces, choice);
      } else {
        buffer.write('> ${item.displayName}');

        // Quantity only if not negative
        if (item.quantity != null &&
            item.quantity!.trim().isNotEmpty &&
            !item.quantity!.startsWith('-')) {
          buffer.write(' ${item.quantity}');

          // Unit only if not negative
          if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
            buffer.write(item.displayUnit);
          }
        } else if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
          buffer.write(' ${item.displayUnit}');
        }

        buffer.writeln();
      }
    }

    // Add divider and completed items only if sharing all items
    if (choice == 'all' && purchased.isNotEmpty && unpurchased.isNotEmpty) {
      buffer.writeln('-------'); // Divider between sections
    }

    // Add completed items only if sharing all items
    if (choice == 'all' && purchased.isNotEmpty) {
      for (final item in purchased) {
        final isPlaceLink = item.quantity == '-1';

        if (isPlaceLink) {
          // Expand place link recursively with 2 spaces indent
          await _expandPlaceLink(buffer, item, '  ', visitedPlaces, choice);
        } else {
          buffer.write('x ${item.displayName}');

          // Quantity only if not negative
          if (item.quantity != null &&
              item.quantity!.trim().isNotEmpty &&
              !item.quantity!.startsWith('-')) {
            buffer.write(' ${item.quantity}');

            // Unit only if not negative
            if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
              buffer.write(item.displayUnit);
            }
          } else if (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')) {
            buffer.write(' ${item.displayUnit}');
          }

          buffer.writeln();
        }
      }
    }

    // Add comment if requested and exists
    if (includeComment && currentPlace.comment != null && currentPlace.comment!.isNotEmpty) {
      buffer.writeln('-------');
      buffer.writeln(currentPlace.comment);
    }

    // Check if there are items to share
    final text = buffer.toString().trim();
    if (text == '* =${currentPlace.name}:') {
      if (mounted) {
        showMessage(context, lw('No items to share'), type: MessageType.warning);
      }
      return;
    }

    // Share the text
    await Share.share(text, subject: currentPlace.name);
  }

  @override
  Widget build(BuildContext context) {
    final unpurchased = listItems.where((item) => !item.isPurchased).toList();
    final purchased = listItems.where((item) => item.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPlace.name),
        actions: [
          if (listItems.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: clMenu,
              surfaceTintColor: Colors.transparent,
              onSelected: (value) {
                switch (value) {
                  case 'move':
                    openMoveItems();
                    break;
                  case 'share':
                    shareList();
                    break;
                  case 'comment':
                    editComment();
                    break;
                  case 'delete_purchased':
                    deletePurchased();
                    break;
                  case 'clear_flags':
                    clearPurchasedFlags();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard_double_arrow_right),
                      const SizedBox(width: 12),
                      Text(lw('Move items'), style: TextStyle(fontSize: fsMedium)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share),
                      const SizedBox(width: 12),
                      Text(lw('Share List'), style: TextStyle(fontSize: fsMedium)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'comment',
                  child: Row(
                    children: [
                      const Icon(Icons.comment),
                      const SizedBox(width: 12),
                      Text(lw('Comment'), style: TextStyle(fontSize: fsMedium)),
                    ],
                  ),
                ),
                if (purchased.isNotEmpty)
                  PopupMenuItem(
                    value: 'delete_purchased',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep),
                        const SizedBox(width: 12),
                        Text(lw('Delete purchased'), style: TextStyle(fontSize: fsMedium)),
                      ],
                    ),
                  ),
                if (purchased.isNotEmpty)
                  PopupMenuItem(
                    value: 'clear_flags',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined),
                        const SizedBox(width: 12),
                        Text(lw('Clear purchased'), style: TextStyle(fontSize: fsMedium)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : listItems.isEmpty
              ? Center(
                  child: Text(
                    lw('No items yet. Add one using the + button.'),
                    textAlign: TextAlign.center,
                  ),
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
                            child: () {
                              final isPlaceLink = item.quantity == '-1';
                              final hasItemPhoto = item.id != null && itemsWithPhoto.contains(item.id);
                              return ListTile(
                                key: ValueKey('tile_${item.id}'),
                                visualDensity: VisualDensity.compact,
                                leading: isPlaceLink
                                    ? const Icon(Icons.folder, color: Colors.blue)
                                    : Checkbox(
                                        value: item.isPurchased,
                                        onChanged: (_) => togglePurchased(item),
                                      ),
                                title: Row(
                                  children: [
                                    if (isPlaceLink)
                                      const Icon(Icons.subdirectory_arrow_right, size: 16),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: hasItemPhoto ? () => showPhoto(item) : null,
                                        child: Text(
                                          () {
                                            final photoPrefix = hasItemPhoto ? '@ ' : '';
                                            final parts = <String>[photoPrefix + item.displayName];
                                            if (item.quantity != null &&
                                                item.quantity!.trim().isNotEmpty &&
                                                !item.quantity!.startsWith('-')) {
                                              // Add quantity with unit (no space, skip negatives)
                                              final qtyUnit = item.quantity!.trim() +
                                                  (item.displayUnit.isNotEmpty && !item.displayUnit.startsWith('-')
                                                      ? item.displayUnit : '');
                                              parts.add(qtyUnit);
                                            }
                                            return parts.join(' ');
                                          }(),
                                          style: TextStyle(
                                            fontSize: fsLarge,
                                            fontWeight: isPlaceLink ? FontWeight.bold : FontWeight.normal,
                                            color: hasItemPhoto ? Colors.blue : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.itemId == null && !isPlaceLink)
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
                                onTap: isPlaceLink ? () => navigateToLinkedPlace(item) : null,
                                onLongPress: () => showItemContextMenu(item),
                              );
                            }(),
                          );
                        },
                      ),
                    ],
                    if (unpurchased.isNotEmpty && purchased.isNotEmpty)
                      const Divider(thickness: 2, height: 24, color: Colors.black),
                    if (purchased.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: purchased.length,
                        itemBuilder: (context, index) {
                          final item = purchased[index];
                          final hasItemPhoto = item.id != null && itemsWithPhoto.contains(item.id);
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
                              title: GestureDetector(
                                onTap: hasItemPhoto ? () => showPhoto(item) : null,
                                child: Text(
                                  () {
                                    final photoPrefix = hasItemPhoto ? '@ ' : '';
                                    final parts = <String>[photoPrefix + item.displayName];
                                    if (item.quantity != null && item.quantity!.trim().isNotEmpty) {
                                      // Add quantity with unit (no space between them)
                                      final qtyUnit = item.quantity!.trim() +
                                          (item.displayUnit.isNotEmpty ? item.displayUnit : '');
                                      parts.add(qtyUnit);
                                    }
                                    return parts.join(' ');
                                  }(),
                                  style: TextStyle(
                                    fontSize: fsLarge,
                                    decoration: TextDecoration.lineThrough,
                                    color: hasItemPhoto ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              onLongPress: () => showItemContextMenu(item),
                            ),
                          );
                        },
                      ),
                    ],
                    if (currentPlace.comment != null && currentPlace.comment!.isNotEmpty) ...[
                      const Divider(thickness: 2, height: 24, color: Colors.black),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lw('Comment'),
                              style: TextStyle(
                                fontSize: fsMedium,
                                fontWeight: fwBold,
                                color: clText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentPlace.comment!,
                              style: TextStyle(
                                fontSize: fsNormal,
                                color: clText,
                              ),
                            ),
                          ],
                        ),
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