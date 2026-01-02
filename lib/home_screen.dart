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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    setState(() => isLoading = true);
    final data = await db.getPlaces();
    setState(() {
      places = data;
      isLoading = false;
    });
  }

  Future<void> addPlace() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Place'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Place name',
            hintText: 'e.g. Supermarket, Market, etc.',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
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
        title: const Text('Edit Place'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Place name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
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
      'Delete Place',
      'Are you sure you want to delete "${place.name}"?',
    );

    if (confirmed) {
      await db.deletePlace(place.id!);
      loadPlaces();
    }
  }

  void showPlaceContextMenu(Place place) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('List'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/list',
                arguments: place,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              editPlace(place);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
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
      'Exit',
      'Exit the application?',
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
          tooltip: 'Exit',
        ),
        title: const Text('Where are we going?'),
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
              ? const Center(
                  child: Text('No places yet. Add one using the + button.'),
                )
              : ReorderableListView.builder(
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
                    return ListTile(
                      key: ValueKey(place.id),
                      title: Text(place.name),
                      leading: const Icon(Icons.store),
                      trailing: const Icon(Icons.drag_handle),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/list',
                          arguments: place,
                        );
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