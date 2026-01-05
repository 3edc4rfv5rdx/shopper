import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'database.dart';
import 'globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final db = DatabaseHelper.instance;
  bool confirmExit = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final value = await db.getSetting('confirm_exit');
    setState(() {
      confirmExit = value != 'false'; // Default to true if not set
    });
  }

  Future<void> _toggleConfirmExit(bool value) async {
    await db.setSetting('confirm_exit', value.toString());
    setState(() {
      confirmExit = value;
    });
  }

  Future<void> _backupDatabase() async {
    try {
      final zipPath = await db.backupToCSV();
      if (mounted) {
        showMessage(context, '${lw('Backup created')}: $zipPath');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, '${lw('Backup failed')}: $e');
      }
    }
  }

  Future<void> _restoreDatabase() async {
    // Show file picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    // Confirm restore
    final confirmed = await showConfirmDialog(
      context,
      lw('Restore Database'),
      lw('This will replace all current data. Continue?'),
    );

    if (!confirmed) return;

    try {
      await db.restoreFromCSV(result.files.single.path!);
      if (mounted) {
        showMessage(context, lw('Database restored successfully'));
        // Rebuild app to refresh all data
        rebuildApp?.call();
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, '${lw('Restore failed')}: $e');
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Text(lw('About')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shopper',
                  style: const TextStyle(
                    fontSize: fsLarge,
                    fontWeight: fwBold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(lw('Version'), progVersion),
                const SizedBox(height: 8),
                _buildInfoRow(lw('Build'), buildNumber.toString()),
                const SizedBox(height: 8),
                _buildInfoRow(lw('Author'), progAuthor),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lw('OK')),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: fwMedium,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: fwNormal,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showLanguageDialog() async {
    final selectedLang = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(lw('Language')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: langNames.entries.map((entry) {
                final isSelected = currentLocale == entry.key;
                return RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: currentLocale,
                  onChanged: (value) => Navigator.pop(context, value),
                  activeColor: clUpBar,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: isSelected ? clSel : null,
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lw('Cancel')),
              ),
            ],
          ),
    );

    if (selectedLang != null && selectedLang != currentLocale) {
      // Save to database
      await db.setSetting('language', selectedLang);

      // Load new locale
      await readLocale(selectedLang);

      // Rebuild the entire app
      rebuildApp?.call();
    }
  }

  Future<void> _showThemeDialog() async {
    final selectedTheme = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(lw('Color Theme')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: loadedThemes.keys.map((themeName) {
                final isSelected = currentTheme == themeName;
                return RadioListTile<String>(
                  title: Text(lw(themeName)),
                  value: themeName,
                  groupValue: currentTheme,
                  onChanged: (value) => Navigator.pop(context, value),
                  activeColor: clUpBar,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tileColor: isSelected ? clSel : null,
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lw('Cancel')),
              ),
            ],
          ),
    );

    if (selectedTheme != null && selectedTheme != currentTheme) {
      // Save to database
      await db.setSetting('theme', selectedTheme);

      // Apply new theme
      applyTheme(selectedTheme);

      // Rebuild the entire app
      rebuildApp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lw('Settings')),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(lw('Language')),
            subtitle: Text(langNames[currentLocale] ?? 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(lw('Color Theme')),
            subtitle: Text(lw(currentTheme)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showThemeDialog,
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: Text(lw('Confirm on exit')),
            subtitle: Text(confirmExit ? lw('Ask before exit') : lw('Exit immediately')),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: confirmExit,
                onChanged: _toggleConfirmExit,
              ),
            ),
            onTap: () => _toggleConfirmExit(!confirmExit),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: Text(lw('Items Dictionary')),
            subtitle: Text(lw('Manage items catalog')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/items-dictionary');
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: Text(lw('Backup Database')),
            subtitle: Text(lw('Export all data to file')),
            onTap: _backupDatabase,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(lw('Restore Database')),
            subtitle: Text(lw('Import data from file')),
            onTap: _restoreDatabase,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(lw('Version')),
            subtitle: Text(progVersion),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }
}