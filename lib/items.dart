class Item {
  final int? id;
  final String name;
  final String? unit;

  Item({
    this.id,
    required this.name,
    this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: map['unit'] as String?,
    );
  }

  Item copyWith({
    int? id,
    String? name,
    String? unit,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
    );
  }
}