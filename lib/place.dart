const _unset = Object();

class Place {
  final int? id;
  final String name;
  final int sortOrder;
  final String? comment;
  final int? parentId; // Folder ID, null for root
  final bool isFolder;

  Place({
    this.id,
    required this.name,
    required this.sortOrder,
    this.comment,
    this.parentId,
    this.isFolder = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'comment': comment,
      'parent_id': parentId,
      'is_folder': isFolder ? 1 : 0,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      comment: map['comment'] as String?,
      parentId: map['parent_id'] as int?,
      isFolder: ((map['is_folder'] as int?) ?? 0) == 1,
    );
  }

  Place copyWith({
    int? id,
    String? name,
    int? sortOrder,
    Object? comment = _unset,
    Object? parentId = _unset,
    bool? isFolder,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      comment: identical(comment, _unset) ? this.comment : comment as String?,
      parentId: identical(parentId, _unset) ? this.parentId : parentId as int?,
      isFolder: isFolder ?? this.isFolder,
    );
  }
}
