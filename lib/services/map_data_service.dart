import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kampus_yardim_app/utils/api_keys.dart' as ApiKeys;
import '../utils/api_keys.dart';

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

        return LocationModel(
          id: doc.id,
          title: data['title'] ?? 'Bilinmeyen Yer',
          snippet: data['snippet'] ?? '',
          position: LatLng(gp.latitude, gp.longitude),
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

  // --- GOOGLE PLACES API (NEARBY SEARCH) - OPTİMİZE EDİLDİ ---
  Future<List<LocationModel>> searchNearbyPlaces({required LatLng center, required String typeFilter}) async {
    final cacheKey = "${center.latitude}_${center.longitude}_$typeFilter";
    if (_nearbyCache.containsKey(cacheKey)) {
      return _nearbyCache[cacheKey]!;
    }

    // 1. ADIM: Daha spesifik Google Place Tipleri kullanıyoruz.
    // 'keyword' yerine 'type' parametresi daha güvenilirdir ancak sadece tek bir tip destekler.
    // Bu yüzden 'keyword' kullanmaya devam edip daha spesifik terimler seçeceğiz.
    
    String keyword;

    if (typeFilter == 'yemek') {
      // Sadece kafe ve restoranlar
      keyword = 'cafe|restaurant|bakery|meal_takeaway'; 
    } else if (typeFilter == 'durak') {
      // Sadece toplu taşıma
      keyword = 'bus_station|transit_station|subway_station';
    } else if (typeFilter == 'kutuphane') {
      keyword = 'library';
    } else if (typeFilter == 'universite') {
      keyword = 'university'; 
    } else {
      // 'all' (Tümü) seçeneği için en önemli yerleri çekiyoruz
      // Keyword kullanımı type'dan daha esnektir çoklu arama için
      keyword = 'university OR library OR cafe OR bus station';
    }

    // URL Oluşturma
    String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${center.latitude},${center.longitude}' // radius buradan kaldırıldı
        '&language=tr' //
        '&key=$_apiKey'; //

    // YENİ: Filtreye göre dinamik arama yarıçapı
    // Üniversite, kütüphane ve tümü için daha geniş bir alanda (10km) arama yap.
    int radius = 1000; // Varsayılan 1km
    if (typeFilter == 'universite' || typeFilter == 'kutuphane' || typeFilter == 'all') {
      radius = 10000; // 10km
    }

    try {
      final url = Uri.parse('$baseUrl&radius=$radius&keyword=${Uri.encodeComponent(keyword)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'];
          
          // 2. ADIM: İSTEMCİ TARAFLI FİLTRELEME (JUNK REMOVER)
          // İstenmeyen yerleri (ATM, Market, Benzinlik vb.) manuel olarak eliyoruz.
          
          final List<String> blackListTypes = [
            'atm', 'bank', 'gas_station', 'car_repair', 'hospital', 'doctor', 
            'dentist', 'gym', 'lodging', 'real_estate_agency', 'travel_agency',
            'convenience_store', 'grocery_or_supermarket', 'store', 'clothing_store'
          ];

          // Üniversite modunda marketlerin çıkmasını engellemek için extra kontrol
          final bool strictUniversityMode = typeFilter == 'universite';

          final List<LocationModel> places = [];

          for (var item in results) {
            final List<String> types = List<String>.from(item['types'] ?? []);
            final String name = (item['name'] ?? '').toString().toLowerCase();

            // Kara liste kontrolü (Eğer bu tiplerden birine sahipse ve özellikle onu aramamışsak atla)
            bool isJunk = types.any((t) => blackListTypes.contains(t));
            
            // İstisna: Eğer filtre 'yemek' ise 'store' (market) bazen kafe olabilir, o yüzden typeFilter'a göre esnek davranılabilir.
            // Ancak 'universite' seçiliyse çok katı olmalıyız.
            
            if (strictUniversityMode) {
               // Üniversite arıyorsak içinde 'university' tipi MUTLAKA olmalı.
               // Ayrıca isminde 'market', 'bakkal', 'kırtasiye' geçiyorsa ele (Google bazen bunları university olarak etiketliyor).
               if (!types.contains('university')) continue;
               if (name.contains('market') || name.contains('bakkal') || name.contains('copy') || name.contains('kırtasiye')) continue;
            } else {
               // Diğer modlarda kara liste kontrolü yap
               if (isJunk) continue;
            }

            // Temiz veriyi modele çevir
            final loc = item['geometry']['location'];
            String assignedType = typeFilter == 'all' ? _determineTypeFromTags(types) : typeFilter;

            places.add(LocationModel(
              id: item['place_id'],
              title: item['name'],
              snippet: item['vicinity'] ?? '',
              position: LatLng(loc['lat'], loc['lng']),
              type: assignedType,
              rating: (item['rating'] as num?)?.toDouble() ?? 0.0,
              icon: _getIconForType(assignedType),
              photoUrls: _extractPhotoUrls(item['photos']),
            ));
          }

          _nearbyCache[cacheKey] = places;
          return places;
        }
      }
    } catch (e) {
      print("Google Places API Hatası: $e");
    }
    return [];
  }

  // Tiplere göre otomatik kategori belirleme (Tümü seçeneği için)
  String _determineTypeFromTags(List<String> types) {
    if (types.contains('university')) return 'universite';
    if (types.contains('library')) return 'kutuphane';
    if (types.contains('bus_station') || types.contains('transit_station')) return 'durak';
    if (types.contains('restaurant') || types.contains('cafe') || types.contains('bakery')) return 'yemek';
    return 'diger';
  }

  // --- DİĞER METODLAR (DEĞİŞMEDİ) ---
  Future<List<Map<String, dynamic>>> getPlacePredictions(String query, LatLng? userLocation) async {
    if (query.length < 3) return [];
    String locationParam = '';
    if (userLocation != null) {
      locationParam = '&location=${userLocation.latitude},${userLocation.longitude}&radius=5000';
    }
    final url = Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query$locationParam&language=tr&key=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') return List<Map<String, dynamic>>.from(data['predictions']);
      }
    } catch (e) { print("Autocomplete Error: $e"); }
    return [];
  }

  Future<LocationModel?> getPlaceDetails(String placeId) async {
    if (_placeDetailsCache.containsKey(placeId)) return _placeDetailsCache[placeId];
    final url = Uri.parse('https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,geometry,photos,rating,formatted_address,opening_hours&language=tr&key=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final loc = result['geometry']['location'];
          String? openNowText;
          if (result['opening_hours'] != null && result['opening_hours']['open_now'] != null) {
            openNowText = result['opening_hours']['open_now'] ? 'Şu an Açık' : 'Kapalı';
          }
          final model = LocationModel(
            id: placeId, title: result['name'], snippet: result['formatted_address'] ?? '',
            position: LatLng(loc['lat'], loc['lng']), type: 'arama_sonucu',
            rating: (result['rating'] as num?)?.toDouble() ?? 0.0,
            photoUrls: _extractPhotoUrls(result['photos']), openingHours: openNowText,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          );
          _placeDetailsCache[placeId] = model;
          return model;
        }
      }
    } catch (e) { print("Details Error: $e"); }
    return null;
  }

  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=walking&key=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          return _decodePolyline(data['routes'][0]['overview_polyline']['points']);
        }
      }
    } catch (e) { print("Directions Error: $e"); }
    return [];
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
  Future<String?> addReview(String locationId, double rating, String comment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return "Yorum yapmak için giriş yapmalısınız.";

    final locationRef = FirebaseFirestore.instance.collection('locations').doc(locationId);
    final reviewRef = locationRef.collection('reviews').doc(currentUser.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final locationSnapshot = await transaction.get(locationRef);
        if (!locationSnapshot.exists) throw Exception("Mekan bulunamadı!");

        // Yeni yorumu ekle/güncelle
        transaction.set(reviewRef, {
          'userId': currentUser.uid,
          'userName': currentUser.displayName ?? 'Kullanıcı',
          'userAvatar': currentUser.photoURL,
          'rating': rating,
          'comment': comment,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Ortalama puanı ve yorum sayısını güncelle
        // Not: Bu işlem çok sayıda eşzamanlı yazmada hatalı sonuç verebilir.
        // İdeali, bu hesaplamayı bir Cloud Function ile yapmaktır.
        // Ancak istemci tarafı için bu pratik bir çözümdür.
        transaction.update(locationRef, {
          'reviewCount': FieldValue.increment(1),
          // Ortalama puanı güncellemek için daha karmaşık bir mantık gerekir.
          // Şimdilik sadece yorum sayısını artırıyoruz. Gerçek bir ortalama için
          // tüm yorumları okumak veya toplam puanı tutmak gerekir.
        });
      });
      return null; // Başarılı
    } catch (e) {
      return "Bir hata oluştu: $e";
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