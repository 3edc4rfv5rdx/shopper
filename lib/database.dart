import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'place.dart';
import 'items.dart';
import 'list.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shopper.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create places table
    await db.execute('''
      CREATE TABLE places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER
      )
    ''');

    // Create items table (dictionary)
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT,
        sort_order INTEGER
      )
    ''');

    // Create lists table (shopping lists)
    await db.execute('''
      CREATE TABLE lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        place_id INTEGER NOT NULL,
        item_id INTEGER,
        name TEXT,
        unit TEXT,
        quantity TEXT,
        is_purchased INTEGER DEFAULT 0,
        sort_order INTEGER,
        FOREIGN KEY (place_id) REFERENCES places (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE SET NULL
      )
    ''');

    // Create settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sort_order column to items table
      await db.execute('ALTER TABLE items ADD COLUMN sort_order INTEGER');
    }
  }

  // ========== PLACES CRUD ==========

  Future<int> insertPlace(Place place) async {
    final db = await database;
    return await db.insert('places', place.toMap());
  }

  Future<List<Place>> getPlaces() async {
    final db = await database;
    final result = await db.query('places', orderBy: 'sort_order ASC');
    return result.map((map) => Place.fromMap(map)).toList();
  }

  Future<Place?> getPlace(int id) async {
    final db = await database;
    final result = await db.query(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Place.fromMap(result.first);
  }

  Future<int> updatePlace(Place place) async {
    final db = await database;
    return await db.update(
      'places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<int> deletePlace(int id) async {
    final db = await database;
    return await db.delete(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePlacesOrder(List<Place> places) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < places.length; i++) {
      batch.update(
        'places',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [places[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getUnpurchasedItemsCount(int placeId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM lists
      WHERE place_id = ? AND is_purchased = 0
    ''', [placeId]);
    return result.first['count'] as int;
  }

  // ========== ITEMS CRUD (dictionary) ==========

  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert('items', item.toMap());
  }

  Future<List<Item>> getItems() async {
    final db = await database;
    final result = await db.query('items', orderBy: 'sort_order ASC, name ASC');
    return result.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> searchItems(String query) async {
    final db = await database;
    final result = await db.query(
      'items',
      where: 'LOWER(name) LIKE LOWER(?)',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
      limit: 20,
    );
    return result.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItem(int id) async {
    final db = await database;
    final result = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Item.fromMap(result.first);
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateItemsOrder(List<Item> items) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(
        'items',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ========== LISTS CRUD ==========

  Future<int> insertListItem(ListItem listItem) async {
    final db = await database;
    return await db.insert('lists', listItem.toMap());
  }

  Future<List<ListItem>> getListItems(int placeId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        l.*,
        i.name as item_name,
        i.unit as item_unit
      FROM lists l
      LEFT JOIN items i ON l.item_id = i.id
      WHERE l.place_id = ?
      ORDER BY l.sort_order ASC
    ''', [placeId]);
    return result.map((map) => ListItem.fromMap(map)).toList();
  }

  Future<ListItem?> getListItem(int id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        l.*,
        i.name as item_name,
        i.unit as item_unit
      FROM lists l
      LEFT JOIN items i ON l.item_id = i.id
      WHERE l.id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    return ListItem.fromMap(result.first);
  }

  Future<int> updateListItem(ListItem listItem) async {
    final db = await database;
    return await db.update(
      'lists',
      listItem.toMap(),
      where: 'id = ?',
      whereArgs: [listItem.id],
    );
  }

  Future<int> deleteListItem(int id) async {
    final db = await database;
    return await db.delete(
      'lists',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateListItemsOrder(List<ListItem> items) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(
        'lists',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> deletePurchasedItems(int placeId) async {
    final db = await database;
    return await db.delete(
      'lists',
      where: 'place_id = ? AND is_purchased = 1',
      whereArgs: [placeId],
    );
  }

  Future<int> clearPurchasedFlags(int placeId) async {
    final db = await database;
    return await db.update(
      'lists',
      {'is_purchased': 0},
      where: 'place_id = ? AND is_purchased = 1',
      whereArgs: [placeId],
    );
  }

  // ========== SETTINGS CRUD ==========

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final result = await db.query('settings');
    return Map.fromEntries(
      result.map((row) => MapEntry(
            row['key'] as String,
            row['value'] as String,
          )),
    );
  }

  // ========== UTILITY ==========

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  // ========== BACKUP/RESTORE ==========

  Future<String> backupToCSV() async {
    final db = await database;

    // Get Documents directory
    final Directory? appDocDir = await getExternalStorageDirectory();
    if (appDocDir == null) throw Exception('Cannot access storage');

    // Create folder structure: Documents/Shopper/sh-YYYYMMDD/
    final now = DateTime.now();
    final dateFolder = 'sh-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final backupRootDir = Directory('${appDocDir.parent.parent.parent.parent.path}/Documents/Shopper');
    final backupDir = Directory('${backupRootDir.path}/$dateFolder');

    if (!await backupRootDir.exists()) {
      await backupRootDir.create(recursive: true);
    }
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // Create timestamp for filename
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final zipFileName = 'backup-$timeStr.zip';
    final zipPath = '${backupDir.path}/$zipFileName';

    // Create temporary directory for CSV files
    final tempDir = await Directory.systemTemp.createTemp('shopper_backup_');

    try {
      // Export places
      final places = await db.query('places', orderBy: 'sort_order ASC');
      final placesCSV = const ListToCsvConverter().convert([
        ['id', 'name', 'sort_order'],
        ...places.map((row) => [row['id'], row['name'], row['sort_order'] ?? ''])
      ]);
      await File('${tempDir.path}/places.csv').writeAsString(placesCSV);

      // Export items
      final items = await db.query('items', orderBy: 'sort_order ASC');
      final itemsCSV = const ListToCsvConverter().convert([
        ['id', 'name', 'unit', 'sort_order'],
        ...items.map((row) => [row['id'], row['name'], row['unit'] ?? '', row['sort_order'] ?? ''])
      ]);
      await File('${tempDir.path}/items.csv').writeAsString(itemsCSV);

      // Export lists
      final lists = await db.query('lists', orderBy: 'place_id ASC, sort_order ASC');
      final listsCSV = const ListToCsvConverter().convert([
        ['id', 'place_id', 'item_id', 'name', 'unit', 'quantity', 'is_purchased', 'sort_order'],
        ...lists.map((row) => [
          row['id'], row['place_id'], row['item_id'] ?? '', row['name'] ?? '',
          row['unit'] ?? '', row['quantity'] ?? '', row['is_purchased'], row['sort_order'] ?? ''
        ])
      ]);
      await File('${tempDir.path}/lists.csv').writeAsString(listsCSV);

      // Export settings
      final settings = await db.query('settings');
      final settingsCSV = const ListToCsvConverter().convert([
        ['key', 'value'],
        ...settings.map((row) => [row['key'], row['value'] ?? ''])
      ]);
      await File('${tempDir.path}/settings.csv').writeAsString(settingsCSV);

      // Create ZIP archive
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addFile(File('${tempDir.path}/places.csv'), 'places.csv');
      encoder.addFile(File('${tempDir.path}/items.csv'), 'items.csv');
      encoder.addFile(File('${tempDir.path}/lists.csv'), 'lists.csv');
      encoder.addFile(File('${tempDir.path}/settings.csv'), 'settings.csv');
      encoder.close();

      return zipPath;
    } finally {
      // Clean up temporary directory
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> restoreFromCSV(String zipPath) async {
    final db = await database;

    // Create temporary directory for extraction
    final tempDir = await Directory.systemTemp.createTemp('shopper_restore_');

    try {
      // Extract ZIP
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          // Use basename to get just the filename without path
          final filename = basename(file.name);
          final outFile = File('${tempDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }

      // Clear existing data (except settings)
      await db.delete('lists');
      await db.delete('items');
      await db.delete('places');

      // Helper function to parse integer from CSV
      int? parseIntOrNull(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        final str = value.toString().trim();
        if (str.isEmpty || str == 'null') return null;
        return int.tryParse(str);
      }

      // Helper function to parse string from CSV
      String? parseStringOrNull(dynamic value) {
        if (value == null) return null;
        final str = value.toString().trim();
        if (str.isEmpty || str == 'null') return null;
        return str;
      }

      // Import places
      if (await File('${tempDir.path}/places.csv').exists()) {
        final placesCSV = await File('${tempDir.path}/places.csv').readAsString();
        final placesList = const CsvToListConverter().convert(placesCSV);
        if (placesList.length > 1) {
          for (int i = 1; i < placesList.length; i++) {
            final row = placesList[i];
            await db.insert('places', {
              'id': parseIntOrNull(row[0])!,
              'name': row[1].toString(),
              'sort_order': parseIntOrNull(row[2]) ?? 0,
            });
          }
        }
      }

      // Import items
      if (await File('${tempDir.path}/items.csv').exists()) {
        final itemsCSV = await File('${tempDir.path}/items.csv').readAsString();
        final itemsList = const CsvToListConverter().convert(itemsCSV);
        final importedNames = <String>{}; // Track imported names (case-insensitive)

        if (itemsList.length > 1) {
          for (int i = 1; i < itemsList.length; i++) {
            final row = itemsList[i];
            final itemName = row[1].toString();
            final itemNameLower = itemName.toLowerCase();

            // Skip duplicates (case-insensitive)
            if (importedNames.contains(itemNameLower)) {
              continue;
            }

            await db.insert('items', {
              'id': parseIntOrNull(row[0])!,
              'name': itemName,
              'unit': parseStringOrNull(row[2]),
              'sort_order': parseIntOrNull(row[3]) ?? 0,
            });

            importedNames.add(itemNameLower);
          }
        }
      }

      // Import lists
      if (await File('${tempDir.path}/lists.csv').exists()) {
        final listsCSV = await File('${tempDir.path}/lists.csv').readAsString();
        final listsList = const CsvToListConverter().convert(listsCSV);
        if (listsList.length > 1) {
          for (int i = 1; i < listsList.length; i++) {
            final row = listsList[i];
            await db.insert('lists', {
              'id': parseIntOrNull(row[0])!,
              'place_id': parseIntOrNull(row[1])!,
              'item_id': parseIntOrNull(row[2]),
              'name': parseStringOrNull(row[3]),
              'unit': parseStringOrNull(row[4]),
              'quantity': parseStringOrNull(row[5]),
              'is_purchased': parseIntOrNull(row[6]) ?? 0,
              'sort_order': parseIntOrNull(row[7]) ?? 0,
            });
          }
        }
      }

      // Note: We don't restore settings to preserve user preferences

    } finally {
      // Clean up temporary directory
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}