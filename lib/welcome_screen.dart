import 'package:flutter/material.dart';
import 'database.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final db = DatabaseHelper.instance;
  String selectedLanguage = 'en';
  String selectedTheme = 'system';

  final languages = {
    'en': 'English',
    'ru': 'Русский',
    'ua': 'Українська',
  };

  final themes = {
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
  };

  Future<void> saveAndContinue() async {
    await db.setSetting('language', selectedLanguage);
    await db.setSetting('theme', selectedTheme);
    await db.setSetting('onboarding_completed', 'true');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.shopping_cart,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Shopper',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Let\'s set up your preferences',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Language selection
              const Text(
                'Language',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...languages.entries.map((entry) => RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: selectedLanguage,
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value!;
                      });
                    },
                    activeColor: Colors.blue,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: selectedLanguage == entry.key
                        ? Colors.blue.withOpacity(0.1)
                        : null,
                  )),

              const SizedBox(height: 24),

              // Theme selection
              const Text(
                'Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...themes.entries.map((entry) => RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: selectedTheme,
                    onChanged: (value) {
                      setState(() {
                        selectedTheme = value!;
                      });
                    },
                    activeColor: Colors.blue,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: selectedTheme == entry.key
                        ? Colors.blue.withOpacity(0.1)
                        : null,
                  )),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}