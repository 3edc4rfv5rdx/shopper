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
  Set<int> placesAllPurchased = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    setState(() => isLoading = true);
    final data = await db.getPlaces();

    // Load item counts for all places
    final Set<int> hasUnpurchased = {};
    final Set<int> allPurchased = {};
    for (final place in data) {
      final unpurchasedCount = await db.getUnpurchasedItemsCount(place.id!);
      final totalCount = await db.getTotalItemsCount(place.id!);
      if (unpurchasedCount > 0) {
        hasUnpurchased.add(place.id!);
      } else if (totalCount > 0) {
        // Has items but all are purchased
        allPurchased.add(place.id!);
      }
    }

    setState(() {
      places = data;
      placesWithUnpurchased = hasUnpurchased;
      placesAllPurchased = allPurchased;
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
            child: Text(lw('OK')),
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
            child: Text(lw('OK')),
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
    showTopMenu(
      context: context,
      items: [
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
    );
  }

  Future<void> exitApp() async {
    // Check if confirmation is required
    final confirmExitSetting = await db.getSetting('confirm_exit');
    if (!mounted) return;
    final requireConfirmation = confirmExitSetting != 'false';

    bool confirmed = true;
    if (requireConfirmation) {
      confirmed = await showConfirmDialog(
        context,
        lw('Exit'),
        lw('Exit the application?'),
      );
    }

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
        title: Text(lw('Lists')),
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
                    final allPurchased = placesAllPurchased.contains(place.id);
                    return Dismissible(
                      key: ValueKey(place.id),
                      background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Swipe right - edit
                          editPlace(place);
                          return false;
                        } else {
                          // Swipe left - delete with confirmation
                          return await showConfirmDialog(
                            context,
                            lw('Delete Place'),
                            '${lw('Are you sure you want to delete')} "${place.name}"?',
                          );
                        }
                      },
                      onDismissed: (direction) {
                        // Only called if confirmDismiss returns true (delete confirmed)
                        db.deletePlace(place.id!);
                        loadPlaces();
                      },
                      child: ListTile(
                        key: ValueKey('tile_${place.id}'),
                        title: Text(
                          place.name,
                          style: TextStyle(
                            fontWeight: hasUnpurchased ? fwBold : fwNormal,
                            fontSize: hasUnpurchased ? fsMedium : fsNormal,
                            decoration: allPurchased ? TextDecoration.lineThrough : null,
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
                      ),
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