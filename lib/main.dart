import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'routes.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShopperApp());
}

class ShopperApp extends StatelessWidget {
  const ShopperApp({super.key});

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