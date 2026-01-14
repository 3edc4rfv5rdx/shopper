class Place {
  final int? id;
  final String name;
  final int sortOrder;
  final String? comment;

  Place({
    this.id,
    required this.name,
    required this.sortOrder,
    this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'comment': comment,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      comment: map['comment'] as String?,
    );
  }

  Place copyWith({
    int? id,
    String? name,
    int? sortOrder,
    String? comment,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      comment: comment ?? this.comment,
    );
  }
}