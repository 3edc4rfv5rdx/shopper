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

  // Load language names from locales.json
  await loadLanguageNames();

  // Load saved language if database exists
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'shopper.db');
  final dbExists = await File(path).exists();

  if (dbExists) {
    try {
      final db = DatabaseHelper.instance;
      final savedLang = await db.getSetting('language');
      if (savedLang != null) {
        await readLocale(savedLang);
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  runApp(const ShopperApp());
}

class ShopperApp extends StatefulWidget {
  const ShopperApp({super.key});

  @override
  State<ShopperApp> createState() => _ShopperAppState();
}

class _ShopperAppState extends State<ShopperApp> {
  @override
  void initState() {
    super.initState();
    // Set global rebuild function
    rebuildApp = () {
      if (mounted) {
        setState(() {});
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          home: showWelcome ? const WelcomeScreen() : const HomeScreen(),
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}