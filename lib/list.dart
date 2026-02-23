const _unset = Object();

class ListItem {
  final int? id;
  final int placeId;
  final int? itemId; // null or 0 if manually entered
  final String? name; // used only if itemId is null
  final String? unit; // used only if itemId is null
  final String? quantity;
  final bool isPurchased;
  final int sortOrder;

  // Fields from joined Item (when itemId is not null)
  final String? itemName;
  final String? itemUnit;

  ListItem({
    this.id,
    required this.placeId,
    this.itemId,
    this.name,
    this.unit,
    this.quantity,
    this.isPurchased = false,
    required this.sortOrder,
    this.itemName,
    this.itemUnit,
  });

  // Get display name (from item or manual entry)
  String get displayName {
    final displayValue = itemName ?? name ?? '';
    return displayValue == 'null' ? '' : displayValue;
  }

  // Get display unit (from item or manual entry)
  String get displayUnit {
    final displayValue = itemUnit ?? unit ?? '';
    return displayValue == 'null' ? '' : displayValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'place_id': placeId,
      'item_id': itemId,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'is_purchased': isPurchased ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory ListItem.fromMap(Map<String, dynamic> map) {
    return ListItem(
      id: map['id'] as int?,
      placeId: map['place_id'] as int,
      itemId: map['item_id'] as int?,
      name: map['name'] as String?,
      unit: map['unit'] as String?,
      quantity: map['quantity'] as String?,
      isPurchased: (map['is_purchased'] as int) == 1,
      sortOrder: map['sort_order'] as int,
      itemName: map['item_name'] as String?,
      itemUnit: map['item_unit'] as String?,
    );
  }

  ListItem copyWith({
    int? id,
    int? placeId,
    Object? itemId = _unset,
    Object? name = _unset,
    Object? unit = _unset,
    Object? quantity = _unset,
    bool? isPurchased,
    int? sortOrder,
    Object? itemName = _unset,
    Object? itemUnit = _unset,
  }) {
    return ListItem(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      itemId: identical(itemId, _unset) ? this.itemId : itemId as int?,
      name: identical(name, _unset) ? this.name : name as String?,
      unit: identical(unit, _unset) ? this.unit : unit as String?,
      quantity: identical(quantity, _unset) ? this.quantity : quantity as String?,
      isPurchased: isPurchased ?? this.isPurchased,
      sortOrder: sortOrder ?? this.sortOrder,
      itemName: identical(itemName, _unset) ? this.itemName : itemName as String?,
      itemUnit: identical(itemUnit, _unset) ? this.itemUnit : itemUnit as String?,
    );
  }
}
