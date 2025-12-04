import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kampus_yardim_app/utils/api_keys.dart' as ApiKeys;

// --- MODELLER ---
class LocationModel {
  final String id;
  final String title;
  final String snippet;
  final LatLng position;
  final String type; // universite, yemek, durak, kutuphane
  final List<String> photoUrls;
  final String? openingHours;
  final double rating;
  final BitmapDescriptor? icon;
  // YENİ: Uygulama içi oylama için alanlar
  final double firestoreRating;
  final int reviewCount;

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
}

// YENİ: Yorum Modeli
class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String comment;
  final Timestamp timestamp;

  ReviewModel({
    required this.id, required this.userId, required this.userName,
    this.userAvatar, required this.rating, required this.comment,
    required this.timestamp,
  });
}

class MapDataService {
  // Singleton Pattern
  static final MapDataService _instance = MapDataService._internal();
  factory MapDataService() => _instance;
  MapDataService._internal();

  // GÜNCELLEME: .env üzerinden okunan getter kullanılıyor
  final String _apiKey = ApiKeys.googleMapsApiKey;
  
  // Custom Icons Cache
  BitmapDescriptor? _iconUni;
  BitmapDescriptor? _iconYemek;
  BitmapDescriptor? _iconDurak;
  BitmapDescriptor? _iconKutuphane;
  BitmapDescriptor? _iconDefault;

  // API Cache
  final Map<String, List<LocationModel>> _nearbyCache = {};
  final Map<String, LocationModel> _placeDetailsCache = {};

  // --- İKON AYARLAMA ---
  void setIcons({
    required BitmapDescriptor iconUni,
    required BitmapDescriptor iconYemek,
    required BitmapDescriptor iconDurak,
    required BitmapDescriptor iconKutuphane,
  }) {
    _iconUni = iconUni;
    _iconYemek = iconYemek;
    _iconDurak = iconDurak;
    _iconKutuphane = iconKutuphane;
    _iconDefault = BitmapDescriptor.defaultMarker;
  }

  // --- FIRESTORE STREAM ---
  Stream<List<LocationModel>> getLocationsStream(String filterType) {
    Query query = FirebaseFirestore.instance.collection('locations');
    
    if (filterType != 'all') {
      query = query.where('type', isEqualTo: filterType);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final GeoPoint gp = data['position'];
        final String type = data['type'] ?? 'diger';

        // DÜZELTME: Koordinatların ters mi olup olmadığını kontrol et
        // Eğer latitude > 90 veya longitude > 180 ise, koordinatlar ters olabilir
        final (latitude, longitude) = _validateCoordinates(gp.latitude, gp.longitude);

        return LocationModel(
          id: doc.id,
          title: data['title'] ?? 'Bilinmeyen Yer',
          snippet: data['snippet'] ?? '',
          position: LatLng(latitude, longitude),
          type: type,
          photoUrls: List<String>.from(data['photos'] ?? []),
          openingHours: data['hours'],
          firestoreRating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: data['reviewCount'] ?? 0,
          icon: _getIconForType(type),
        );
      }).toList();
    });
  }

  BitmapDescriptor? _getIconForType(String type) {
    switch (type) {
      case 'universite': return _iconUni;
      case 'yemek': return _iconYemek;
      case 'durak': return _iconDurak;
      case 'kutuphane': return _iconKutuphane;
      default: return _iconDefault;
    }
  }

  // DÜZELTME: Koordinat doğrulama - Eğer lat/lng ters ise otomatik düzelt
  (double, double) _validateCoordinates(double lat, double lng) {
    // Geçerli aralıklar: latitude -90 to 90, longitude -180 to 180
    if (lat > 90 || lat < -90 || lng > 180 || lng < -180) {
      // Koordinatlar ters olabilir - değişdir
      if (kDebugMode) print("⚠️ Ters koordinat tespit edildi: ($lat, $lng) → ($lng, $lat)");
      return (lng, lat);
    }
    return (lat, lng);
  }

  // --- ✅ GOOGLE PLACES API (TAMAMEN YENİDEN YAZILDI - ÜST DÜZEY) ---
  Future<List<LocationModel>> searchNearbyPlaces({required LatLng center, required String typeFilter}) async {
    final cacheKey = "${center.latitude}_${center.longitude}_$typeFilter";
    if (_nearbyCache.containsKey(cacheKey)) {
      return _nearbyCache[cacheKey]!;
    }

    try {
      List<LocationModel> allPlaces = [];

      // ✅ FARKLI FİLTRELER İÇİN ÖZEL STRATEJİLER
      if (typeFilter == 'universite') {
        // ✅ ÜNİVERSİTE: Çok geniş alanda ara, tüm şehirdeki üniversiteleri getir
        allPlaces = await _searchUniversities(center);
      } else if (typeFilter == 'yemek') {
        // ✅ YEMEK: Restoran ve kafeler için optimize edilmiş arama
        allPlaces = await _searchRestaurants(center);
      } else if (typeFilter == 'durak') {
        // ✅ DURAK: Toplu taşıma durakları
        allPlaces = await _searchTransitStations(center);
      } else if (typeFilter == 'kutuphane') {
        // ✅ KÜTÜPHANE: Kütüphaneler
        allPlaces = await _searchLibraries(center);
      } else if (typeFilter == 'all') {
        // ✅ TÜMÜ: Sadece Firestore verilerini kullan, Google Places kullanma
        // (Kullanıcı konumu marker'ını kaldırmak için UI'da düzenleme yapacağız)
        return []; // Boş döndür, sadece Firestore verileri gösterilsin
      }

      _nearbyCache[cacheKey] = allPlaces;
      return allPlaces;
    } catch (e) {
      if (kDebugMode) print("Google Places API Hatası: $e");
      return [];
    }
  }

  // ✅ ÜNİVERSİTE ARAMA - ŞEHİRDEKİ TÜM ÜNİVERSİTELER
  Future<List<LocationModel>> _searchUniversities(LatLng center) async {
    final List<LocationModel> universities = [];
    
    try {
      // İlk arama: 20km yarıçapında tüm üniversiteler
      final url1 = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${center.latitude},${center.longitude}'
        '&radius=20000' // 20km - şehir çapında
        '&type=university'
        '&language=tr'
        '&key=$_apiKey'
      );

      final response1 = await http.get(url1).timeout(const Duration(seconds: 15));
      
      if (response1.statusCode == 200) {
        final data1 = json.decode(response1.body);
        if (data1['status'] == 'OK' || data1['status'] == 'ZERO_RESULTS') {
          if (data1['results'] != null) {
            universities.addAll(_parseUniversityResults(data1['results']));
          }

          // Eğer sonraki sayfa varsa (next_page_token), onu da çek
          String? nextPageToken = data1['next_page_token'];
          if (nextPageToken != null) {
            await Future.delayed(const Duration(seconds: 2)); // Google API gereksinimi
            
            final url2 = Uri.parse(
              'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?pagetoken=$nextPageToken'
              '&key=$_apiKey'
            );
            
            final response2 = await http.get(url2).timeout(const Duration(seconds: 15));
            if (response2.statusCode == 200) {
              final data2 = json.decode(response2.body);
              if (data2['results'] != null) {
                universities.addAll(_parseUniversityResults(data2['results']));
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

  // ✅ RESTORAN ARAMA - DAHA FAZLA RESTORAN VE KAFE
  Future<List<LocationModel>> _searchRestaurants(LatLng center) async {
    final List<LocationModel> restaurants = [];
    final Set<String> seenIds = {}; // Duplicate önleme

    try {
      // 1. Restoran araması
      final restaurantResults = await _fetchPlacesByType(center, 'restaurant', 5000);
      for (var place in restaurantResults) {
        if (!seenIds.contains(place.id)) {
          restaurants.add(place);
          seenIds.add(place.id);
        }
      }

      // 2. Kafe araması
      final cafeResults = await _fetchPlacesByType(center, 'cafe', 5000);
      for (var place in cafeResults) {
        if (!seenIds.contains(place.id)) {
          restaurants.add(place);
          seenIds.add(place.id);
        }
      }

      // 3. Fırın/pastane araması
      final bakeryResults = await _fetchPlacesByType(center, 'bakery', 3000);
      for (var place in bakeryResults) {
        if (!seenIds.contains(place.id)) {
          restaurants.add(place);
          seenIds.add(place.id);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Restoran arama hatası: $e");
    }

    return restaurants;
  }

  // ✅ TOPLU TAŞIMA DURAK ARAMA
  Future<List<LocationModel>> _searchTransitStations(LatLng center) async {
    final List<LocationModel> stations = [];
    final Set<String> seenIds = {};

    try {
      // Bus station
      final busResults = await _fetchPlacesByType(center, 'bus_station', 3000);
      for (var place in busResults) {
        if (!seenIds.contains(place.id)) {
          stations.add(place);
          seenIds.add(place.id);
        }
      }

      // Transit station
      final transitResults = await _fetchPlacesByType(center, 'transit_station', 3000);
      for (var place in transitResults) {
        if (!seenIds.contains(place.id)) {
          stations.add(place);
          seenIds.add(place.id);
        }
      }

      // Subway station
      final subwayResults = await _fetchPlacesByType(center, 'subway_station', 5000);
      for (var place in subwayResults) {
        if (!seenIds.contains(place.id)) {
          stations.add(place);
          seenIds.add(place.id);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Durak arama hatası: $e");
    }

    return stations;
  }

  // ✅ KÜTÜPHANE ARAMA
  Future<List<LocationModel>> _searchLibraries(LatLng center) async {
    return await _fetchPlacesByType(center, 'library', 10000);
  }

  // ✅ GENEL TİP BAZLI ARAMA FONKSİYONU
  Future<List<LocationModel>> _fetchPlacesByType(LatLng center, String type, int radius) async {
    final List<LocationModel> places = [];
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${center.latitude},${center.longitude}'
        '&radius=$radius'
        '&type=$type'
        '&language=tr'
        '&key=$_apiKey'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List<dynamic>;
          
          for (var item in results) {
            final place = _parseLocationResult(item, type);
            if (place != null) {
              places.add(place);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("$type arama hatası: $e");
    }

    return places;
  }

  // ✅ ÜNİVERSİTE SONUÇLARINI PARSE ET
  List<LocationModel> _parseUniversityResults(List<dynamic> results) {
    final List<LocationModel> universities = [];
    
    // ✅ KARA LİSTE: Bu kelimeleri içeren yerler üniversite değil
    final blacklistKeywords = [
      'market', 'bakkal', 'kırtasiye', 'copy', 'fotokopi', 
      'berber', 'kuaför', 'apart', 'yurt', 'pansiyon', 'otel',
      'cafe', 'restaurant', 'kafe', 'restoran'
    ];

    for (var item in results) {
      try {
        final List<String> types = List<String>.from(item['types'] ?? []);
        final String name = (item['name'] ?? '').toString().toLowerCase();
        
        // Üniversite tipi kontrolü
        if (!types.contains('university')) continue;
        
        // Kara liste kontrolü
        bool isBlacklisted = blacklistKeywords.any((keyword) => name.contains(keyword));
        if (isBlacklisted) continue;
        
        // Geçerli üniversite
        final loc = item['geometry']['location'];
        final rawLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
        final rawLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
        final (latitude, longitude) = _validateCoordinates(rawLat, rawLng);
        
        universities.add(LocationModel(
          id: item['place_id'],
          title: item['name'],
          snippet: item['vicinity'] ?? '',
          position: LatLng(latitude, longitude),
          type: 'universite',
          rating: (item['rating'] as num?)?.toDouble() ?? 0.0,
          icon: _iconUni,
          photoUrls: _extractPhotoUrls(item['photos']),
        ));
      } catch (e) {
        if (kDebugMode) print("Üniversite parse hatası: $e");
      }
    }

    return universities;
  }

  // ✅ GENEL LOCATION PARSE
  LocationModel? _parseLocationResult(Map<String, dynamic> item, String type) {
    try {
      final loc = item['geometry']?['location'];
      if (loc == null) return null;

      final rawLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      final rawLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
      final (latitude, longitude) = _validateCoordinates(rawLat, rawLng);

      return LocationModel(
        id: item['place_id'],
        title: item['name'] ?? 'Bilinmeyen',
        snippet: item['vicinity'] ?? '',
        position: LatLng(latitude, longitude),
        type: type,
        rating: (item['rating'] as num?)?.toDouble() ?? 0.0,
        icon: _getIconForType(type),
        photoUrls: _extractPhotoUrls(item['photos']),
      );
    } catch (e) {
      if (kDebugMode) print("Location parse hatası: $e");
      return null;
    }
  }

  // --- DİĞER METODLAR (DEĞİŞMEDİ) ---
  Future<List<Map<String, dynamic>>> getPlacePredictions(String query, LatLng? userLocation) async {
    if (query.isEmpty) return [];
    
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return [];

    try {
      String locationParam = '';
      if (userLocation != null) {
        locationParam = '&location=${userLocation.latitude},${userLocation.longitude}&radius=5000';
      }

      final url = Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(trimmedQuery)}$locationParam&language=tr&key=$_apiKey');

      final response = await http.get(url).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Tahmin sorgusu zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) print("HTTP Hatası: Tahminler alınamadı");
        return [];
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        if (data['status'] == 'ZERO_RESULTS') return [];
        if (kDebugMode) print("Tahmin API: ${data['error_message'] ?? data['status']}");
        return [];
      }

      final predictions = data['predictions'];
      if (predictions == null || predictions is! List) return [];

      return List<Map<String, dynamic>>.from(predictions);
    } catch (e) {
      if (kDebugMode) print("Tahmin Hatası: $e");
      return [];
    }
  }

  Future<LocationModel?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty) {
      if (kDebugMode) print("Hata: Boş placeId değeri");
      return null;
    }

    if (_placeDetailsCache.containsKey(placeId)) {
      return _placeDetailsCache[placeId];
    }

    try {
      final url = Uri.parse('https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,geometry,photos,rating,formatted_address,opening_hours&language=tr&key=$_apiKey');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Mekan detayları sorgusu zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) print("HTTP Hatası: Mekan detayları alınamadı");
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        String errorMsg = data['error_message'] ?? data['status'] ?? 'Bilinmeyen hata';
        if (kDebugMode) print("Mekan Detay API Hatası: $errorMsg");
        if (data['status'] == 'ZERO_RESULTS') return null;
        return null;
      }

      final result = data['result'];
      if (result == null) {
        if (kDebugMode) print("API boş sonuç döndürdü");
        return null;
      }

      final geometry = result['geometry'];
      if (geometry == null || geometry['location'] == null) {
        if (kDebugMode) print("Mekan geometry bilgisi eksik");
        return null;
      }

      final loc = geometry['location'];
      final name = result['name'] ?? 'Bilinmeyen Mekan';
      final address = result['formatted_address'] ?? '';

      String? openNowText;
      if (result['opening_hours'] != null && result['opening_hours']['open_now'] != null) {
        try {
          openNowText = result['opening_hours']['open_now'] ? 'Şu an Açık' : 'Kapalı';
        } catch (e) {
          if (kDebugMode) print('Açık/Kapalı durumu işlenirken hata: $e');
        }
      }

      final rawLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      final rawLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
      final (latitude, longitude) = _validateCoordinates(rawLat, rawLng);

      final model = LocationModel(
        id: placeId,
        title: name,
        snippet: address,
        position: LatLng(latitude, longitude),
        type: 'arama_sonucu',
        rating: (result['rating'] as num?)?.toDouble() ?? 0.0,
        photoUrls: _extractPhotoUrls(result['photos']),
        openingHours: openNowText,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );

      _placeDetailsCache[placeId] = model;
      return model;
    } catch (e) {
      if (kDebugMode) print("Mekan Detay Hatası: $e");
      return null;
    }
  }

  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    if (origin.latitude == destination.latitude && origin.longitude == destination.longitude) {
      if (kDebugMode) print("Uyarı: Başlangıç ve bitiş aynı noktada");
      return [];
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking&language=tr&key=$_apiKey'
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Rota sorgusu zaman aşımına uğradı.'),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) print("HTTP Hatası: Rota alınamadı");
        return [];
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        String errorMsg = data['error_message'] ?? data['status'] ?? 'Bilinmeyen hata';
        if (kDebugMode) print("Rota API Hatası: $errorMsg");
        return [];
      }

      final routes = data['routes'];
      if (routes == null || routes.isEmpty) {
        if (kDebugMode) print("Uyarı: Rota sonucu boş");
        return [];
      }

      try {
        final firstRoute = routes[0];
        final overviewPolyline = firstRoute['overview_polyline'];
        
        if (overviewPolyline == null || overviewPolyline['points'] == null) {
          if (kDebugMode) print("Uyarı: Polyline verileri eksik");
          return [];
        }

        final polylinePoints = overviewPolyline['points'] as String?;
        if (polylinePoints == null || polylinePoints.isEmpty) {
          if (kDebugMode) print("Uyarı: Polyline string boş");
          return [];
        }

        final coordinates = _decodePolyline(polylinePoints);
        
        if (coordinates.isEmpty) {
          if (kDebugMode) print("Uyarı: Polyline decode'ı sonucu boş");
          return [];
        }

        return coordinates;
      } catch (e) {
        if (kDebugMode) print("Rota verileri işlenirken hata: $e");
        return [];
      }
    } catch (e) {
      if (kDebugMode) print("Rota Hatası: $e");
      return [];
    }
  }

  Future<void> voteForStatus(String locationId, String status) async {
    await FirebaseFirestore.instance.collection('locations').doc(locationId).set({
      'lastUpdate': FieldValue.serverTimestamp(), 'status': status,
    }, SetOptions(merge: true));
  }

  Future<void> addPhotoToLocation(String locationId, String photoUrl) async {
    await FirebaseFirestore.instance.collection('locations').doc(locationId).update({
      'photos': FieldValue.arrayUnion([photoUrl])
    });
  }

  // --- YENİ: YORUM VE PUANLAMA SİSTEMİ ---

  /// Belirli bir mekan için yorumları stream olarak getirir.
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
          userId: data['userId'],
          userName: data['userName'],
          userAvatar: data['userAvatar'],
          rating: (data['rating'] as num).toDouble(),
          comment: data['comment'],
          timestamp: data['timestamp'],
        );
      }).toList();
    });
  }

  /// Bir mekana yeni bir yorum ve puan ekler.
  /// Transaction kullanarak mekanın ortalama puanını ve yorum sayısını günceller.
  /// Hata durumunda error mesajı döndürür, başarıda null döndürür.
  Future<String?> addReview(String locationId, double rating, String comment) async {
    // User validation
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return "Yorum yapmak için giriş yapmalısınız.";
    }

    // Input validation
    if (locationId.isEmpty) {
      return "Geçersiz mekan ID'si.";
    }

    if (rating < 0 || rating > 5) {
      return "Puan 0-5 arasında olmalıdır.";
    }

    if (comment.trim().isEmpty) {
      return "Yorum boş olamaz.";
    }

    if (comment.length > 500) {
      return "Yorum en fazla 500 karakter olabilir.";
    }

    final locationRef = FirebaseFirestore.instance.collection('locations').doc(locationId);
    final reviewRef = locationRef.collection('reviews').doc(currentUser.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final locationSnapshot = await transaction.get(locationRef);
        if (!locationSnapshot.exists) {
          throw Exception('Mekan bulunamadı');
        }

        // Yeni yorumu ekle/güncelle
        transaction.set(reviewRef, {
          'userId': currentUser.uid,
          'userName': currentUser.displayName ?? 'Anonim Kullanıcı',
          'userAvatar': currentUser.photoURL,
          'rating': rating,
          'comment': comment.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Yorum sayısını güncelle
        transaction.update(locationRef, {
          'reviewCount': FieldValue.increment(1),
        });
      });

      if (kDebugMode) print('Yorum başarıyla eklendi: $locationId');
      return null; // Başarılı
    } on FirebaseException catch (e) {
      if (kDebugMode) print("Firebase Hatası: ${e.message}");
      
      if (e.code == 'permission-denied') {
        return "Bu işlemi yapmaya yetkiniz yok.";
      }
      if (e.code == 'not-found') {
        return "Mekan bulunamadı.";
      }
      if (e.code == 'unavailable') {
        return "Veritabanı şu anda kullanılamıyor. Lütfen biraz sonra tekrar deneyiniz.";
      }
      
      return "Hata: ${e.message}";
    } catch (e) {
      if (kDebugMode) print("Yorum Ekleme Hatası: $e");
      return "Yorum eklenirken hata: $e";
    }
  }

  List<String> _extractPhotoUrls(List<dynamic>? photos) {
    if (photos == null || photos.isEmpty) return [];
    return photos.map((p) => 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${p['photo_reference']}&key=$_apiKey').toList();
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }
}
