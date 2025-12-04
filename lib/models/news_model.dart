import 'package:cloud_firestore/cloud_firestore.dart';

/// Haber & Duyurular Sistemi
/// Kampus haberlerini, duyuruları ve önemli bilgilendirmeleri yönetir
class News {
  final String id;
  final String title;
  final String content;
  final String category; // "akademik", "etkinlik", "bildirim", "ozel"
  final String imageUrl;
  final String authorId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final bool isPinned;
  final int viewCount;
  final List<String> tags;
  final bool isPublished;

  News({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.imageUrl,
    required this.authorId,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    required this.isPinned,
    required this.viewCount,
    required this.tags,
    required this.isPublished,
  });

  factory News.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return News(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'bildirim',
      imageUrl: data['imageUrl'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] ?? false,
      viewCount: (data['viewCount'] ?? 0).toInt(),
      tags: List<String>.from(data['tags'] ?? []),
      isPublished: data['isPublished'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'authorId': authorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isPinned': isPinned,
      'viewCount': viewCount,
      'tags': tags,
      'isPublished': isPublished,
    };
  }

  News copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? imageUrl,
    String? authorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    bool? isPinned,
    int? viewCount,
    List<String>? tags,
    bool? isPublished,
  }) {
    return News(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isPinned: isPinned ?? this.isPinned,
      viewCount: viewCount ?? this.viewCount,
      tags: tags ?? this.tags,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}
