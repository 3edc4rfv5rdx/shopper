import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database.dart';
import 'place.dart';
import 'globals.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseHelper.instance;
  List<Place> places = [];
  Set<int> placesWithUnpurchased = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    setState(() => isLoading = true);
    final data = await db.getPlaces();

    // Load unpurchased counts for all places
    final Set<int> hasUnpurchased = {};
    for (final place in data) {
      final count = await db.getUnpurchasedItemsCount(place.id!);
      if (count > 0) {
        hasUnpurchased.add(place.id!);
      }
    }

    setState(() {
      places = data;
      placesWithUnpurchased = hasUnpurchased;
      isLoading = false;
    });
  }

  Future<void> addPlace() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Add Place')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: lw('Place name'),
            hintText: lw('e.g. Supermarket, Market, etc.'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lw('Add')),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newPlace = Place(
        name: nameController.text,
        sortOrder: places.length,
      );
      await db.insertPlace(newPlace);
      loadPlaces();
    }
  }

  Future<void> editPlace(Place place) async {
    final nameController = TextEditingController(text: place.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Edit Place')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: lw('Place name')),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lw('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lw('Save')),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final updatedPlace = place.copyWith(name: nameController.text);
      await db.updatePlace(updatedPlace);
      loadPlaces();
    }
  }

  Future<void> deletePlace(Place place) async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Delete Place'),
      '${lw('Are you sure you want to delete')} "${place.name}"?',
    );

    if (confirmed) {
      await db.deletePlace(place.id!);
      loadPlaces();
    }
  }

  void showPlaceContextMenu(Place place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: clMenu,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.list),
            title: Text(lw('List')),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.pushNamed(
                context,
                '/list',
                arguments: place,
              );
              loadPlaces();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(lw('Edit')),
            onTap: () {
              Navigator.pop(context);
              editPlace(place);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(lw('Delete')),
            onTap: () {
              Navigator.pop(context);
              deletePlace(place);
            },
          ),
        ],
      ),
    );
  }

  Future<void> exitApp() async {
    final confirmed = await showConfirmDialog(
      context,
      lw('Exit'),
      lw('Exit the application?'),
    );

    if (confirmed) {
      await db.vacuum();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: exitApp,
          tooltip: lw('Exit'),
        ),
        title: Text(lw('Where are we going?')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : places.isEmpty
              ? Center(
                  child: Text(lw('No places yet. Add one using the + button.')),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: places.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = places.removeAt(oldIndex);
                      places.insert(newIndex, item);
                    });
                    await db.updatePlacesOrder(places);
                  },
                  itemBuilder: (context, index) {
                    final place = places[index];
                    final hasUnpurchased = placesWithUnpurchased.contains(place.id);
                    return ListTile(
                      key: ValueKey(place.id),
                      title: Text(
                        place.name,
                        style: TextStyle(
                          fontWeight: hasUnpurchased ? fwBold : fwNormal,
                          fontSize: hasUnpurchased ? fsMedium : fsNormal,
                        ),
                      ),
                      leading: const Icon(Icons.store),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          '/list',
                          arguments: place,
                        );
                        loadPlaces();
                      },
                      onLongPress: () => showPlaceContextMenu(place),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: addPlace,
        child: const Icon(Icons.add),
      ),
    );
  }
}