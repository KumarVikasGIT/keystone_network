// ============================================================================
//  example/lib/data/models.dart
//
//  Simple model classes used across the example screens.
//  In a real app these would live in separate feature-layer files.
// ============================================================================

// ── Gallery ───────────────────────────────────────────────────────────────

class Gallery {
  final int    id;
  final String title;
  final String thumbnailUrl;
  final int    photoCount;

  const Gallery({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.photoCount,
  });

  factory Gallery.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Gallery(
      id:           map['id'] as int,
      title:        map['title'] as String,
      thumbnailUrl: map['thumbnail_url'] as String,
      photoCount:   map['photo_count'] as int,
    );
  }
}

// ── Photo ─────────────────────────────────────────────────────────────────

class Photo {
  final int    id;
  final String url;
  final String filename;

  const Photo({required this.id, required this.url, required this.filename});

  factory Photo.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Photo(
      id:       map['id'] as int,
      url:      map['url'] as String,
      filename: map['filename'] as String,
    );
  }
}

// ── User ──────────────────────────────────────────────────────────────────

class User {
  final int    id;
  final String name;
  final String email;
  final String avatarUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory User.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return User(
      id:        map['id'] as int,
      name:      map['name'] as String,
      email:     map['email'] as String,
      avatarUrl: map['avatar_url'] as String,
    );
  }
}
