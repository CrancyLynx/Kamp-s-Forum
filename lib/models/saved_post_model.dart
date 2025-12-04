import 'package:cloud_firestore/cloud_firestore.dart';

/// Kaydedilmiş Gönderiler Sistemi
class SavedPost {
  final String id;
  final String userId;
  final String postId;
  final String postAuthorId;
  final String postTitle;
  final String? postContent;
  final String? postImageUrl;
  final String postCategory;
  final String collectionName;
  final DateTime savedAt;
  final DateTime originalPostDate;
  final int viewCount;
  final bool isArchived;
  final String? notes;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  SavedPost({
    required this.id,
    required this.userId,
    required this.postId,
    required this.postAuthorId,
    required this.postTitle,
    this.postContent,
    this.postImageUrl,
    required this.postCategory,
    required this.collectionName,
    required this.savedAt,
    required this.originalPostDate,
    required this.viewCount,
    required this.isArchived,
    this.notes,
    required this.tags,
    required this.metadata,
  });

  factory SavedPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      postId: data['postId'] ?? '',
      postAuthorId: data['postAuthorId'] ?? '',
      postTitle: data['postTitle'] ?? '',
      postContent: data['postContent'],
      postImageUrl: data['postImageUrl'],
      postCategory: data['postCategory'] ?? '',
      collectionName: data['collectionName'] ?? 'default',
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      originalPostDate: (data['originalPostDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: (data['viewCount'] ?? 0).toInt(),
      isArchived: data['isArchived'] ?? false,
      notes: data['notes'],
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'postId': postId,
      'postAuthorId': postAuthorId,
      'postTitle': postTitle,
      'postContent': postContent,
      'postImageUrl': postImageUrl,
      'postCategory': postCategory,
      'collectionName': collectionName,
      'savedAt': Timestamp.fromDate(savedAt),
      'originalPostDate': Timestamp.fromDate(originalPostDate),
      'viewCount': viewCount,
      'isArchived': isArchived,
      'notes': notes,
      'tags': tags,
      'metadata': metadata,
    };
  }

  SavedPost copyWith({
    String? id,
    String? userId,
    String? postId,
    String? postAuthorId,
    String? postTitle,
    String? postContent,
    String? postImageUrl,
    String? postCategory,
    String? collectionName,
    DateTime? savedAt,
    DateTime? originalPostDate,
    int? viewCount,
    bool? isArchived,
    String? notes,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return SavedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      postId: postId ?? this.postId,
      postAuthorId: postAuthorId ?? this.postAuthorId,
      postTitle: postTitle ?? this.postTitle,
      postContent: postContent ?? this.postContent,
      postImageUrl: postImageUrl ?? this.postImageUrl,
      postCategory: postCategory ?? this.postCategory,
      collectionName: collectionName ?? this.collectionName,
      savedAt: savedAt ?? this.savedAt,
      originalPostDate: originalPostDate ?? this.originalPostDate,
      viewCount: viewCount ?? this.viewCount,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Kaydedilmiş Gönderiler Koleksiyonu
class SavedPostCollection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int postCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;
  final List<String> collaborators;
  final String? coverImageUrl;
  final String color;

  SavedPostCollection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.postCount,
    required this.createdAt,
    this.updatedAt,
    required this.isPublic,
    required this.collaborators,
    this.coverImageUrl,
    required this.color,
  });

  factory SavedPostCollection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedPostCollection(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      postCount: (data['postCount'] ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isPublic: data['isPublic'] ?? false,
      collaborators: List<String>.from(data['collaborators'] ?? []),
      coverImageUrl: data['coverImageUrl'],
      color: data['color'] ?? '#FF5733',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'postCount': postCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isPublic': isPublic,
      'collaborators': collaborators,
      'coverImageUrl': coverImageUrl,
      'color': color,
    };
  }
}
