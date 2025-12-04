import 'package:cloud_firestore/cloud_firestore.dart';

/// Konum İkonları Sistemi
class LocationIcon {
  final String id;
  final String name;
  final String category; // "amenity", "food", "transport", "education", "health", "entertainment"
  final String svgPath;
  final String? pngUrl;
  final String color; // Hex color code
  final String backgroundColor;
  final int size; // Piksel
  final String createdBy;
  final DateTime createdAt;
  final bool isDefault;
  final bool isActive;
  final int usageCount;
  final List<String> aliases; // İkon için alternatif adlar
  final Map<String, String> labels; // Çok dilli etiketler

  LocationIcon({
    required this.id,
    required this.name,
    required this.category,
    required this.svgPath,
    this.pngUrl,
    required this.color,
    required this.backgroundColor,
    required this.size,
    required this.createdBy,
    required this.createdAt,
    required this.isDefault,
    required this.isActive,
    required this.usageCount,
    required this.aliases,
    required this.labels,
  });

  factory LocationIcon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationIcon(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'amenity',
      svgPath: data['svgPath'] ?? '',
      pngUrl: data['pngUrl'],
      color: data['color'] ?? '#000000',
      backgroundColor: data['backgroundColor'] ?? '#FFFFFF',
      size: (data['size'] ?? 48).toInt(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDefault: data['isDefault'] ?? false,
      isActive: data['isActive'] ?? true,
      usageCount: (data['usageCount'] ?? 0).toInt(),
      aliases: List<String>.from(data['aliases'] ?? []),
      labels: Map<String, String>.from(data['labels'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'svgPath': svgPath,
      'pngUrl': pngUrl,
      'color': color,
      'backgroundColor': backgroundColor,
      'size': size,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDefault': isDefault,
      'isActive': isActive,
      'usageCount': usageCount,
      'aliases': aliases,
      'labels': labels,
    };
  }

  LocationIcon copyWith({
    String? id,
    String? name,
    String? category,
    String? svgPath,
    String? pngUrl,
    String? color,
    String? backgroundColor,
    int? size,
    String? createdBy,
    DateTime? createdAt,
    bool? isDefault,
    bool? isActive,
    int? usageCount,
    List<String>? aliases,
    Map<String, String>? labels,
  }) {
    return LocationIcon(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      svgPath: svgPath ?? this.svgPath,
      pngUrl: pngUrl ?? this.pngUrl,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      size: size ?? this.size,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
      aliases: aliases ?? this.aliases,
      labels: labels ?? this.labels,
    );
  }

  /// Türkçe etiketi al
  String get turkishLabel => labels['tr'] ?? name;

  /// İngilizce etiketi al
  String get englishLabel => labels['en'] ?? name;
}

/// İkon Seti
class LocationIconSet {
  final String id;
  final String name;
  final String? description;
  final List<String> iconIds;
  final String createdBy;
  final DateTime createdAt;
  final int version;
  final bool isPublished;
  final String? previewImageUrl;

  LocationIconSet({
    required this.id,
    required this.name,
    this.description,
    required this.iconIds,
    required this.createdBy,
    required this.createdAt,
    required this.version,
    required this.isPublished,
    this.previewImageUrl,
  });

  factory LocationIconSet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationIconSet(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      iconIds: List<String>.from(data['iconIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      version: (data['version'] ?? 1).toInt(),
      isPublished: data['isPublished'] ?? false,
      previewImageUrl: data['previewImageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconIds': iconIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'version': version,
      'isPublished': isPublished,
      'previewImageUrl': previewImageUrl,
    };
  }
}
