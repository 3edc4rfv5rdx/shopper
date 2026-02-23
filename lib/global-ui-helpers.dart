// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'global-theme-localization.dart';

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
// Returns Map with 'option' (String) and 'includeComment' (bool)
Future<Map<String, dynamic>?> showShareOptionsDialog(BuildContext context) async {
  String selectedOption = 'unpurchased'; // Default selection
  bool includeComment = false;

  return await showDialog<Map<String, dynamic>>(
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
            const SizedBox(height: 8),
            CheckboxListTile(
              title: Text(lw('With comment')),
              value: includeComment,
              onChanged: (value) => setState(() => includeComment = value ?? false),
              activeColor: clUpBar,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'option': selectedOption,
              'includeComment': includeComment,
            }),
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

// Show PIN setup dialog - returns PIN or null if cancelled
Future<String?> showSetPinDialog(BuildContext context) async {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();

  return await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        String? error;

        void validate() {
          if (pinController.text.length < 4) {
            error = lw('PIN must be at least 4 digits');
          } else if (pinController.text != confirmController.text) {
            error = lw('PINs do not match');
          } else {
            error = null;
          }
          setState(() {});
        }

        return AlertDialog(
          title: Text(lw('Set PIN')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: lw('Enter PIN'),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                onChanged: (_) => validate(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                decoration: InputDecoration(
                  labelText: lw('Confirm PIN'),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                onChanged: (_) => validate(),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lw('Cancel')),
            ),
            TextButton(
              onPressed: error == null && pinController.text.length >= 4
                  ? () => Navigator.pop(context, pinController.text)
                  : null,
              child: Text(lw('OK')),
            ),
          ],
        );
      },
    ),
  );
}

// Show PIN entry dialog - returns true if correct, false if cancelled
Future<bool> showEnterPinDialog(BuildContext context, String correctPin) async {
  final pinController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        String? error;

        return AlertDialog(
          title: Text(lw('Enter PIN')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                decoration: InputDecoration(
                  labelText: lw('PIN'),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                onChanged: (_) {
                  if (error != null) {
                    setState(() => error = null);
                  }
                },
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(lw('Cancel')),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(context, true);
                } else {
                  setState(() => error = lw('Wrong PIN'));
                }
              },
              child: Text(lw('OK')),
            ),
          ],
        );
      },
    ),
  );

  return result ?? false;
}

// Show delete item with photo dialog - returns 'move', 'delete', or null
Future<String?> showDeleteItemWithPhotoDialog(BuildContext context) async {
  String selectedOption = 'move'; // Default to safer option

  return await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(lw('Delete item with photo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(lw('Move to gallery')),
              value: 'move',
              groupValue: selectedOption,
              onChanged: (value) => setState(() => selectedOption = value!),
              activeColor: clUpBar,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            RadioListTile<String>(
              title: Text(lw('Delete photo')),
              value: 'delete',
              groupValue: selectedOption,
              onChanged: (value) => setState(() => selectedOption = value!),
              activeColor: clUpBar,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
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
