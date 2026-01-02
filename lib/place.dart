class Place {
  final int? id;
  final String name;
  final int sortOrder;

  Place({
    this.id,
    required this.name,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
    );
  }

  Place copyWith({
    int? id,
    String? name,
    int? sortOrder,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}