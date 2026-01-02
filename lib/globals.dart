// Global variables and functions

import 'package:flutter/material.dart';

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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return result ?? false;
}