import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kampus_yardim_app/utils/api_keys.dart' as ApiKeys;

// === KONUMDAKİ TÜRLERİN HARITA EŞLEŞTİRMESİ ===
class LocationTypeMapper {
  static const Map<String, String> typeToDisplay = {
    'universite': 'Üniversite',
    'yemek': 'Yemek',
    'durak': 'Durak',
    'kutuphane': 'Kütüphane',
    'diger': 'Diğer',
  };

  static String getDisplayName(String type) {
    return typeToDisplay[type.toLowerCase()] ?? 'Bilinmeyen';
  }

  static bool isValidType(String type) {
    return typeToDisplay.containsKey(type.toLowerCase());
  }
}

// === KONUM MODELİ ===
class LocationModel {
  final String id;
  final String title;
  final String snippet;
  final LatLng position;
  final String type; // universite, yemek, durak, kutuphane, diger
  final List<String> photoUrls;
  final String? openingHours;
  final double rating;
  final double firestoreRating;
  final int reviewCount;
  final BitmapDescriptor? icon;

  LocationModel({
    required this.id,
    required this.title,
    required this.snippet,
    required this.position,
    required this.type,
    this.photoUrls = const [],
    this.openingHours,
    this.rating = 0.0,
    this.firestoreRating = 0.0,
    this.reviewCount = 0,
    this.icon,
  });

  // Türü normalize et
  String get normalizedType => type.toLowerCase();

  // Görüntü adını al
  String get displayType => LocationTypeMapper.getDisplayName(type);
}

// === YORUM MODELİ ===
class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final Timestamp timestamp;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });
}

// === HADİTA VERİ SERVİSİ ===
class MapDataService {
  static final MapDataService _instance = MapDataService._internal();
  factory MapDataService() => _instance;
  MapDataService._internal();

  final String _apiKey = ApiKeys.googleMapsApiKey;

  // İkonlar cache
  final Map<String, BitmapDescriptor> _iconCache = {};

  // API cache
  final Map<String, List<LocationModel>> _nearbyCache = {};
  final Map<String, LocationModel> _placeDetailsCache = {};

  // İkon ayarlama
  void setIcons({
    required BitmapDescriptor iconUni,
    required BitmapDescriptor iconYemek,
    required BitmapDescriptor iconDurak,
    required BitmapDescriptor iconKutuphane,
  }) {
    _iconCache['universite'] = iconUni;
    _iconCache['yemek'] = iconYemek;
    _iconCache['durak'] = iconDurak;
    _iconCache['kutuphane'] = iconKutuphane;
  }

  // Türe uygun ikonu al
  BitmapDescriptor? _getIconForType(String type) {
    final normalizedType = type.toLowerCase();
    return _iconCache[normalizedType] ?? BitmapDescriptor.defaultMarker;
  }

  // === KOORDİNAT DOĞRULAMA ===
  /// Koordinatları doğrula. Eğer ters ise değiştir.
  /// Geçerli aralık: lat -90 to 90, lng -180 to 180
  (double, double) _validateCoordinates(double lat, double lng) {
    // Eğer değerler geçersiz aralıkta ise ters olabilir
    if ((lat > 90 || lat < -90) && (lng <= 90 && lng >= -90)) {
      if (kDebugMode) print("⚠️ Koordinatlar ters tespit edildi: ($lat, $lng) → ($lng, $lat)");
      return (lng, lat);
    }
    return (lat, lng);
  }

  // === FIRESTORE'DAN KONUMLARı AKIŞ OLARAK AL ===
  Stream<List<LocationModel>> getLocationsStream(String filterType) {
    Query query = FirebaseFirestore.instance.collection('locations');

    // Filtre uygula (tüm kategoriye izin ver)
    if (filterType != 'all' && filterType.isNotEmpty) {
      query = query.where('type', isEqualTo: filterType.toLowerCase());
    }

    return query.snapshots().map((snapshot) {
      final locations = <LocationModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final geoPoint = data['position'] as GeoPoint?;
          final type = (data['type'] as String? ?? 'diger').toLowerCase();

          if (geoPoint == null) continue;

          // Koordinat doğrulama
          final (lat, lng) = _validateCoordinates(geoPoint.latitude, geoPoint.longitude);

          locations.add(LocationModel(
            id: doc.id,
            title: data['title'] ?? 'Bilinmeyen Yer',
            snippet: data['snippet'] ?? '',
            position: LatLng(lat, lng),
            type: type,
            photoUrls: _parsePhotos(data['photos']),
            openingHours: data['hours'] as String?,
            firestoreRating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            reviewCount: data['reviewCount'] as int? ?? 0,
            icon: _getIconForType(type),
          ));
        } catch (e) {
          if (kDebugMode) print("Firestore konum parse hatası: $e");
        }
      }

      return locations;
    });
  }

  // === GOOGLE PLACES API ARAMASI ===
  Future<List<LocationModel>> searchNearbyPlaces({
    required LatLng center,
    required String typeFilter,
  }) async {
    // Cache kontrol
    final cacheKey = "${center.latitude}_${center.longitude}_${typeFilter.toLowerCase()}";
    if (_nearbyCache.containsKey(cacheKey)) {
      return _nearbyCache[cacheKey]!;
    }

    try {
      List<LocationModel> places = [];

      switch (typeFilter.toLowerCase()) {
        case 'universite':
          places = await _searchUniversities(center);
          break;
        case 'yemek':
          places = await _searchRestaurants(center);
          break;
        case 'durak':
          places = await _searchTransitStations(center);
          break;
        case 'kutuphane':
          places = await _searchLibraries(center);
          break;
        default:
          places = [];
      }

      _nearbyCache[cacheKey] = places;
      return places;
    } catch (e) {
      if (kDebugMode) print("Arama hatası ($typeFilter): $e");
      return [];
    }
  }

  // === ÜNİVERSİTE ARAMASI ===
  Future<List<LocationModel>> _searchUniversities(LatLng center) async {
    final universities = <LocationModel>[];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${center.latitude},${center.longitude}'
        '&radius=20000&type=university&language=tr&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK' && data['results'] is List) {
          universities.addAll(_parseSearchResults(data['results'], 'universite'));

          // Sonraki sayfa
          if (data['next_page_token'] != null) {
            await Future.delayed(const Duration(seconds: 2));
            final url2 = Uri.parse(
              'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?pagetoken=${data['next_page_token']}&key=$_apiKey',
            );
            final response2 = await http.get(url2).timeout(const Duration(seconds: 15));
            if (response2.statusCode == 200) {
              final data2 = json.decode(response2.body) as Map<String, dynamic>;
              if (data2['results'] is List) {
                universities.addAll(_parseSearchResults(data2['results'], 'universite'));
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("Üniversite arama hatası: $e");
    }

    return universities;
  }

  // === RESTORAN ARAMASI ===
  Future<List<LocationModel>> _searchRestaurants(LatLng center) async {
    final restaurants = <LocationModel>[];
    final seenIds = <String>{};

    try {
      // Restoran
      final restaurantResults = await _fetchByType(center, 'restaurant', 5000);
      for (var place in restaurantResults) {
        if (!seenIds.contains(place.id)) {
          seenIds.add(place.id);
          restaurants.add(place);
        }
      }

      // Kafe
      final cafeResults = await _fetchByType(center, 'cafe', 5000);
      for (var place in cafeResults) {
        if (!seenIds.contains(place.id)) {
          seenIds.add(place.id);
          restaurants.add(place);
        }
      }

      // Fırın
      final bakeryResults = await _fetchByType(center, 'bakery', 3000);
      for (var place in bakeryResults) {
        if (!seenIds.contains(place.id)) {
          seenIds.add(place.id);
          restaurants.add(place);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Restoran arama hatası: $e");
    }

    return restaurants;
  }

  // === DURAK ARAMASI ===
  Future<List<LocationModel>> _searchTransitStations(LatLng center) async {
    final stations = <LocationModel>[];
    final seenIds = <String>{};

    try {
      for (var type in ['bus_station', 'transit_station', 'subway_station']) {
        final results = await _fetchByType(center, type, 5000);
        for (var place in results) {
          if (!seenIds.contains(place.id)) {
            seenIds.add(place.id);
            stations.add(place);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("Durak arama hatası: $e");
    }

    return stations;
  }

  // === KÜTÜPHANE ARAMASI ===
  Future<List<LocationModel>> _searchLibraries(LatLng center) async {
    return await _fetchByType(center, 'library', 10000);
  }

  // === GENEL API ARAMASI ===
  Future<List<LocationModel>> _fetchByType(
    LatLng center,
    String placeType,
    int radius,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${center.latitude},${center.longitude}'
        '&radius=$radius&type=$placeType&language=tr&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['results'] is List) {
          return _parseSearchResults(data['results'], _mapGoogleTypeToOurType(placeType));
        }
      }
    } catch (e) {
      if (kDebugMode) print("$placeType arama hatası: $e");
    }

    return [];
  }

  // === ARAMA SONUÇLARINI PARSE ET ===
  List<LocationModel> _parseSearchResults(List<dynamic> results, String type) {
    final locations = <LocationModel>[];

    for (var item in results) {
      try {
        final location = item as Map<String, dynamic>;
        final geometry = location['geometry'] as Map<String, dynamic>?;
        final locData = geometry?['location'] as Map<String, dynamic>?;

        if (locData == null) continue;

        final rawLat = (locData['lat'] as num?)?.toDouble() ?? 0.0;
        final rawLng = (locData['lng'] as num?)?.toDouble() ?? 0.0;
        final (lat, lng) = _validateCoordinates(rawLat, rawLng);

        locations.add(LocationModel(
          id: location['place_id'] ?? 'unknown',
          title: location['name'] ?? 'Bilinmeyen',
          snippet: location['vicinity'] ?? '',
          position: LatLng(lat, lng),
          type: type,
          rating: (location['rating'] as num?)?.toDouble() ?? 0.0,
          icon: _getIconForType(type),
          photoUrls: _extractPhotoUrls(location['photos']),
        ));
      } catch (e) {
        if (kDebugMode) print("Parse hatası: $e");
      }
    }

    return locations;
  }

  // === MEKANDETAYLARıNı AL ===
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    if (_placeDetailsCache.containsKey(placeId)) {
      return _placeDetailsCache[placeId];
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,geometry,photos,rating,formatted_address,opening_hours'
        '&language=tr&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>?;
          final locData = geometry?['location'] as Map<String, dynamic>?;

          if (locData != null) {
            final rawLat = (locData['lat'] as num?)?.toDouble() ?? 0.0;
            final rawLng = (locData['lng'] as num?)?.toDouble() ?? 0.0;
            final (lat, lng) = _validateCoordinates(rawLat, rawLng);

            final model = LocationModel(
              id: placeId,
              title: result['name'] ?? 'Bilinmeyen',
              snippet: result['formatted_address'] ?? '',
              position: LatLng(lat, lng),
              type: 'diger',
              rating: (result['rating'] as num?)?.toDouble() ?? 0.0,
              icon: BitmapDescriptor.defaultMarker,
              photoUrls: _extractPhotoUrls(result['photos']),
            );

            _placeDetailsCache[placeId] = model;
            return model;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("Mekan detay hatası: $e");
    }

    return null;
  }

  // === ROTA KOORDİNATLARıNı AL ===
  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    if (origin.latitude == destination.latitude && origin.longitude == destination.longitude) {
      if (kDebugMode) print("Uyarı: Başlangıç ve bitiş aynı");
      return [];
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List)[0] as Map<String, dynamic>;
          final legs = route['legs'] as List?;

          if (legs != null && legs.isNotEmpty) {
            final steps = (legs[0] as Map<String, dynamic>)['steps'] as List?;
            if (steps != null) {
              final coordinates = <LatLng>[];
              for (var step in steps) {
                final stepData = step as Map<String, dynamic>;
                final polyline = stepData['polyline'] as Map<String, dynamic>?;
                if (polyline != null && polyline['points'] != null) {
                  coordinates.addAll(_decodePolyline(polyline['points'] as String));
                }
              }
              return coordinates;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("Rota hatası: $e");
    }

    return [];
  }

  // === YORUM STREAM'İ AL ===
  Stream<List<ReviewModel>> getReviewsStream(String locationId) {
    return FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ReviewModel(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'Anonim',
          userAvatar: data['userAvatar'] as String?,
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          comment: data['comment'] ?? '',
          timestamp: data['timestamp'] ?? Timestamp.now(),
        );
      }).toList();
    });
  }

  // === YORUM EKLE ===
  Future<String?> addReview(String locationId, double rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Giriş yapmalısınız";

    if (locationId.isEmpty) return "Geçersiz konum";
    if (rating < 0 || rating > 5) return "Puan 0-5 arasında olmalıdır";
    if (comment.trim().isEmpty) return "Yorum boş olamaz";
    if (comment.length > 500) return "En fazla 500 karakter";

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final locRef = FirebaseFirestore.instance.collection('locations').doc(locationId);
        final reviewRef = locRef.collection('reviews').doc(user.uid);

        transaction.set(reviewRef, {
          'userId': user.uid,
          'userName': user.displayName ?? 'Kullanıcı',
          'userAvatar': user.photoURL,
          'rating': rating,
          'comment': comment,
          'timestamp': FieldValue.serverTimestamp(),
        });

        final locDoc = await transaction.get(locRef);
        if (locDoc.exists) {
          final data = locDoc.data();
          if (data != null) {
            final oldRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            final reviewCount = data['reviewCount'] as int? ?? 0;

            final newRating = (oldRating * reviewCount + rating) / (reviewCount + 1);

            transaction.update(locRef, {
              'rating': newRating,
              'reviewCount': reviewCount + 1,
            });
          }
        }
      });

      return null;
    } catch (e) {
      if (kDebugMode) print("Yorum ekleme hatası: $e");
      return "Hata: $e";
    }
  }

  // === YARDIMCI METODLAR ===

  List<String> _parsePhotos(dynamic photos) {
    if (photos is! List) return [];
    return photos.cast<String>();
  }

  List<String> _extractPhotoUrls(List<dynamic>? photos) {
    if (photos == null || photos.isEmpty) return [];
    return photos
        .map((p) {
          if (p is Map<String, dynamic> && p['photo_reference'] != null) {
            return 'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=400'
                '&photoreference=${p['photo_reference']}'
                '&key=$_apiKey';
          }
          return null;
        })
        .whereType<String>()
        .toList();
  }

  String _mapGoogleTypeToOurType(String googleType) {
    switch (googleType.toLowerCase()) {
      case 'restaurant':
      case 'cafe':
      case 'bakery':
        return 'yemek';
      case 'bus_station':
      case 'transit_station':
      case 'subway_station':
        return 'durak';
      case 'library':
        return 'kutuphane';
      case 'university':
        return 'universite';
      default:
        return 'diger';
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final poly = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      result = 0;
      shift = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }

    return poly;
  }

  // Cache temizle
  void clearCache() {
    _nearbyCache.clear();
    _placeDetailsCache.clear();
  }

  // Belirli cache temizle
  void clearNearbyCache(String typeFilter) {
    _nearbyCache.removeWhere((key, _) => key.endsWith(typeFilter));
  }

  // Yer önerileri getir (autocomplete)
  Future<List<String>> getPlacePredictions(String input, LatLng bounds) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&location=${bounds.latitude},${bounds.longitude}'
          '&radius=50000'
          '&key=${ApiKeys.googleMapsApiKey}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List?;
        if (predictions != null) {
          return predictions
              .map((p) => (p['description'] as String?) ?? '')
              .where((desc) => desc.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('getPlacePredictions error: $e');
      return [];
    }
  }

  // Yorum oyu (beğeni/eleştiri)
  Future<void> voteForStatus(String placeId, String reviewId, String voteType) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(placeId)
          .collection('reviews')
          .doc(reviewId)
          .update({
        'upvotes': FieldValue.increment(voteType == 'up' ? 1 : 0),
        'downvotes': FieldValue.increment(voteType == 'down' ? 1 : 0),
      });
    } catch (e) {
      debugPrint('voteForStatus error: $e');
    }
  }
}
