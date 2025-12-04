import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Konum İşaretleri - Harita üzerinde kampus yerlerini gösterir
class LocationMarker {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String iconType; // "canteen", "library", "classroom", "event", "health", "sport", "custom"
  final String category;
  final String? imageUrl;
  final String? phoneNumber;
  final String? website;
  final String? address;
  final List<String> tags;
  final bool isActive;
  final DateTime createdAt;
  final int rating; // 0-5

  LocationMarker({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.iconType,
    required this.category,
    this.imageUrl,
    this.phoneNumber,
    this.website,
    this.address,
    required this.tags,
    required this.isActive,
    required this.createdAt,
    required this.rating,
  });

  LatLng get position => LatLng(latitude, longitude);

  factory LocationMarker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationMarker(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      iconType: data['iconType'] ?? 'custom',
      category: data['category'] ?? 'general',
      imageUrl: data['imageUrl'],
      phoneNumber: data['phoneNumber'],
      website: data['website'],
      address: data['address'],
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: (data['rating'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'iconType': iconType,
      'category': category,
      'imageUrl': imageUrl,
      'phoneNumber': phoneNumber,
      'website': website,
      'address': address,
      'tags': tags,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'rating': rating,
    };
  }

  LocationMarker copyWith({
    String? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? iconType,
    String? category,
    String? imageUrl,
    String? phoneNumber,
    String? website,
    String? address,
    List<String>? tags,
    bool? isActive,
    DateTime? createdAt,
    int? rating,
  }) {
    return LocationMarker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      iconType: iconType ?? this.iconType,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      address: address ?? this.address,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rating: rating ?? this.rating,
    );
  }
}
