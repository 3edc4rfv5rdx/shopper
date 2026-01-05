import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
      where: 'name LIKE ?',
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

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}