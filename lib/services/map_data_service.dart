import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart'; 
import '../utils/api_keys.dart';

class LocationModel {
  final String id;
  final String title;
  final String snippet;
  final String type; 
  final LatLng position;
  final BitmapDescriptor? icon;
  final String? openingHours; 
  final String? liveStatus; 
  final List<String> photoUrls; 
  final Map<String, dynamic>? votes; 

  LocationModel({
    required this.id,
    required this.title,
    required this.snippet,
    required this.type,
    required this.position,
    this.icon,
    this.openingHours,
    this.liveStatus,
    required this.photoUrls,
    this.votes,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot doc, BitmapDescriptor? icon) {
    final data = doc.data() as Map<String, dynamic>;
    List<String> photos = [];
    if (data['photos'] != null) {
      photos = List<String>.from(data['photos']);
    } else if (data['image'] != null) {
      photos.add(data['image']);
    }
    
    if (photos.isEmpty) {
      photos.add("https://placehold.co/600x400/png?text=Fotograf+Yok");
    }

    return LocationModel(
      id: doc.id,
      title: data['title'] ?? 'Başlıksız Mekan',
      snippet: data['snippet'] ?? '',
      type: data['type'] ?? 'diger',
      position: LatLng(
        (data['lat'] as num?)?.toDouble() ?? 0.0,
        (data['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      icon: icon,
      openingHours: data['hours'],
      liveStatus: data['status'],
      photoUrls: photos,
      votes: data['votes'],
    );
  }
}

class MapDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();
  
  BitmapDescriptor? _iconUni;
  BitmapDescriptor? _iconYemek;
  BitmapDescriptor? _iconDurak;
  BitmapDescriptor? _iconKutuphane;
  BitmapDescriptor? _iconDefault;

  void setIcons({
    required BitmapDescriptor iconUni,
    required BitmapDescriptor iconYemek,
    required BitmapDescriptor iconDurak,
    required BitmapDescriptor iconKutuphane,
    BitmapDescriptor? iconDefault,
  }) {
    _iconUni = iconUni;
    _iconYemek = iconYemek;
    _iconDurak = iconDurak;
    _iconKutuphane = iconKutuphane;
    _iconDefault = iconDefault ?? BitmapDescriptor.defaultMarker;
  }

  BitmapDescriptor? getIconForType(String type) {
    switch (type) {
      case 'universite': return _iconUni;
      case 'yemek': return _iconYemek;
      case 'durak': return _iconDurak;
      case 'kutuphane': return _iconKutuphane;
      default: return _iconDefault;
    }
  }

  // --- GOOGLE PLACES & DIRECTIONS API ---
  
  String _mapGoogleTypeToAppType(String googleType) {
    if (['restaurant', 'cafe', 'bakery', 'meal_takeaway', 'food'].contains(googleType)) return 'yemek';
    if (['bus_station', 'subway_station', 'transit_station'].contains(googleType)) return 'durak';
    if (['library', 'book_store'].contains(googleType)) return 'kutuphane';
    if (['university'].contains(googleType)) return 'universite';
    return 'diger';
  }

  String _mapAppFilterToGoogleType(String appFilter) {
    switch (appFilter) {
      case 'yemek': return 'restaurant';
      case 'durak': return 'transit_station'; 
      case 'kutuphane': return 'library';
      case 'universite': return 'university'; // School yerine University kullanarak daraltıyoruz
      default: return ''; 
    }
  }

  // YENİ: İsim bazlı sıkı filtreleme (İlkokul, Lise vb. engellemek için)
  bool _isValidUniversity(String name) {
    final lowerName = name.toLowerCase();
    // Engellenecek kelimeler
    final bannedWords = [
      'ilkokul', 'ortaokul', 'lise', 'anaokul', 'kolej', 
      'sürücü kursu', 'etüt', 'dershane', 'yurt', 'primary', 
      'secondary', 'high school', 'driving'
    ];
    
    for (var word in bannedWords) {
      if (lowerName.contains(word)) return false;
    }
    return true;
  }

  // 1. Yakındaki Yerleri Getir
  Future<List<LocationModel>> searchNearbyPlaces({
    required LatLng center, 
    required String typeFilter,
    double radius = 1500 
  }) async {
    String typeParam = '';
    if (typeFilter != 'all') {
      String gType = _mapAppFilterToGoogleType(typeFilter);
      if (gType.isNotEmpty) {
        typeParam = '&type=$gType';
      }
    }

    // Eğer filtre üniversite ise, sadece type=university kullanıyoruz
    final String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${center.latitude},${center.longitude}'
        '&radius=$radius'
        '$typeParam'
        '&language=tr'
        '&key=$googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final List results = data['results'];
          
          return results.where((place) {
            // EK FİLTRELEME: Eğer filtre üniversite ise veya genel arama ise, isminde lise/ilkokul geçenleri at
            if (typeFilter == 'universite' || typeFilter == 'all') {
               String name = place['name'];
               String googleType = (place['types'] as List).isNotEmpty ? place['types'][0] : '';
               
               // Eğer tipi 'university' ise veya biz üniversite arıyorsak isim kontrolü yap
               if (googleType == 'university' || typeFilter == 'universite') {
                 return _isValidUniversity(name);
               }
            }
            return true;
          }).map((place) {
            List<String> photos = [];
            if (place['photos'] != null && (place['photos'] as List).isNotEmpty) {
              String ref = place['photos'][0]['photo_reference'];
              String photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$googleMapsApiKey';
              photos.add(photoUrl);
            } else {
              photos.add("https://placehold.co/600x400/png?text=Fotograf+Yok");
            }

            String googleType = (place['types'] as List).isNotEmpty ? place['types'][0] : 'point_of_interest';
            String appType = _mapGoogleTypeToAppType(googleType);

            if (typeFilter != 'all' && appType == 'diger') {
              appType = typeFilter;
            }

            return LocationModel(
              id: place['place_id'],
              title: place['name'],
              snippet: place['vicinity'] ?? 'Adres bilgisi yok',
              type: appType,
              position: LatLng(
                place['geometry']['location']['lat'],
                place['geometry']['location']['lng'],
              ),
              icon: getIconForType(appType),
              openingHours: place['opening_hours'] != null && place['opening_hours']['open_now'] == true ? 'Şu an Açık' : 'Kapalı',
              liveStatus: 'Bilinmiyor',
              photoUrls: photos,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Google API Bağlantı Hatası: $e");
    }
    return [];
  }

  // 2. Arama Tahminleri (Autocomplete)
  Future<List<Map<String, dynamic>>> getPlacePredictions(String query, LatLng? userLocation) async {
    if (query.isEmpty) return [];

    String locationParam = '';
    if (userLocation != null) {
      locationParam = '&location=${userLocation.latitude},${userLocation.longitude}&radius=10000'; // Yarıçapı artırdım
    }

    final String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=$query'
        '$locationParam'
        '&language=tr'
        '&key=$googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
    } catch (e) {
      debugPrint("Autocomplete Hatası: $e");
    }
    return [];
  }

  // 3. Yer Detayı (Details)
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    final String url = 'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&fields=geometry,name,vicinity,place_id,types,opening_hours,photos'
        '&language=tr'
        '&key=$googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          
          List<String> photos = [];
          if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
            String ref = result['photos'][0]['photo_reference'];
            String photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$googleMapsApiKey';
            photos.add(photoUrl);
          } else {
            photos.add("https://placehold.co/600x400/png?text=Fotograf+Yok");
          }

          String googleType = (result['types'] as List).isNotEmpty ? result['types'][0] : 'point_of_interest';
          String appType = _mapGoogleTypeToAppType(googleType);

          return LocationModel(
            id: result['place_id'],
            title: result['name'],
            snippet: result['vicinity'] ?? 'Adres bilgisi yok',
            type: appType,
            position: LatLng(
              result['geometry']['location']['lat'],
              result['geometry']['location']['lng'],
            ),
            icon: getIconForType(appType),
            openingHours: result['opening_hours'] != null && result['opening_hours']['open_now'] == true ? 'Şu an Açık' : 'Kapalı',
            liveStatus: 'Bilinmiyor',
            photoUrls: photos,
          );
        }
      }
    } catch (e) {
      debugPrint("Place Details Hatası: $e");
    }
    return null;
  }

  // 4. Rota Çizimi (Directions API)
  Future<List<LatLng>> getRouteCoordinates(LatLng origin, LatLng destination) async {
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking'
        '&key=$googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          return _decodePolyline(encodedPolyline);
        }
      }
    } catch (e) {
      debugPrint("Rota Çekme Hatası: $e");
    }
    return [];
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

  // --- FIREBASE İŞLEMLERİ ---

  Stream<List<LocationModel>> getLocationsStream(String filter) {
    Query query = _firestore.collection('locations');
    if (filter != 'all') {
      query = query.where('type', isEqualTo: filter);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] ?? 'diger';
        return LocationModel.fromFirestore(doc, getIconForType(type));
      }).toList();
    });
  }

  Future<void> voteForStatus(String locationId, String status) async {
    final docRef = _firestore.collection('locations').doc(locationId);
    try {
      await docRef.set({
        'status': status,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Oylama hatası: $e");
    }
  }

  Future<void> addPhotoToLocation(String locationId, String photoUrl) async {
     try {
       await _firestore.collection('locations').doc(locationId).set({
        'photos': FieldValue.arrayUnion([photoUrl]),
      }, SetOptions(merge: true));
     } catch(e) { debugPrint("Foto ekleme hatası: $e"); }
  }

  Future<void> seedDatabaseIfEmpty() async {
    // Sabit veri seeding işlemi
    final snapshot = await _firestore.collection('locations').limit(1).get();
    if (snapshot.docs.isEmpty) {
      final batch = _firestore.batch();
      for (var loc in _fixedLocations) {
        final docRef = _firestore.collection('locations').doc(loc['id'].toString());
        List<String> mockPhotos = ["https://placehold.co/600x400/png?text=${loc['title'].toString().replaceAll(' ', '+')}"];
        batch.set(docRef, {
          'title': loc['title'],
          'lat': loc['lat'],
          'lng': loc['lng'],
          'type': loc['type'],
          'snippet': loc['snippet'] ?? 'Kampüs mekanı.',
          'hours': loc['hours'] ?? '08:00 - 17:00',
          'status': loc['status'] ?? 'Normal',
          'photos': mockPhotos,
        });
      }
      await batch.commit();
    }
  }
  
  List<LocationModel> getFallbackLocations(String currentFilter) {
    List<LocationModel> locations = [];
    for (var data in _fixedLocations) {
      if (data['type'] == null || data['lat'] == null || data['lng'] == null) continue;
      String type = data['type'];
      if (currentFilter == 'all' || type == currentFilter) {
        locations.add(LocationModel(
          id: data['id'], 
          title: data['title'], 
          snippet: data['snippet'] ?? '', 
          type: type, 
          position: LatLng(data['lat'], data['lng']), 
          icon: getIconForType(type) ?? BitmapDescriptor.defaultMarker,
          openingHours: data['hours'],
          liveStatus: data['status'] ?? 'Normal',
          photoUrls: ["https://placehold.co/600x400/png?text=${data['title'].toString().replaceAll(' ', '+')}"],
        ));
      }
    }
    return locations;
  }

  // Sabit listeyi de sadece üniversiteler olacak şekilde temizledim
  final List<Map<String, dynamic>> _fixedLocations = [
    {'id': 'vak_u25', 'title': 'İstanbul Galata Üniversitesi', 'lat': 41.0286, 'lng': 28.9744, 'type': 'universite'},
    {'id': 'vak_u1', 'title': 'Koç Üniversitesi', 'lat': 41.2049, 'lng': 29.0718, 'type': 'universite'},
    {'id': 'vak_u2', 'title': 'Sabancı Üniversitesi', 'lat': 40.8912, 'lng': 29.3787, 'type': 'universite'},
    {'id': 'vak_u3', 'title': 'İstanbul Bilgi Üniversitesi (Santral)', 'lat': 41.0664, 'lng': 28.9458, 'type': 'universite'},
    {'id': 'vak_u4', 'title': 'Bahçeşehir Üniversitesi (Beşiktaş)', 'lat': 41.0423, 'lng': 29.0095, 'type': 'universite'},
    {'id': 'vak_u5', 'title': 'Yeditepe Üniversitesi', 'lat': 40.9739, 'lng': 29.1517, 'type': 'universite'},
    {'id': 'vak_u6', 'title': 'İstanbul Aydın Üniversitesi', 'lat': 40.9930, 'lng': 28.7989, 'type': 'universite'},
    {'id': 'vak_u7', 'title': 'İstanbul Medipol Üniversitesi (Kavacık)', 'lat': 41.0927, 'lng': 29.0935, 'type': 'universite'},
    {'id': 'vak_u8', 'title': 'Özyeğin Üniversitesi', 'lat': 41.0347, 'lng': 29.2618, 'type': 'universite'},
    {'id': 'vak_u9', 'title': 'Kadir Has Üniversitesi', 'lat': 41.0253, 'lng': 28.9592, 'type': 'universite'},
    {'id': 'vak_u10', 'title': 'Acıbadem Üniversitesi', 'lat': 40.9764, 'lng': 29.1086, 'type': 'universite'},
    {'id': 'vak_u11', 'title': 'Beykent Üniversitesi', 'lat': 41.1090, 'lng': 29.0060, 'type': 'universite'},
    {'id': 'vak_u12', 'title': 'Haliç Üniversitesi', 'lat': 41.0663, 'lng': 28.9472, 'type': 'universite'},
    {'id': 'vak_u13', 'title': 'Üsküdar Üniversitesi', 'lat': 41.0247, 'lng': 29.0353, 'type': 'universite'},
    {'id': 'vak_u14', 'title': 'Piri Reis Üniversitesi', 'lat': 40.8936, 'lng': 29.3033, 'type': 'universite'},
    {'id': 'vak_u15', 'title': 'İstanbul Ticaret Üniversitesi', 'lat': 41.0633, 'lng': 28.9511, 'type': 'universite'},
    {'id': 'vak_u16', 'title': 'MEF Üniversitesi', 'lat': 41.1077, 'lng': 29.0232, 'type': 'universite'},
    {'id': 'vak_u17', 'title': 'Bezmiâlem Vakıf Üniversitesi', 'lat': 41.0186, 'lng': 28.9392, 'type': 'universite'},
    {'id': 'vak_u18', 'title': 'Fatih Sultan Mehmet Vakıf Üni.', 'lat': 41.0644, 'lng': 28.9497, 'type': 'universite'},
    {'id': 'vak_u19', 'title': 'İstanbul Sabahattin Zaim Üni.', 'lat': 41.0294, 'lng': 28.7917, 'type': 'universite'},
    {'id': 'vak_u20', 'title': 'Maltepe Üniversitesi', 'lat': 40.9572, 'lng': 29.2089, 'type': 'universite'},
    {'id': 'vak_u21', 'title': 'Doğuş Üniversitesi (Dudullu)', 'lat': 41.0003, 'lng': 29.1561, 'type': 'universite'},
    {'id': 'vak_u22', 'title': 'Işık Üniversitesi (Şile)', 'lat': 41.1714, 'lng': 29.5622, 'type': 'universite'},
    {'id': 'vak_u23', 'title': 'Altınbaş Üniversitesi', 'lat': 41.0635, 'lng': 28.8239, 'type': 'universite'},
    {'id': 'vak_u24', 'title': 'İstanbul Gelişim Üniversitesi', 'lat': 40.9936, 'lng': 28.7061, 'type': 'universite'},
    // DEVLET ÜNİVERSİTELERİ
    {'id': 'ist_u1', 'title': 'İstanbul Üniversitesi (Beyazıt)', 'lat': 41.0130, 'lng': 28.9636, 'type': 'universite'},
    {'id': 'ist_u2', 'title': 'İstanbul Teknik Üniversitesi (Ayazağa)', 'lat': 41.1065, 'lng': 29.0229, 'type': 'universite'},
    {'id': 'ist_u3', 'title': 'Boğaziçi Üniversitesi (Güney)', 'lat': 41.0833, 'lng': 29.0503, 'type': 'universite'},
    {'id': 'ist_u4', 'title': 'Yıldız Teknik Üniversitesi (Davutpaşa)', 'lat': 41.0522, 'lng': 28.8927, 'type': 'universite'},
    {'id': 'ist_u5', 'title': 'Marmara Üniversitesi (Göztepe)', 'lat': 40.9877, 'lng': 29.0528, 'type': 'universite'},
    {'id': 'ist_u6', 'title': 'Mimar Sinan Güzel Sanatlar Üni.', 'lat': 41.0312, 'lng': 28.9902, 'type': 'universite'},
    {'id': 'ist_u7', 'title': 'Türk-Alman Üniversitesi', 'lat': 41.1394, 'lng': 29.0833, 'type': 'universite'},
    {'id': 'ist_u8', 'title': 'İstanbul Medeniyet Üniversitesi', 'lat': 40.9990, 'lng': 29.0622, 'type': 'universite'},
    {'id': 'ist_u9', 'title': 'Galatasaray Üniversitesi', 'lat': 41.0475, 'lng': 29.0222, 'type': 'universite'},
    {'id': 'ist_u10', 'title': 'Sağlık Bilimleri Üniversitesi', 'lat': 41.0053, 'lng': 29.0225, 'type': 'universite'},
    {'id': 'ist_u11', 'title': 'İstanbul Cerrahpaşa Üniversitesi', 'lat': 40.9922, 'lng': 28.7303, 'type': 'universite'},
    // ANKARA
    {'id': 'ank1', 'title': 'ODTÜ (METU)', 'lat': 39.8914, 'lng': 32.7760, 'type': 'universite'},
    {'id': 'ank2', 'title': 'Bilkent Üniversitesi', 'lat': 39.8687, 'lng': 32.7483, 'type': 'universite'},
    {'id': 'ank3', 'title': 'Hacettepe Üniversitesi (Beytepe)', 'lat': 39.8656, 'lng': 32.7339, 'type': 'universite'},
    {'id': 'ank4', 'title': 'Ankara Üniversitesi', 'lat': 39.9366, 'lng': 32.8303, 'type': 'universite'},
    {'id': 'ank5', 'title': 'Gazi Üniversitesi', 'lat': 39.9372, 'lng': 32.8229, 'type': 'universite'},
    // İZMİR
    {'id': 'izm1', 'title': 'Ege Üniversitesi', 'lat': 38.4595, 'lng': 27.2275, 'type': 'universite'},
    {'id': 'izm2', 'title': 'Dokuz Eylül Üniversitesi', 'lat': 38.3707, 'lng': 27.2023, 'type': 'universite'},
    {'id': 'izm3', 'title': 'İzmir Yüksek Teknoloji Enstitüsü', 'lat': 38.3236, 'lng': 26.6366, 'type': 'universite'},
    // DİĞER ŞEHİRLER
    {'id': 'ant1', 'title': 'Akdeniz Üniversitesi (Antalya)', 'lat': 36.8970, 'lng': 30.6483, 'type': 'universite'},
    {'id': 'esk1', 'title': 'Anadolu Üniversitesi (Eskişehir)', 'lat': 39.7915, 'lng': 30.5009, 'type': 'universite'},
    {'id': 'bur1', 'title': 'Uludağ Üniversitesi (Bursa)', 'lat': 40.2234, 'lng': 28.8727, 'type': 'universite'},
    {'id': 'kon1', 'title': 'Selçuk Üniversitesi (Konya)', 'lat': 38.0254, 'lng': 32.5108, 'type': 'universite'},
    {'id': 'tra1', 'title': 'Karadeniz Teknik Üniversitesi (Trabzon)', 'lat': 40.9950, 'lng': 39.7717, 'type': 'universite'},
    {'id': 'erz1', 'title': 'Atatürk Üniversitesi (Erzurum)', 'lat': 39.9022, 'lng': 41.2425, 'type': 'universite'},
    {'id': 'gaz1', 'title': 'Gaziantep Üniversitesi', 'lat': 37.0346, 'lng': 37.3367, 'type': 'universite'},
    {'id': 'kay1', 'title': 'Erciyes Üniversitesi (Kayseri)', 'lat': 38.7077, 'lng': 35.5262, 'type': 'universite'},
    {'id': 'sak1', 'title': 'Sakarya Üniversitesi', 'lat': 40.7431, 'lng': 30.3323, 'type': 'universite'},
    {'id': 'koc1', 'title': 'Kocaeli Üniversitesi', 'lat': 40.8225, 'lng': 29.9213, 'type': 'universite'},
    {'id': 'can1', 'title': 'Çanakkale Onsekiz Mart Üniversitesi', 'lat': 40.1177, 'lng': 26.4109, 'type': 'universite'},
    // Ekstra Örnekler (Mekan Tipleri İçin)
    {'id': 'ymk1', 'title': 'Merkez Yemekhane', 'lat': 41.1055, 'lng': 29.0239, 'type': 'yemek', 'snippet': 'Öğle yemeği servisi 11:30 - 14:30', 'hours': '11:30-14:30'},
    {'id': 'drk1', 'title': 'Metro Girişi', 'lat': 41.1070, 'lng': 29.0210, 'type': 'durak', 'snippet': 'M2 Hattı', 'hours': '06:00-00:00'},
    {'id': 'kut1', 'title': 'Mustafa İnan Kütüphanesi', 'lat': 41.1045, 'lng': 29.0250, 'type': 'kutuphane', 'snippet': '7/24 Açık', 'hours': '24 Saat'},
  ];
}