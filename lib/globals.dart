// Global variables and functions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Forward declaration for app rebuild function
void Function()? rebuildApp;


const String progVersion = '0.1.260102';
const int buildNumber = 3;
const String progAuthor = 'Eugen';

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

// Show snackbar message
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
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