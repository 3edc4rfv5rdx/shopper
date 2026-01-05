class Item {
  final int? id;
  final String name;
  final String? unit;
  final int sortOrder;

  Item({
    this.id,
    required this.name,
    this.unit,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'sort_order': sortOrder,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: map['unit'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Item copyWith({
    int? id,
    String? name,
    String? unit,
    int? sortOrder,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}