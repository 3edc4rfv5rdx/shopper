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
  Set<int> lockedPlaces = {};
  Place? currentFolder;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  List<Place> get _folders =>
      places.where((p) => p.isFolder).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Place> get _rootLists =>
      places.where((p) => !p.isFolder && p.parentId == null).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Place> _childrenOf(int folderId) =>
      places.where((p) => !p.isFolder && p.parentId == folderId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<Place> get _visibleLists {
    if (currentFolder == null) return _rootLists;
    return _childrenOf(currentFolder!.id!);
  }

  List<Place> get _visibleFolders => currentFolder == null ? _folders : [];

  Future<void> loadPlaces() async {
    setState(() => isLoading = true);
    final data = await db.getPlaces();

    final Set<int> hasUnpurchased = {};
    final Set<int> allPurchased = {};
    final Set<int> locked = {};

    for (final place in data) {
      if (place.id == null) continue;

      if (!place.isFolder) {
        final unpurchasedCount = await db.getUnpurchasedItemsCount(place.id!);
        final totalCount = await db.getTotalItemsCount(place.id!);
        if (unpurchasedCount > 0) {
          hasUnpurchased.add(place.id!);
        } else if (totalCount > 0) {
          allPurchased.add(place.id!);
        }

        final isLocked = await db.isPlaceLocked(place.id!);
        if (isLocked) {
          locked.add(place.id!);
        }
      }
    }

    setState(() {
      places = data;
      placesWithUnpurchased = hasUnpurchased;
      placesAllPurchased = allPurchased;
      lockedPlaces = locked;
      isLoading = false;
    });
  }

  Future<void> _addPlaceLike({required bool asFolder}) async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(asFolder ? lw('Add Folder') : lw('Add Place')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: asFolder ? lw('Folder name') : lw('Place name'),
            hintText: asFolder
                ? lw('e.g. Weekly, Markets, Household')
                : lw('e.g. Groceries, Tasks, Ideas'),
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      final newPlace = Place(
        name: nameController.text.trim(),
        sortOrder: places.length,
        isFolder: asFolder,
        parentId: asFolder ? null : currentFolder?.id,
      );
      await db.insertPlace(newPlace);
      if (mounted) loadPlaces();
    }
  }

  Future<void> addPlace() async => _addPlaceLike(asFolder: false);
  Future<void> addFolder() async => _addPlaceLike(asFolder: true);

  Future<void> editPlace(Place place) async {
    final nameController = TextEditingController(text: place.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place.isFolder ? lw('Edit Folder') : lw('Edit Place')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: place.isFolder ? lw('Folder name') : lw('Place name'),
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      final updatedPlace = place.copyWith(name: nameController.text.trim());
      await db.updatePlace(updatedPlace);
      if (mounted) loadPlaces();
    }
  }

  Future<void> movePlaceToFolder(Place place) async {
    final folders = _folders;
    if (folders.isEmpty) {
      showMessage(context, lw('No folders yet. Create one first.'), type: MessageType.warning);
      return;
    }

    final target = await showDialog<Place>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lw('Select folder')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.name),
                onTap: () => Navigator.pop(context, folder),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lw('Cancel')),
          ),
        ],
      ),
    );

    if (target == null) return;
    await db.updatePlaceParent(place.id!, target.id);
    if (mounted) {
      loadPlaces();
      showMessage(context, lw('Moved to folder'), type: MessageType.success);
    }
  }

  Future<void> removeFromFolder(Place place) async {
    await db.updatePlaceParent(place.id!, null);
    if (mounted) {
      loadPlaces();
      showMessage(context, lw('Removed from folder'), type: MessageType.success);
    }
  }

  Future<void> deletePlace(Place place) async {
    if (!place.isFolder) {
      final isLocked = await db.isPlaceLocked(place.id!);
      if (isLocked) {
        final pin = await db.getPlacePin(place.id!);
        if (!mounted) return;
        if (pin != null) {
          final correct = await showEnterPinDialog(context, pin);
          if (!mounted || !correct) return;
        }
      }
    }

    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      place.isFolder ? lw('Delete Folder') : lw('Delete Place'),
      '${lw('Are you sure you want to delete')} "${place.name}"?',
    );

    if (!confirmed) return;

    if (place.isFolder) {
      await db.clearFolderChildren(place.id!);
      await db.deletePlace(place.id!);
      if (mounted) loadPlaces();
      return;
    }

    final items = await db.getListItems(place.id!);
    final itemsWithPhotos = <int>[];
    for (final item in items) {
      if (await hasPhoto(item.id!)) {
        itemsWithPhotos.add(item.id!);
      }
    }

    if (itemsWithPhotos.isNotEmpty && mounted) {
      final photoAction = await showDeleteItemWithPhotoDialog(context);
      if (photoAction == null) return;

      for (final itemId in itemsWithPhotos) {
        if (photoAction == 'move') {
          await movePhotoToGallery(itemId);
        } else {
          await deletePhoto(itemId);
        }
      }
    }

    await db.deletePlace(place.id!);
    if (mounted) loadPlaces();
  }

  Future<void> showPlaceContextMenu(Place place) async {
    final isLocked = !place.isFolder && await db.isPlaceLocked(place.id!);

    if (!mounted) return;

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
        if (!place.isFolder)
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(lw('Move to folder')),
            onTap: () {
              Navigator.pop(context);
              movePlaceToFolder(place);
            },
          ),
        if (!place.isFolder && place.parentId != null)
          ListTile(
            leading: const Icon(Icons.folder_off),
            title: Text(lw('Remove from folder')),
            onTap: () {
              Navigator.pop(context);
              removeFromFolder(place);
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
        if (!place.isFolder)
          ListTile(
            leading: Icon(isLocked ? Icons.lock_open : Icons.lock),
            title: Text(isLocked ? lw('Unlock') : lw('Lock')),
            onTap: () {
              Navigator.pop(context);
              if (isLocked) {
                unlockPlace(place);
              } else {
                lockPlace(place);
              }
            },
          ),
      ],
    );
  }

  Future<void> lockPlace(Place place) async {
    final pin = await showSetPinDialog(context);
    if (pin != null && mounted) {
      await db.setPlacePin(place.id!, pin);
      loadPlaces();
      if (mounted) {
        showMessage(context, lw('List locked'), type: MessageType.success);
      }
    }
  }

  Future<void> unlockPlace(Place place) async {
    final pin = await db.getPlacePin(place.id!);
    if (pin == null) return;

    if (!mounted) return;
    final correct = await showEnterPinDialog(context, pin);
    if (correct && mounted) {
      await db.removePlacePin(place.id!);
      loadPlaces();
      if (mounted) {
        showMessage(context, lw('List unlocked'), type: MessageType.success);
      }
    }
  }

  Future<void> openPlace(Place place) async {
    final isLocked = lockedPlaces.contains(place.id);
    if (isLocked) {
      final pin = await db.getPlacePin(place.id!);
      if (!mounted) return;
      if (pin != null) {
        final correct = await showEnterPinDialog(context, pin);
        if (!mounted || !correct) return;
      }
    }

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/list',
      arguments: place,
    );
    if (!mounted) return;
    loadPlaces();
  }

  void openFolder(Place folder) {
    setState(() {
      currentFolder = folder;
    });
  }

  void exitFolderView() {
    setState(() {
      currentFolder = null;
    });
  }

  Future<void> exitApp() async {
    final confirmExitSetting = await db.getSetting('confirm_exit');
    if (!mounted) return;
    final requireConfirmation = confirmExitSetting != 'false';

    var confirmed = true;
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

  Widget _buildPlaceTile(Place place) {
    final hasUnpurchased = placesWithUnpurchased.contains(place.id);
    final allPurchased = placesAllPurchased.contains(place.id);
    final isLocked = lockedPlaces.contains(place.id);

    final tile = ListTile(
      key: ValueKey('tile_${place.id}_root'),
      title: Text(
        place.name,
        style: TextStyle(
          fontWeight: place.isFolder
              ? fwBold
              : (hasUnpurchased ? fwBold : fwNormal),
          fontSize: place.isFolder
              ? fsMedium
              : (hasUnpurchased ? fsMedium : fsNormal),
          decoration: allPurchased ? TextDecoration.lineThrough : null,
        ),
      ),
      leading: place.isFolder
          ? const Icon(Icons.folder)
          : Icon(isLocked ? Icons.lock : Icons.list_alt),
      onTap: place.isFolder ? () => openFolder(place) : () => openPlace(place),
      onLongPress: () => showPlaceContextMenu(place),
    );

    return Dismissible(
      key: ValueKey('dismiss_${place.id}_root'),
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
          editPlace(place);
        } else {
          deletePlace(place);
        }
        return false;
      },
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleLists = _visibleLists;
    final visibleFolders = _visibleFolders;

    return Scaffold(
      appBar: AppBar(
        leading: currentFolder == null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: exitApp,
                tooltip: lw('Exit'),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: exitFolderView,
                tooltip: lw('Back'),
              ),
        title: Text(currentFolder?.name ?? lw('Lists')),
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
                  child: Text(
                    lw('No places yet. Add one using the + button.'),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  children: [
                    for (final place in visibleLists) _buildPlaceTile(place),
                    for (final folder in visibleFolders) _buildPlaceTile(folder),
                    if (currentFolder != null && visibleLists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          lw('No items yet. Add one using the + button.'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentFolder == null) ...[
            FloatingActionButton(
              heroTag: 'add_folder',
              mini: true,
              onPressed: addFolder,
              tooltip: lw('Add Folder'),
              child: const Icon(Icons.create_new_folder),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            heroTag: 'add_place',
            onPressed: addPlace,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
