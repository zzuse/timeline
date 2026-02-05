/// Note model for timeline entries
class Note {
  final String id;
  String text;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  List<String> imagePaths;
  List<String> audioPaths;
  List<String> tags;
  
  // Sync fields
  String? serverId;          // Server-side ID for this note
  DateTime? lastSyncedAt;    // Last successful sync timestamp
  bool isDirty;              // Has local changes not yet synced

  Note({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.imagePaths = const [],
    this.audioPaths = const [],
    this.tags = const [],
    this.serverId,
    this.lastSyncedAt,
    this.isDirty = true,
  });

  /// Create a new note with auto-generated id and timestamps
  factory Note.create({
    required String text,
    List<String> imagePaths = const [],
    List<String> audioPaths = const [],
    List<String> tags = const [],
  }) {
    final now = DateTime.now();
    return Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      createdAt: now,
      updatedAt: now,
      imagePaths: List.from(imagePaths),
      audioPaths: List.from(audioPaths),
      tags: List.from(tags),
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isPinned': isPinned ? 1 : 0,
      'imagePaths': imagePaths.join('|'),
      'audioPaths': audioPaths.join('|'),
      'tags': tags.join('|'),
      'serverId': serverId,
      'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  /// Create from database map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      text: map['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      isPinned: (map['isPinned'] as int) == 1,
      imagePaths: _splitPaths(map['imagePaths'] as String?),
      audioPaths: _splitPaths(map['audioPaths'] as String?),
      tags: _splitPaths(map['tags'] as String?),
      serverId: map['serverId'] as String?,
      lastSyncedAt: map['lastSyncedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncedAt'] as int)
          : null,
      isDirty: map['isDirty'] != null ? (map['isDirty'] as int) == 1 : true,
    );
  }

  static List<String> _splitPaths(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// Create a copy with updated fields
  Note copyWith({
    String? text,
    DateTime? updatedAt,
    bool? isPinned,
    List<String>? imagePaths,
    List<String>? audioPaths,
    List<String>? tags,
    String? serverId,
    DateTime? lastSyncedAt,
    bool? isDirty,
  }) {
    return Note(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      imagePaths: imagePaths ?? List.from(this.imagePaths),
      audioPaths: audioPaths ?? List.from(this.audioPaths),
      tags: tags ?? List.from(this.tags),
      serverId: serverId ?? this.serverId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
