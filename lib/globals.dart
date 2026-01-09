// Global variables and functions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'database.dart';
import 'list.dart';
import 'items.dart';
import 'place.dart';

const String progVersion = '0.7.260107';
const int buildNumber = 15;
const String progAuthor = 'Eugen';
bool xvDebug = true;

// Forward declaration for app rebuild function
void Function()? rebuildApp;

// Font setups
const double fsSmall = 14;
const double fsNormal = 16;
const double fsMedium = 18;
const double fsLarge = 20;
const double fsTitle = 24;
const FontWeight fwNormal = FontWeight.normal;
const FontWeight fwMedium = FontWeight.w500;
const FontWeight fwBold = FontWeight.bold;

// ========== COLOR THEMES ==========

// Path to colors file
const String colorsFile = 'assets/colors.json';

// Current theme colors (will be set based on selected theme)
late Color clText;
late Color clBgrnd;
late Color clUpBar;
late Color clFill;
late Color clSel;
late Color clMenu;

// Constant colors
const Color clRed = Colors.red;
const Color clWhite = Colors.white;

// Loaded themes from JSON
Map<String, Map<String, String>> loadedThemes = {};

// Current theme name
String currentTheme = 'Light';

// Convert hex string to Color
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex'; // Add alpha if not present
  }
  return Color(int.parse(hex, radix: 16));
}

// Load all themes from colors.json
Future<void> loadThemes() async {
  try {
    final jsonString = await rootBundle.loadString(colorsFile);
    final Map<String, dynamic> themesData = json.decode(jsonString);

    loadedThemes = {};
    themesData.forEach((themeName, colors) {
      if (colors is Map) {
        loadedThemes[themeName] = Map<String, String>.from(colors);
      }
    });

    debugPrint('Loaded ${loadedThemes.length} themes: ${loadedThemes.keys.join(', ')}');
  } catch (e) {
    debugPrint('Error loading themes: $e');
    // Fallback to default theme
    loadedThemes = {
      'Light': {
        'text': '#000000',
        'background': '#F5EFD5',
        'appBar': '#E6C94C',
        'fill': '#F9F3E3',
        'selected': '#FFCC80',
        'menu': '#ADD8E6',
      }
    };
  }
}

// Apply selected theme
void applyTheme(String themeName) {
  if (!loadedThemes.containsKey(themeName)) {
    debugPrint('Theme $themeName not found, using Light');
    themeName = 'Light';
  }

  final theme = loadedThemes[themeName]!;
  currentTheme = themeName;

  clText = hexToColor(theme['text'] ?? '#000000');
  clBgrnd = hexToColor(theme['background'] ?? '#FFFFFF');
  clUpBar = hexToColor(theme['appBar'] ?? '#2196F3');
  clFill = hexToColor(theme['fill'] ?? '#FFFFFF');
  clSel = hexToColor(theme['selected'] ?? '#90CAF9');
  clMenu = hexToColor(theme['menu'] ?? '#CFD8DC');

  debugPrint('Applied theme: $themeName');
}

// ========== LOCALIZATION ==========

// Path to locales file
const String localesFile = 'assets/locales.json';

// Supported languages with their names (loaded dynamically from locales.json)
Map<String, String> langNames = {};

// Translation cache for current language
Map<String, String> _uiLocale = {};

// Current locale
String currentLocale = 'en';

// Check if language is supported
bool isLanguageSupported(String locale) {
  return langNames.containsKey(locale.toLowerCase());
}

// Localization function - main translation function
String lw(String text) {
  if (currentLocale == 'en') {
    return text;
  }
  return _uiLocale[text] ?? text;
}

// Load language names from locales file
Future<void> loadLanguageNames() async {
  try {
    final jsonString = await rootBundle.loadString(localesFile);
    final Map<String, dynamic> allTranslations = json.decode(jsonString);

    // Get language names from _language_name section
    if (allTranslations.containsKey('_language_name')) {
      final languageNamesSection = allTranslations['_language_name'];
      if (languageNamesSection is Map) {
        langNames = Map<String, String>.from(languageNamesSection);
        debugPrint('Loaded ${langNames.length} language names: ${langNames.keys.join(', ')}');
      }
    }
  } catch (e) {
    debugPrint('Error loading language names: $e');
    // Fallback to default if loading fails
    langNames = {'en': 'English'};
  }
}

// Read localizations from file
Future<void> readLocale(String locale) async {
  locale = locale.toLowerCase();

  // Check if language is supported
  if (!isLanguageSupported(locale)) {
    debugPrint('Language $locale not supported, using English instead');
    currentLocale = 'en';
  } else {
    currentLocale = locale;
  }

  // For English, no cache needed
  if (currentLocale == 'en') {
    _uiLocale = {};
    return;
  }

  try {
    // Load JSON file with localizations
    final jsonString = await rootBundle.loadString(localesFile);
    final Map<String, dynamic> allTranslations = json.decode(jsonString);

    // Create empty cache
    _uiLocale = {};

    // Fill cache with translations for current locale
    allTranslations.forEach((key, value) {
      if (value is Map && value.containsKey(currentLocale)) {
        _uiLocale[key] = value[currentLocale];
      }
    });

    debugPrint('Loaded ${_uiLocale.length} translations for $currentLocale');
  } catch (e) {
    debugPrint('Error loading translations: $e');
    _uiLocale = {};
  }
}

// ========== OTHER GLOBALS ==========

// Global database instance (will be initialized in main.dart)
// DatabaseHelper? db;

// Message types for colored notifications
enum MessageType {
  success,  // Green
  warning,  // Orange
  error,    // Red
  info,     // Blue
}

// Show snackbar message with color based on type
void showMessage(
  BuildContext context,
  String message, {
  MessageType type = MessageType.info,
}) {
  Color backgroundColor;
  Color textColor = Colors.white;

  switch (type) {
    case MessageType.success:
      backgroundColor = Colors.green.shade600;
      break;
    case MessageType.warning:
      backgroundColor = Colors.orange.shade600;
      break;
    case MessageType.error:
      backgroundColor = Colors.red.shade600;
      break;
    case MessageType.info:
      backgroundColor = Colors.blue.shade600;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: textColor)),
      backgroundColor: backgroundColor,
    ),
  );
}

// Show confirmation dialog
Future<bool> showConfirmDialog(
  BuildContext context,
  String title,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
  return result ?? false;
}

// Show share options dialog
Future<String?> showShareOptionsDialog(BuildContext context) async {
  String selectedOption = 'unpurchased'; // Default selection

  return await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(lw('Share List')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(lw('Only unpurchased items')),
              value: 'unpurchased',
              groupValue: selectedOption,
              onChanged: (value) => setState(() => selectedOption = value!),
              activeColor: clUpBar,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              tileColor: selectedOption == 'unpurchased' ? clSel : null,
            ),
            RadioListTile<String>(
              title: Text(lw('All items')),
              value: 'all',
              groupValue: selectedOption,
              onChanged: (value) => setState(() => selectedOption = value!),
              activeColor: clUpBar,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              tileColor: selectedOption == 'all' ? clSel : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selectedOption),
            child: Text(lw('OK')),
          ),
        ],
      ),
    ),
  );
}

// Capitalize first letter of string
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

// Show top menu (replaces bottom sheet with top-aligned menu)
Future<T?> showTopMenu<T>({
  required BuildContext context,
  required List<Widget> items,
}) async {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final maxHeight = screenHeight * 0.67; // 2/3 of screen height

      return Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(top: 80), // Below app bar
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: clMenu,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        ),
      );
    },
  );
}

// ========== UNIFIED ITEM DIALOG ==========

// List spacing constants
const double _itemVerticalSpacing = 8.0;
const double _dialogFieldSpacing = 16.0;

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

  Future<void> selectPlaceAsLink() async {
    final db = DatabaseHelper.instance;
    final places = await db.getPlaces();

    // Exclude current Place
    final availablePlaces = places.where((p) => p.id != widget.placeId).toList();

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
        quantityController.text = '-1'; // Link marker
        unitController.text = '-${selectedPlace.id}'; // Place ID with minus
        searchResults = [];
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

    // Check for duplicates (skip for place links)
    final isPlaceLinkNew = quantityController.text.trim() == '-1';
    if (!isPlaceLinkNew) {
      final itemName = nameController.text.trim();
      if (_isDuplicate(itemName)) {
        if (context.mounted) {
          final message = widget.dialogContext == ItemDialogContext.list
              ? '${lw('Item')} "$itemName" ${lw('already exists in this list')}'
              : '${lw('Item')} "$itemName" ${lw('already exists in dictionary')}';
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
      final updated = current.copyWith(
        itemId: selectedItem?.id,
        name: selectedItem == null ? nameController.text.trim() : null,
        unit: selectedItem == null && unitController.text.trim().isNotEmpty
            ? unitController.text.trim()
            : null,
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

      final newItem = ListItem(
        placeId: widget.placeId!,
        itemId: selectedItem?.id,
        name: selectedItem == null ? nameController.text.trim() : null,
        unit: selectedItem == null && unitController.text.trim().isNotEmpty
            ? unitController.text.trim()
            : null,
        quantity: quantityController.text.trim().isNotEmpty
            ? quantityController.text.trim()
            : null,
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

      if (mounted) {
        showMessage(context, lw('Item added to dictionary'), type: MessageType.success);
      }
    }
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) return const SizedBox.shrink();

    final maxHeight = widget.dialogContext == ItemDialogContext.dictionary ? 150.0 : 200.0;
    final isClickable = widget.dialogContext == ItemDialogContext.list;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final item = searchResults[index] as Item;

          if (widget.dialogContext == ItemDialogContext.dictionary) {
            // Warning-only style
            return ListTile(
              title: Text(item.name),
              subtitle: item.unit != null ? Text(item.unit!) : null,
              dense: true,
              tileColor: Colors.orange.shade50,
              leading: const Icon(Icons.warning, color: Colors.orange, size: 20),
            );
          } else {
            // Clickable style
            return ListTile(
              title: Text(item.name),
              subtitle: item.unit != null ? Text(item.unit!) : null,
              dense: true,
              onTap: isClickable ? () => selectItem(item) : null,
            );
          }
        },
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
                      : lw('e.g. Milk, Bread'),
                  suffixIcon: nameController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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