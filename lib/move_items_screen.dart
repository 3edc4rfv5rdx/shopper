import 'package:flutter/material.dart';
import 'database.dart';
import 'place.dart';
import 'list.dart';
import 'globals.dart';

class MoveItemsScreen extends StatefulWidget {
  final Place currentPlace;
  final List<ListItem> items;

  const MoveItemsScreen({
    super.key,
    required this.currentPlace,
    required this.items,
  });

  @override
  State<MoveItemsScreen> createState() => _MoveItemsScreenState();
}

class _MoveItemsScreenState extends State<MoveItemsScreen> {
  final db = DatabaseHelper.instance;
  final Set<int> selectedItemIds = {};
  bool isMoveMode = true; // true = Move, false = Copy
  Place? destinationPlace;
  List<Place> availablePlaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    final places = await db.getPlaces();
    setState(() {
      // Exclude current place from available destinations
      availablePlaces = places.where((p) => p.id != widget.currentPlace.id).toList();
      isLoading = false;
    });
  }

  void toggleSelectAll() {
    setState(() {
      if (selectedItemIds.length == widget.items.length) {
        // Unselect all
        selectedItemIds.clear();
      } else {
        // Select all
        selectedItemIds.addAll(widget.items.map((item) => item.id!));
      }
    });
  }

  bool canProceed() {
    return selectedItemIds.isNotEmpty && destinationPlace != null;
  }

  Future<void> moveOrCopyItems() async {
    if (!canProceed()) {
      if (destinationPlace == null) {
        showMessage(context, lw('Please select destination'), type: MessageType.warning);
      } else {
        showMessage(context, lw('Please select at least one item'), type: MessageType.warning);
      }
      return;
    }

    final selectedItems = widget.items.where((item) => selectedItemIds.contains(item.id)).toList();
    final destPlace = destinationPlace!;

    // Get current max sort order in destination
    final destItems = await db.getListItems(destPlace.id!);
    int maxSortOrder = destItems.isEmpty ? 0 : destItems.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b);

    // Check for duplicates
    int skippedCount = 0;
    for (var item in selectedItems) {
      final isPlaceLink = item.quantity == '-1';

      // Check if item already exists in destination
      final isDuplicate = destItems.any((destItem) {
        // For place links, check by unit (Place ID)
        if (isPlaceLink && destItem.quantity == '-1') {
          return destItem.unit == item.unit;
        }
        // For regular items, check by itemId
        return destItem.itemId == item.itemId;
      });

      if (isDuplicate) {
        // Skip duplicates for both Move and Copy
        skippedCount++;

        // For Move mode: delete the item from source since it already exists in destination
        if (isMoveMode) {
          await db.deleteListItem(item.id!);
        }
        continue;
      }

      maxSortOrder++;

      if (isMoveMode) {
        // Move: update placeId and reset isPurchased
        final updated = item.copyWith(
          placeId: destPlace.id!,
          isPurchased: false,
          sortOrder: maxSortOrder,
        );
        await db.updateListItem(updated);
      } else {
        // Copy: create new item with reset isPurchased
        final newItem = ListItem(
          placeId: destPlace.id!,
          itemId: item.itemId,
          name: item.name,
          unit: item.unit,
          quantity: item.quantity,
          isPurchased: false,
          sortOrder: maxSortOrder,
        );
        await db.insertListItem(newItem);
      }
    }

    if (mounted) {
      final actualCount = selectedItems.length - skippedCount;
      String message;

      if (isMoveMode) {
        message = lw('Moved %d items to %s').replaceAll('%d', '$actualCount').replaceAll('%s', destPlace.name);
      } else {
        message = lw('Copied %d items to %s').replaceAll('%d', '$actualCount').replaceAll('%s', destPlace.name);
      }

      if (skippedCount > 0) {
        message += ' (${lw('Skipped %d duplicates').replaceAll('%d', '$skippedCount')})';
      }

      showMessage(context, message, type: MessageType.success);
      Navigator.pop(context, true); // Return true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selectedItemIds.length == widget.items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMoveMode ? lw('Move items') : lw('Copy items')),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Select all / Unselect all button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: toggleSelectAll,
                      icon: Icon(allSelected ? Icons.check_box : Icons.check_box_outline_blank),
                      label: Text(allSelected ? lw('Unselect all') : lw('Select all')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: clUpBar,
                        foregroundColor: clText,
                      ),
                    ),
                  ),
                ),

                // Items list with checkboxes
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = selectedItemIds.contains(item.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedItemIds.add(item.id!);
                            } else {
                              selectedItemIds.remove(item.id);
                            }
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          item.displayName,
                          style: TextStyle(
                            fontSize: fsLarge,
                            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: '${item.quantity ?? ''} ${item.displayUnit}'.trim().isNotEmpty
                            ? Text(
                                '${item.quantity ?? ''} ${item.displayUnit}'.trim(),
                                style: const TextStyle(fontSize: fsNormal),
                              )
                            : null,
                        activeColor: clUpBar,
                      );
                    },
                  ),
                ),

                // Move/Copy controls group
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(
                    children: [
                      // Copy mode checkbox
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
                        child: CheckboxListTile(
                          value: !isMoveMode,
                          onChanged: (value) => setState(() => isMoveMode = !value!),
                          title: Text(lw('Copy'), style: const TextStyle(fontSize: fsLarge)),
                          controlAffinity: ListTileControlAffinity.leading,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          activeColor: clUpBar,
                        ),
                      ),

                      // Destination dropdown
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<Place>(
                              initialValue: destinationPlace,
                              style: const TextStyle(fontSize: fsLarge, color: Colors.black),
                              isDense: true,
                              decoration: InputDecoration(
                                labelText: lw('Select destination'),
                                labelStyle: const TextStyle(fontSize: fsLarge),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: clFill,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: availablePlaces.map((place) {
                                return DropdownMenuItem<Place>(
                                  value: place,
                                  child: Text(place.name, style: const TextStyle(fontSize: fsLarge)),
                                );
                              }).toList(),
                              onChanged: (Place? newValue) {
                                setState(() {
                                  destinationPlace = newValue;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(lw('Cancel'), style: const TextStyle(fontSize: fsLarge)),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: canProceed() ? moveOrCopyItems : null,
                              child: Text(lw('OK'), style: const TextStyle(fontSize: fsLarge)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
