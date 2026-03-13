// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'database.dart';
import 'items.dart';
import 'list.dart';
import 'place.dart';
import 'globals-theme-localization.dart';
import 'globals-ui-helpers.dart';

// ========== UNIFIED ITEM DIALOG ==========

// List spacing constants
const double _itemVerticalSpacing = 4.0;
const double _dialogFieldSpacing = 8.0;

// Dialog modes
enum ItemDialogMode { add, edit }

// Dialog contexts
enum ItemDialogContext { list, dictionary }

// Import dependencies for ItemDialog
// Note: These are forward references - actual imports should be in files using ItemDialog
// import 'database.dart';
// import 'list.dart';
// import 'items.dart';

class ItemDialog extends StatefulWidget {
  final ItemDialogMode mode;
  final ItemDialogContext dialogContext;
  final int? placeId;
  final List<dynamic> existingItems;
  final dynamic existingItem;

  const ItemDialog({
    super.key,
    required this.mode,
    required this.dialogContext,
    this.placeId,
    required this.existingItems,
    this.existingItem,
  }) : assert(
          dialogContext == ItemDialogContext.dictionary || placeId != null,
          'placeId is required for list context',
        ),
        assert(
          mode == ItemDialogMode.add || existingItem != null,
          'existingItem is required for edit mode',
        );

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late TextEditingController unitController;

  dynamic selectedItem; // Item or null
  List<dynamic> searchResults = [];
  bool isSearching = false;
  bool isPlaceLink = false;
  bool isPlaceLinkSelected = false; // Track if place link is selected
  String? savedQuantity; // Store real quantity value for place links
  String? savedUnit; // Store real unit value for place links

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    quantityController = TextEditingController();
    unitController = TextEditingController();
    _initializeControllers();
    _detectPlaceLink();
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    if (widget.mode == ItemDialogMode.edit) {
      if (widget.dialogContext == ItemDialogContext.list) {
        final listItem = widget.existingItem as ListItem;
        nameController.text = listItem.displayName;

        // Filter negative values
        final qty = listItem.quantity ?? '';
        quantityController.text = qty.startsWith('-') ? '' : qty;

        final unit = listItem.displayUnit;
        unitController.text = unit.startsWith('-') ? '' : unit;
      } else {
        final item = widget.existingItem as Item;
        nameController.text = item.name;
        unitController.text = item.unit ?? '';
      }
    }
  }

  void _detectPlaceLink() {
    if (widget.mode != ItemDialogMode.edit ||
        widget.dialogContext != ItemDialogContext.list) {
      isPlaceLink = false;
      return;
    }

    final listItem = widget.existingItem as ListItem;
    isPlaceLink = listItem.quantity == '-1';
  }

  Future<void> searchItems(String query) async {
    if (query.length > 1) {
      if (!mounted) return;
      setState(() => isSearching = true);

      try {
        final db = DatabaseHelper.instance;
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

  void selectItem(dynamic item) {
    setState(() {
      selectedItem = item;
      nameController.text = item.name;
      unitController.text = item.unit ?? '';
      searchResults = [];
    });
  }

  Future<Set<int>> _getPlacesLinkingTo(int targetPlaceId) async {
    final db = DatabaseHelper.instance;
    final linkingPlaces = <int>{};
    final toCheck = <int>[targetPlaceId];
    final checked = <int>{};

    while (toCheck.isNotEmpty) {
      final currentPlaceId = toCheck.removeLast();
      if (checked.contains(currentPlaceId)) continue;
      checked.add(currentPlaceId);

      // Get all places
      final allPlaces = await db.getPlaces();

      for (final place in allPlaces) {
        if (place.id == null || checked.contains(place.id)) continue;

        // Check if this place has a link to currentPlaceId
        final items = await db.getListItems(place.id!);
        final hasLink = items.any((item) =>
            item.quantity == '-1' && item.unit == '-$currentPlaceId');

        if (hasLink) {
          linkingPlaces.add(place.id!);
          toCheck.add(place.id!);
        }
      }
    }

    return linkingPlaces;
  }

  Future<void> selectPlaceAsLink() async {
    final db = DatabaseHelper.instance;
    final places = await db.getPlaces();

    // Exclude current Place and places that link to it (prevent circular refs)
    final placesLinkingToCurrent = await _getPlacesLinkingTo(widget.placeId!);
    final availablePlaces = places.where((p) =>
        p.id != widget.placeId && !placesLinkingToCurrent.contains(p.id)).toList();

    if (availablePlaces.isEmpty) {
      if (mounted) {
        showMessage(context, lw('No other places available'), type: MessageType.warning);
      }
      return;
    }

    if (!mounted) return;

    final selectedPlace = await showDialog<Place>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Select Place')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availablePlaces.length,
            itemBuilder: (context, index) {
              final place = availablePlaces[index];
              return ListTile(
                title: Text(place.name),
                onTap: () => Navigator.pop(context, place),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lw('Cancel')),
          ),
        ],
      ),
    );

    if (selectedPlace != null && mounted) {
      setState(() {
        nameController.text = selectedPlace.name;
        // Save real values
        savedQuantity = '-1'; // Link marker
        savedUnit = '-${selectedPlace.id}'; // Place ID with minus
        // Show stars in fields
        quantityController.text = '*';
        unitController.text = '*';
        searchResults = [];
        isPlaceLinkSelected = true; // Mark as place link
      });
    }
  }

  bool _isDuplicate(String itemName) {
    if (widget.dialogContext == ItemDialogContext.list) {
      final listItems = widget.existingItems.cast<ListItem>();
      return listItems.any((item) {
        if (widget.mode == ItemDialogMode.edit) {
          final currentItem = widget.existingItem as ListItem;
          if (item.id == currentItem.id) return false;
        }
        return item.displayName.toLowerCase() == itemName.toLowerCase();
      });
    } else {
      final items = widget.existingItems.cast<Item>();
      return items.any((item) {
        if (widget.mode == ItemDialogMode.edit) {
          final currentItem = widget.existingItem as Item;
          if (item.id == currentItem.id) return false;
        }
        return item.name.toLowerCase() == itemName.toLowerCase();
      });
    }
  }

  bool _validateFields() {
    if (nameController.text.trim().isEmpty) {
      return false;
    }

    final isPlaceLinkNew = isPlaceLinkSelected || quantityController.text.trim() == '-1';

    // Check for duplicates
    if (widget.dialogContext == ItemDialogContext.list) {
      final listItems = widget.existingItems.cast<ListItem>();

      if (isPlaceLinkNew) {
        // For place links, check by unit (Place ID) - use saved value
        final placeUnit = savedUnit ?? unitController.text.trim();
        final duplicate = listItems.any((item) {
          if (widget.mode == ItemDialogMode.edit) {
            final currentItem = widget.existingItem as ListItem;
            if (item.id == currentItem.id) return false;
          }
          return item.quantity == '-1' && item.unit == placeUnit;
        });

        if (duplicate) {
          if (context.mounted) {
            showMessage(
              context,
              lw('This place link already exists in this list'),
              type: MessageType.warning,
            );
          }
          return false;
        }
      } else {
        // For regular items, check by name
        final itemName = nameController.text.trim();
        if (_isDuplicate(itemName)) {
          if (context.mounted) {
            final message = '${lw('Item')} "$itemName" ${lw('already exists in this list')}';
            showMessage(context, message, type: MessageType.warning);
          }
          return false;
        }
      }
    } else {
      // Dictionary context - check by name
      final itemName = nameController.text.trim();
      if (_isDuplicate(itemName)) {
        if (context.mounted) {
          final message = '${lw('Item')} "$itemName" ${lw('already exists in dictionary')}';
          showMessage(context, message, type: MessageType.warning);
        }
        return false;
      }
    }

    return true;
  }

  Future<void> _handleSave() async {
    if (!_validateFields()) return;

    final db = DatabaseHelper.instance;

    if (widget.dialogContext == ItemDialogContext.list) {
      await _saveListItem(db);
    } else {
      await _saveDictionaryItem(db);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _saveListItem(DatabaseHelper db) async {
    if (widget.mode == ItemDialogMode.edit) {
      final current = widget.existingItem as ListItem;
      final trimmedName = nameController.text.trim();
      final trimmedUnit = unitController.text.trim();
      final hasSelected = selectedItem != null;
      var detachFromDictionary = false;

      if (!hasSelected && current.itemId != null) {
        final currentName = current.displayName.trim();
        if (trimmedName.isNotEmpty &&
            trimmedName.toLowerCase() != currentName.toLowerCase()) {
          // User changed the name without selecting a dictionary item.
          // Treat this as an explicit switch to manual entry.
          detachFromDictionary = true;
        }
      }

      final resolvedItemId =
          hasSelected ? selectedItem.id : (detachFromDictionary ? null : current.itemId);
      final resolvedName = resolvedItemId == null ? trimmedName : null;
      final resolvedUnit =
          resolvedItemId == null && trimmedUnit.isNotEmpty ? trimmedUnit : null;

      final updated = current.copyWith(
        itemId: resolvedItemId,
        name: resolvedName,
        unit: resolvedUnit,
        quantity: quantityController.text.trim().isNotEmpty
            ? quantityController.text.trim()
            : null,
      );
      await db.updateListItem(updated);
    } else {
      // Add mode - calculate sortOrder
      final existingItems = widget.existingItems.cast<ListItem>();
      final maxOrder = existingItems.isEmpty
          ? 0
          : existingItems.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b);

      // Use saved values for place links, otherwise use controller values
      final quantityValue = isPlaceLinkSelected
          ? savedQuantity
          : (quantityController.text.trim().isNotEmpty
              ? quantityController.text.trim()
              : null);

      final unitValue = isPlaceLinkSelected
          ? savedUnit
          : (selectedItem == null && unitController.text.trim().isNotEmpty
              ? unitController.text.trim()
              : null);

      final newItem = ListItem(
        placeId: widget.placeId!,
        itemId: selectedItem?.id,
        name: selectedItem == null ? nameController.text.trim() : null,
        unit: unitValue,
        quantity: quantityValue,
        sortOrder: maxOrder + 1,
      );

      await db.insertListItem(newItem);
    }
  }

  Future<void> _saveDictionaryItem(DatabaseHelper db) async {
    if (widget.mode == ItemDialogMode.edit) {
      final current = widget.existingItem as Item;
      final updated = current.copyWith(
        name: capitalizeFirst(nameController.text.trim()),
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
      );
      await db.updateItem(updated);
    } else {
      // Add mode - calculate sortOrder
      final existingItems = widget.existingItems.cast<Item>();
      final maxOrder = existingItems.isEmpty
          ? 0
          : existingItems.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b);

      final newItem = Item(
        name: capitalizeFirst(nameController.text.trim()),
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        sortOrder: maxOrder + 1,
      );

      await db.insertItem(newItem);

      // Check if auto-sort is enabled
      final autoSortSetting = await db.getSetting('auto_sort_dict');
      if (autoSortSetting == 'true') {
        // Reload all items and sort them alphabetically
        final allItems = await db.getItems();
        allItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        await db.updateItemsOrder(allItems);
      }

      if (mounted) {
        showMessage(context, lw('Item added to dictionary'), type: MessageType.success);
      }
    }
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) return const SizedBox.shrink();

    final maxHeight = widget.dialogContext == ItemDialogContext.dictionary ? 80.0 : 100.0;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: searchResults.length,
          itemBuilder: (context, index) {
            final item = searchResults[index] as Item;
            final displayText = item.unit != null
                ? '${item.name} /${item.unit}'
                : item.name;

            if (widget.dialogContext == ItemDialogContext.dictionary) {
              // Warning-only style
              return Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(displayText, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              );
            } else {
              // Clickable style
              return InkWell(
                onTap: () => selectItem(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(displayText, style: const TextStyle(fontSize: 14)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    if (widget.dialogContext != ItemDialogContext.list) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: quantityController,
            decoration: InputDecoration(
              labelText: lw('Quantity'),
              hintText: isPlaceLinkSelected ? '*' : lw('e.g. 2'),
            ),
            keyboardType: TextInputType.number,
            enabled: !isPlaceLinkSelected,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: unitController,
            decoration: InputDecoration(
              labelText: lw('Unit'),
              hintText: isPlaceLinkSelected ? '*' : lw('e.g. kg, pcs'),
            ),
            enabled: !isPlaceLinkSelected,
          ),
        ),
        if (widget.mode == ItemDialogMode.add)
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: selectPlaceAsLink,
            tooltip: lw('Select Place'),
          ),
      ],
    );
  }

  Widget _buildUnitField() {
    if (widget.dialogContext != ItemDialogContext.dictionary) {
      return const SizedBox.shrink();
    }

    return TextField(
      controller: unitController,
      decoration: InputDecoration(
        labelText: lw('Unit'),
        hintText: lw('e.g. kg, pcs, liter'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Block editing of place links
    if (isPlaceLink) {
      return AlertDialog(
        title: Text(lw('Cannot edit place link')),
        content: Text(lw('Please delete and recreate the link')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lw('OK')),
          ),
        ],
      );
    }

    final title = widget.mode == ItemDialogMode.add
        ? lw('Add Item')
        : lw('Edit Item');

    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
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
                  hintText: widget.dialogContext == ItemDialogContext.list
                      ? lw('Search or enter item name')
                      : lw('e.g. Apples, Notebook'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: nameController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              nameController.clear();
                              searchResults = [];
                            });
                          },
                        )
                      : null,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {}); // Update suffixIcon
                  if (widget.mode == ItemDialogMode.add ||
                      (widget.mode == ItemDialogMode.edit &&
                          widget.dialogContext == ItemDialogContext.list)) {
                    searchItems(value);
                  }
                },
              ),
              const SizedBox(height: _itemVerticalSpacing),
              _buildSearchResults(),
              if (searchResults.isNotEmpty)
                const SizedBox(height: _dialogFieldSpacing),
              if (widget.dialogContext == ItemDialogContext.list)
                const SizedBox(height: _dialogFieldSpacing),
              _buildQuantityField(),
              if (widget.dialogContext == ItemDialogContext.dictionary)
                const SizedBox(height: _dialogFieldSpacing),
              _buildUnitField(),
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
          onPressed: _handleSave,
          child: Text(lw('OK')),
        ),
      ],
    );
  }
}
