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
  bool autoSortDict = false;
  bool shopModeWakelock = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final exitValue = await db.getSetting('confirm_exit');
    final sortValue = await db.getSetting('auto_sort_dict');
    final wakelockValue = await db.getSetting('shop_mode_wakelock');
    setState(() {
      confirmExit = exitValue != 'false'; // Default to true if not set
      autoSortDict = sortValue == 'true'; // Default to false if not set
      shopModeWakelock = wakelockValue != 'false'; // Default to true if not set
    });
  }

  Future<void> _toggleConfirmExit(bool value) async {
    await db.setSetting('confirm_exit', value.toString());
    setState(() {
      confirmExit = value;
    });
  }

  Future<void> _toggleAutoSortDict(bool value) async {
    await db.setSetting('auto_sort_dict', value.toString());
    setState(() {
      autoSortDict = value;
    });
  }

  Future<void> _toggleShopModeWakelock(bool value) async {
    await db.setSetting('shop_mode_wakelock', value.toString());
    setState(() {
      shopModeWakelock = value;
    });
  }

  Future<void> _backupDatabase() async {
    try {
      final zipPath = await db.backupToCSV();
      if (mounted) {
        showMessage(context, '${lw('Backup created')}: $zipPath', type: MessageType.success);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, '${lw('Backup failed')}: $e', type: MessageType.error);
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

    if (!mounted) return;

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
        showMessage(context, lw('Database restored successfully'), type: MessageType.success);
        // Rebuild app to refresh all data
        rebuildApp?.call();
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, '${lw('Restore failed')}: $e', type: MessageType.error);
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
    String? selected = currentLocale;
    final selectedLang = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lw('Language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: langNames.entries.map((entry) {
              final isSelected = selected == entry.key;
              return ListTile(
                title: Text(entry.value),
                leading: Radio<String>(
                  value: entry.key,
                  groupValue: selected,
                  onChanged: (value) {
                    setDialogState(() => selected = value);
                    Navigator.pop(context, value);
                  },
                  activeColor: clUpBar,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                tileColor: isSelected ? clSel : null,
                onTap: () {
                  setDialogState(() => selected = entry.key);
                  Navigator.pop(context, entry.key);
                },
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
    String? selected = currentTheme;
    final selectedTheme = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(lw('Color Theme')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: loadedThemes.keys.map((themeName) {
              final isSelected = selected == themeName;
              return ListTile(
                title: Text(lw(themeName)),
                leading: Radio<String>(
                  value: themeName,
                  groupValue: selected,
                  onChanged: (value) {
                    setDialogState(() => selected = value);
                    Navigator.pop(context, value);
                  },
                  activeColor: clUpBar,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                tileColor: isSelected ? clSel : null,
                onTap: () {
                  setDialogState(() => selected = themeName);
                  Navigator.pop(context, themeName);
                },
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
            leading: const Icon(Icons.inventory_2),
            title: Text(lw('Items Dictionary')),
            subtitle: Text(lw('Manage items catalog')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/items-dictionary');
            },
          ),
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
            leading: const Icon(Icons.sort_by_alpha),
            title: Text(lw('Auto-sort dictionary')),
            subtitle: Text(autoSortDict ? lw('Sort alphabetically on item add') : lw('Manual sorting only')),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: autoSortDict,
                onChanged: _toggleAutoSortDict,
              ),
            ),
            onTap: () => _toggleAutoSortDict(!autoSortDict),
          ),
          ListTile(
            leading: const Icon(Icons.light_mode),
            title: Text(lw('Keep screen on in shop mode')),
            subtitle: Text(shopModeWakelock ? lw('Screen stays on') : lw('Normal screen timeout')),
            trailing: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: shopModeWakelock,
                onChanged: _toggleShopModeWakelock,
              ),
            ),
            onTap: () => _toggleShopModeWakelock(!shopModeWakelock),
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