import 'package:flutter/material.dart';
import 'database.dart';
import 'globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final db = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showMessage(context, 'Language selection - Coming soon');
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Light'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showMessage(context, 'Theme selection - Coming soon');
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Color Scheme'),
            subtitle: const Text('Blue'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showMessage(context, 'Color scheme - Coming soon');
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Items Dictionary'),
            subtitle: const Text('Manage items catalog'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/items-dictionary');
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Database'),
            subtitle: const Text('Export all data to file'),
            onTap: () {
              showMessage(context, 'Backup - Coming soon');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Database'),
            subtitle: const Text('Import data from file'),
            onTap: () {
              showMessage(context, 'Restore - Coming soon');
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}