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
    int? itemId,
    String? name,
    String? unit,
    String? quantity,
    bool? isPurchased,
    int? sortOrder,
    String? itemName,
    String? itemUnit,
  }) {
    return ListItem(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      isPurchased: isPurchased ?? this.isPurchased,
      sortOrder: sortOrder ?? this.sortOrder,
      itemName: itemName ?? this.itemName,
      itemUnit: itemUnit ?? this.itemUnit,
    );
  }
}