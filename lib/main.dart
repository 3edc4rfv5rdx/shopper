import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'routes.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';
import 'database.dart';
import 'globals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load color themes from colors.json
  await loadThemes();

  // Load language names from locales.json
  await loadLanguageNames();

  // Load saved settings if database exists
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'shopper.db');
  final dbExists = await File(path).exists();

  if (dbExists) {
    try {
      final db = DatabaseHelper.instance;

      // Load saved language
      final savedLang = await db.getSetting('language');
      if (savedLang != null) {
        await readLocale(savedLang);
      }

      // Load and apply saved theme
      final savedTheme = await db.getSetting('theme');
      if (savedTheme != null && loadedThemes.containsKey(savedTheme)) {
        applyTheme(savedTheme);
      } else {
        applyTheme('Light'); // Default theme
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      applyTheme('Light'); // Default theme on error
    }
  } else {
    // First run - apply default theme
    applyTheme('Light');
  }

  runApp(const ShopperApp());
}

class ShopperApp extends StatefulWidget {
  const ShopperApp({super.key});

  @override
  State<ShopperApp> createState() => _ShopperAppState();
}

class _ShopperAppState extends State<ShopperApp> {
  Key _homeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Set global rebuild function
    rebuildApp = () {
      if (mounted) {
        setState(() {
          // Create new key to force HomeScreen rebuild
          _homeKey = UniqueKey();
        });
      }
    };
  }

  Future<bool> _isDatabaseExists() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'shopper.db');
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isDatabaseExists(),
      builder: (context, snapshot) {
        // Show loading while checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Determine which screen to show
        final showWelcome = !(snapshot.data ?? false);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Shopper',
          theme: ThemeData(
            colorScheme: ColorScheme.light(
              primary: clUpBar,
              surface: clBgrnd,
              onPrimary: clText,
              onSurface: clText,
            ),
            scaffoldBackgroundColor: clBgrnd,
            appBarTheme: AppBarTheme(
              backgroundColor: clUpBar,
              foregroundColor: clText,
            ),
            useMaterial3: true,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: clUpBar,
                foregroundColor: clText,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: clFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          home: showWelcome ? const WelcomeScreen() : HomeScreen(key: _homeKey),
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}