// Global variables and functions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

const String progVersion = '0.7.260107';
const int buildNumber = 13;
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