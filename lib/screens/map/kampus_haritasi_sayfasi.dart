import 'dart:async';
import 'dart:math' show cos, sqrt, atan2, pi, sin;
import 'dart:ui' as ui;
import 'dart:io' show Platform; // Platform kontrolü için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Servis ve Yardımcılar
import '../../services/map_data_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../utils/app_colors.dart';
import '../../utils/maskot_helper.dart';

// YENİ: Ring Seferleri Paneli Importu
import '../../widgets/map/ring_seferleri_sheet.dart';

class KampusHaritasiSayfasi extends StatefulWidget {
  final String initialFilter;
  final LatLng? initialFocus;
  final double initialZoom;

  const KampusHaritasiSayfasi({
    super.key,
    this.initialFilter = 'all',
    this.initialFocus,
    this.initialZoom = 15.0,
  });

  @override
  State<KampusHaritasiSayfasi> createState() => _KampusHaritasiSayfasiState();
}

class _KampusHaritasiSayfasiState extends State<KampusHaritasiSayfasi> {
  // Controller ve Servisler
  GoogleMapController? _mapController;
  final MapDataService _mapDataService = MapDataService();
  StreamSubscription? _firestoreSubscription;
  StreamSubscription? _locationSubscription;

  // Durum Değişkenleri
  String _currentFilter = 'all';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _radiusCircles = {};
  LatLng? _userLocation;
  BitmapDescriptor? _iconUser;
  bool _isLoading = false;
  bool _isRouteActive = false;

  // ✅ RADIUS KONTROLLERİ
  double _searchRadiusKm = 5.0; // Başlangıç: 5km
  bool _showRadiusCircle = false; // Sadece filter != 'all' olunca göster
  
  // ✅ YENİ: Error state tracking
  String? _locationError;
  bool _permissionDenied = false;
  
  // Kullanıcı Üniversitesi (Ring sistemi için)
  String? _userUniversity;

  // Veri Havuzları
  List<LocationModel> _firestoreLocations = [];
  List<LocationModel> _googleLocations = [];

  // Arama İşlemleri
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  DateTime? _lastApiCall; // ✅ Rate limiting

  // Global Key'ler (Tutorial için)
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _filterChipKey = GlobalKey();
  final GlobalKey _myLocationButtonKey = GlobalKey();

  // Harita Stili (Karanlık Mod)
  final String _darkMapStyle = '''
    [
      {"elementType": "geometry","stylers": [{"color": "#242f3e"}]},
      {"elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},
      {"elementType": "labels.text.stroke","stylers": [{"color": "#242f3e"}]},
      {"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},
      {"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},
      {"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},
      {"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},
      {"featureType": "road","elementType": "geometry","stylers": [{"color": "#38414e"}]},
      {"featureType": "road","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},
      {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},
      {"featureType": "road.highway","elementType": "geometry","stylers": [{"color": "#746855"}]},
      {"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},
      {"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},
      {"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},
      {"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},
      {"featureType": "water","elementType": "labels.text.stroke","stylers": [{"color": "#17263c"}]}
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _initializeMapSequence();
    _fetchUserUniversity(); // Üniversite bilgisini çek
  }

  // Kullanıcının kayıtlı üniversitesini öğren
  Future<void> _fetchUserUniversity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          // submissionData içinden veya ana profilden üniversite adını al
          String? uniName = data?['universite'];
          if (uniName == null && data?['submissionData'] != null) {
             uniName = data?['submissionData']['university'];
          }
          setState(() {
            _userUniversity = uniName;
          });
        }
      } catch (e) {
        debugPrint("Üniversite bilgisi alınamadı: $e");
      }
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeMapSequence() async {
    setState(() => _isLoading = true);
    try {
      await _prepareCustomMarkers();
      await _initializeLocationStream();
      await _loadPlaces();
      if (mounted) _showTutorial();
    } catch (e) {
      debugPrint("Harita başlatma hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. Marker İkonlarını Oluşturma ---
  Future<void> _prepareCustomMarkers() async {
    try {
      _iconUser = await _createMarkerBitmap(Icons.person_pin, AppColors.primary);
      final iconUni = await _createMarkerBitmap(Icons.school, Colors.redAccent);
      final iconYemek = await _createMarkerBitmap(Icons.restaurant, Colors.orangeAccent);
      final iconDurak = await _createMarkerBitmap(Icons.directions_bus, Colors.blueAccent);
      final iconKutuphane = await _createMarkerBitmap(Icons.menu_book, Colors.purpleAccent);

      _mapDataService.setIcons(
        iconUni: iconUni,
        iconYemek: iconYemek,
        iconDurak: iconDurak,
        iconKutuphane: iconKutuphane,
      );
    } catch (e) {
      debugPrint("İkon oluşturma hatası: $e");
    }
  }

  Future<BitmapDescriptor> _createMarkerBitmap(IconData icon, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const size = Size(120, 120);

    final Paint paint = Paint()..color = color;
    final Paint shadowPaint = Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + 4), size.width / 2 - 4, shadowPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 4, paint);

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontSize: 70, fontFamily: icon.fontFamily, color: Colors.white, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));

    final img = await pictureRecorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // --- 2. Kullanıcı Konumu (DÜZELTİLEN KISIM) ---
  Future<void> _initializeLocationStream() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationError = "Konum servisleri kapalı. Lütfen açınız.");
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _permissionDenied = true;
              _locationError = "Konum izni reddedildi.";
            });
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _locationError = "Konum izni kalıcı olarak reddedildi. Ayarlardan açınız.";
          });
        }
        return;
      }

      // Platforma özel LocationSettings
      LocationSettings locationSettings;
      try {
        if (Platform.isAndroid) {
          // ✅ GÜNCELLENDİ: bestForNavigation (maksimum doğruluk - navigasyon için)
          // ✅ GÜNCELLENDİ: intervalDuration 2 saniyeye düşürüldü (daha hızlı güncellemeler)
          // ✅ GÜNCELLENDİ: distanceFilter 2 metreye düşürüldü (anında güncelleme)
          // ✅ GÜNCELLENDİ: pauseLocationUpdatesAutomatically false (sürekli takip)
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
            intervalDuration: const Duration(seconds: 2),
            forceLocationManager: false,
          );
        } else if (Platform.isIOS) {
          locationSettings = AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            distanceFilter: 2,
            pauseLocationUpdatesAutomatically: false,
          );
        } else {
          locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          );
        }
      } catch (e) {
        // LocationSettings başarısız olursa fallback
        debugPrint("LocationSettings hatası: $e");
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        );
      }

      // İlk konum al - ✅ bestForNavigation ile (maksimum doğruluk)
      try {
        Position initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 20),
        );
        
        if (mounted) {
          setState(() {
            _userLocation = LatLng(initialPos.latitude, initialPos.longitude);
            _locationError = null; // Hata temizle
          });
          
          // Marker'ları güncelle
          _updateMarkers();
          
          if (widget.initialFocus == null && _mapController != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, 15),
            );
          }
        }
      } catch (e) {
        debugPrint("İlk konum alınamadı: $e");
        // Hata olsa da stream'i başlat
      }

      // Stream dinleme
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          if (mounted) {
            setState(() {
              _userLocation = LatLng(pos.latitude, pos.longitude);
              _updateMarkers();
            });
          }
        },
        onError: (e) {
          debugPrint("Location stream hatası: $e");
          if (mounted) {
            setState(() => _locationError = "Konum alma hatası");
          }
        },
      );

    } catch (e) {
      debugPrint("Konum sistemi hatası: $e");
      if (mounted) {
        setState(() => _locationError = "Konum servisi başlatılamadı");
      }
    }
  }

  // --- 3. Mekanları Getirme (Firestore + Google Places) ---
  Future<void> _loadPlaces() async {
    if (!mounted) return;
    await _firestoreSubscription?.cancel();
    final center = _userLocation ?? widget.initialFocus ?? const LatLng(41.0082, 28.9784);

    _firestoreSubscription = _mapDataService.getLocationsStream(_currentFilter).listen((firestorePlaces) {
      if (mounted) {
        _firestoreLocations = firestorePlaces;
        _updateMarkers(); 
      }
    });

    try {
      final googlePlaces = await _mapDataService.searchNearbyPlaces(center: center, typeFilter: _currentFilter);
      if (mounted) {
        _googleLocations = googlePlaces;
        _updateMarkers(); 
      }
    } catch (e) {
      debugPrint("Google Places Hatası: $e");
    }
  }

  // --- Markerları Birleştirme ---
  void _updateMarkers() {
    if (!mounted) return;
    Set<Marker> newMarkers = {};
    Set<Circle> newCircles = {};

    // ✅ KULLANICI KONUM MARKER'I - TÜM KATEGORİLERDE GÖSTER
    if (_userLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: _iconUser ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Konumun'),
          zIndex: 3,
        ),
      );
      
      // ✅ RADIUS DÜLESİ - Sadece 'all' dışında ve açıksa göster
      if (_currentFilter != 'all' && _showRadiusCircle) {
        newCircles.add(
          Circle(
            circleId: const CircleId('search_radius'),
            center: _userLocation!,
            radius: _searchRadiusKm * 1000,
            fillColor: AppColors.primary.withOpacity(0.1),
            strokeColor: AppColors.primary.withOpacity(0.5),
            strokeWidth: 2,
            zIndex: 1,
          ),
        );
      }
    }

    // Firestore lokasyonları (Radius ile filtrele)
    for (var loc in _firestoreLocations) {
      bool isInRadius = true;
      if (_userLocation != null && _currentFilter != 'all' && _showRadiusCircle) {
        double distKm = _calculateDistance(_userLocation!, loc.position);
        isInRadius = distKm <= _searchRadiusKm;
      }

      if (isInRadius) {
        newMarkers.add(Marker(
          markerId: MarkerId("fs_${loc.id}"),
          position: loc.position,
          icon: loc.icon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: loc.title, snippet: loc.snippet),
          onTap: () => _showLocationDetails(loc),
        ));
      }
    }

    // Google Places lokasyonları
    for (var loc in _googleLocations) {
      bool isDuplicate = _firestoreLocations.any((f) {
        double dist = _calculateDistance(f.position, loc.position);
        return dist < 0.05; 
      });

      bool isInRadius = true;
      if (_userLocation != null && _currentFilter != 'all' && _showRadiusCircle) {
        double distKm = _calculateDistance(_userLocation!, loc.position);
        isInRadius = distKm <= _searchRadiusKm;
      }

      if (!isDuplicate && isInRadius) {
        newMarkers.add(Marker(
          markerId: MarkerId("g_${loc.id}"),
          position: loc.position,
          icon: loc.icon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(title: loc.title),
          onTap: () => _showLocationDetails(loc),
        ));
      }
    }

    // Arama sonuçları marker'ları
    final searchMarkers = _markers.where((m) => m.markerId.value.startsWith("s_"));
    newMarkers.addAll(searchMarkers);

    setState(() {
      _markers = newMarkers;
      _radiusCircles = newCircles;
    });
    
    // ✅ ZOOM OPTIMIZATION
    if (_mapController != null && _showRadiusCircle && _userLocation != null) {
      _optimizeZoomLevel();
    }
  }

  // ✅ ZOOM SEVIYESINI OTOMATİK AYARLA
  void _optimizeZoomLevel() {
    if (_mapController == null || _markers.isEmpty) return;
    double baseZoom = 15.0;
    if (_searchRadiusKm > 15) baseZoom = 12.0;
    else if (_searchRadiusKm > 10) baseZoom = 13.0;
    else if (_searchRadiusKm > 5) baseZoom = 14.0;
    if (_markers.length > 20) baseZoom -= 1;
    if (_markers.length > 40) baseZoom -= 1;
    if (_markers.length > 60) baseZoom -= 2;
    baseZoom = baseZoom.clamp(10.0, 18.0);
    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, baseZoom),
      );
    } catch (e) {
      debugPrint("Zoom animation hatası: $e");
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371.0; 
    double degToRad(double deg) => deg * (pi / 180);
    double lat1Rad = degToRad(p1.latitude);
    double lon1Rad = degToRad(p1.longitude);
    double lat2Rad = degToRad(p2.latitude);
    double lon2Rad = degToRad(p2.longitude);
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (Theme.of(context).brightness == Brightness.dark) {
      try { controller.setMapStyle(_darkMapStyle); } catch (_) {}
    }
    if (widget.initialFocus != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(widget.initialFocus!, 16));
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _markers.removeWhere((m) => m.markerId.value.startsWith("s_"));
        });
      }
      return;
    }

    // ✅ Rate limiting: API'yi en fazla 5 saniyede bir çağır
    final now = DateTime.now();
    if (_lastApiCall != null && now.difference(_lastApiCall!).inSeconds < 5) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      setState(() => _lastApiCall = DateTime.now());
      
      try {
        final results = await _mapDataService.getPlacePredictions(query, _userLocation);
        if (mounted) {
          setState(() => _searchResults = results);
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Arama yapılamadı")),
          );
        }
      }
    });
  }

  Future<void> _onSearchResultSelected(String placeId) async {
    FocusScope.of(context).unfocus();
    setState(() { 
      _searchResults = []; 
      _isLoading = true;
      _isRouteActive = false; // ✅ Rota temizle
    });
    _searchController.clear();

    try {
      final location = await _mapDataService.getPlaceDetails(placeId);
      
      if (location != null && mounted) {
        setState(() {
          _isLoading = false;
          _markers.removeWhere((m) => m.markerId.value.startsWith("s_"));
          _markers.add(Marker(
            markerId: MarkerId("s_${location.id}"),
            position: location.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
            infoWindow: InfoWindow(title: location.title),
            onTap: () => _showLocationDetails(location),
          ));
        });
        
        if (_mapController != null) {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location.position, 17));
          await Future.delayed(const Duration(milliseconds: 300)); // ✅ Animation bitmesini bekle
          if (mounted) {
            _showLocationDetails(location);
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konum detayları alınamadı.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Mekan detayı hatası: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    }
  }

  Future<void> _drawRoute(LatLng destination) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konumunuz alınamadı.")),
      );
      return;
    }
    
    Navigator.pop(context); 
    setState(() => _isLoading = true);
    
    try {
      final points = await _mapDataService.getRouteCoordinates(_userLocation!, destination);
      
      if (points.isEmpty && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rota bulunamadı.")),
        );
        return;
      }
      
      if (mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('active_route'),
              points: points,
              color: AppColors.primary,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            )
          };
          _isRouteActive = true;
          _isLoading = false;
        });
        
        if (_mapController != null) {
          try {
            LatLngBounds bounds = _boundsFromLatLngList(points);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          } catch (e) {
            debugPrint("Rota animation hatası: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Rota çizme hatası: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rota hatası: $e")),
        );
      }
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  // --- YENİ: Ring Seferleri Paneli ---
  void _showRingSchedule() {
    if (_userUniversity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profilinizde üniversite bilgisi bulunamadı.")));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => RingSeferleriSheet(universityName: _userUniversity!), // Parametre gönderiliyor
    );
  }

  // --- Yorum/Puanlama Ekranları ---
  void _showAddReviewDialog(LocationModel location) {
    final pageContext = context;
    double rating = 3.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Yorum Yap"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("'${location.title}' için puanınız:"),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () => setDialogState(() => rating = index + 1.0),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: "Deneyimlerinizi paylaşın...",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                ElevatedButton(
                  onPressed: () async {
                    final comment = commentController.text.trim();
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum boş bırakılamaz.")));
                      return;
                    }
                    Navigator.pop(context); 
                    
                    final error = await _mapDataService.addReview(location.id, rating, comment);
                    if (!mounted) return;
                    
                    if (error != null) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text("Hata: $error"), backgroundColor: AppColors.error));
                    } else {
                      ScaffoldMessenger.of(pageContext).showSnackBar(const SnackBar(content: Text("Yorumunuz eklendi!"), backgroundColor: AppColors.success));
                    }
                  },
                  child: const Text("Gönder"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Detay BottomSheet ---
  void _showLocationDetails(LocationModel location) {
    String distanceText = "Bilinmiyor";
    String timeText = "---";
    
    if (_userLocation != null) {
      double km = _calculateDistance(_userLocation!, location.position);
      distanceText = "${km.toStringAsFixed(2)} km";
      int mins = (km / 4.5 * 60).round(); 
      timeText = "~$mins dk";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)]
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Resim Alanı
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      location.photoUrls.isNotEmpty
                        ? PageView.builder(
                            itemCount: location.photoUrls.length,
                            itemBuilder: (_, i) => CachedNetworkImage(
                              cacheManager: DefaultCacheManager(),
                              imageUrl: location.photoUrls[i],
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                              errorWidget: (c, u, e) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                          ),
                      Positioned(
                        top: 10, right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // İçerik Alanı
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(location.snippet, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 16),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_userLocation != null) ...[
                            _buildInfoBadge(Icons.straighten, distanceText, AppColors.primary),
                            _buildInfoBadge(Icons.directions_walk, timeText, Colors.blue),
                          ],
                          if (location.reviewCount > 0)
                            _buildInfoBadge(Icons.star, "${location.firestoreRating.toStringAsFixed(1)} (${location.reviewCount})", Colors.purple),
                          if (location.rating > 0)
                            _buildInfoBadge(Icons.public, "Google: ${location.rating}", Colors.amber),
                          if (location.openingHours != null)
                            _buildInfoBadge(Icons.access_time, location.openingHours!, location.openingHours!.contains('Açık') ? Colors.green : Colors.red),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Aksiyon Butonları
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _drawRoute(location.position),
                              icon: const Icon(Icons.directions, color: Colors.white),
                              label: const Text("Yol Tarifi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddReviewDialog(location),
                              icon: const Icon(Icons.rate_review),
                              label: const Text("Yorum Yap"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal( 
                            onPressed: () async {
                                final url = 'https://www.google.com/maps/search/?api=1&query=${location.position.latitude},${location.position.longitude}';
                                try {
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harita uygulaması açılamadı.")));
                                }
                            },
                            icon: const Icon(Icons.map),
                            tooltip: "Google Maps'te Aç",
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      const Text("Canlı Durum Oylaması", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildVoteButton("Sakin", Colors.green, location.id),
                          const SizedBox(width: 10),
                          _buildVoteButton("Normal", Colors.orange, location.id),
                          const SizedBox(width: 10),
                          _buildVoteButton("Kalabalık", Colors.red, location.id),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Tutorial ---
  void _showTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MaskotHelper.checkAndShow(context,
          featureKey: 'harita_tutorial_gosterildi',
          targets: [
            TargetFocus(
                identify: "search-bar",
                keyTarget: _searchBarKey,
                alignSkip: Alignment.bottomRight,
                contents: [
                  TargetContent(
                      align: ContentAlign.bottom,
                      builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Kampüsü Keşfet!', description: 'Fakülteler, kafeler, kütüphane... Aradığın her yeri buradan arayarak kolayca bulabilirsin.', mascotAssetPath: 'assets/images/düsünceli_bay.png'))
                ]),
            TargetFocus(
                identify: "filter-chips",
                keyTarget: _filterChipKey,
                alignSkip: Alignment.bottomRight,
                contents: [
                  TargetContent(
                      align: ContentAlign.bottom,
                      builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Kategorilere Göz At', description: 'İstersen mekanları kategorilerine göre filtreleyerek de haritada görebilirsin.', mascotAssetPath: 'assets/images/mutlu_bay.png'))
                ]),
            TargetFocus(
                identify: "my-location-button",
                keyTarget: _myLocationButtonKey,
                alignSkip: Alignment.topLeft,
                contents: [
                  TargetContent(
                      align: ContentAlign.top,
                      builder: (context, controller) => MaskotHelper.buildTutorialContent(context, title: 'Konumunu Bul', description: 'Haritada kaybolursan bu butona basarak anında kendi konumuna dönebilirsin.'))
                ])
          ]);
    });
  }

  // --- Küçük UI Bileşenleri ---
  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVoteButton(String text, Color color, String locId) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _mapDataService.voteForStatus(locId, text);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Oylandı: $text"), duration: const Duration(seconds: 1)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.05),
          ),
          child: Column(
            children: [
              Icon(Icons.thumb_up_alt_outlined, color: color, size: 20),
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, IconData icon) {
    final isSelected = _currentFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = key;
          _showRadiusCircle = (key != 'all');
          _searchRadiusKm = 5.0;
        });
        _loadPlaces();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. HARİTA KATMANI
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 12),
            onMapCreated: _onMapCreated,
            markers: _markers,
            polylines: _polylines,
            circles: _radiusCircles,
            myLocationEnabled: false, 
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ✅ YENİ: Konum izni hata durumu gösterimi
          if (_permissionDenied)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.withOpacity(0.9),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Konum İzni Gerekli",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (_locationError != null)
                              Text(
                                _locationError!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Geolocator.openLocationSettings(),
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text("Aç"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. ARAMA VE FİLTRE BAR (SafeArea içinde)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arama Çubuğu
                  Container(
                    key: _searchBarKey,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText: "Kampüste ara...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  // Arama Sonuçları Listesi
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                            title: Text(item['structured_formatting']['main_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item['structured_formatting']['secondary_text'] ?? '', maxLines: 1),
                            onTap: () => _onSearchResultSelected(item['place_id']),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Filtre Çipleri
                  if (_searchResults.isEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        key: _filterChipKey,
                        children: [
                          _buildFilterChip('Tümü', 'all', Icons.map),
                          _buildFilterChip('Üniversiteler', 'universite', Icons.school),
                          _buildFilterChip('Yemek', 'yemek', Icons.restaurant),
                          _buildFilterChip('Duraklar', 'durak', Icons.directions_bus),
                          _buildFilterChip('Kütüphane', 'kutuphane', Icons.menu_book),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ✅ YENİ: RADIUS KONTROL PANELİ
          if (_showRadiusCircle && _userLocation != null)
            Positioned(
              left: 16,
              top: 130,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background gradient (renkli arka)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.08),
                              AppColors.primary.withOpacity(0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom fade gradient (aşağıya doğru yok olan)
                    Positioned(
                      bottom: -12,
                      left: -12,
                      right: -12,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).cardColor.withOpacity(0.3),
                              Theme.of(context).cardColor.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_searchRadiusKm.toStringAsFixed(1)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'radiusDown',
                              backgroundColor: Colors.red.withOpacity(0.8),
                              child: const Icon(Icons.remove, color: Colors.white, size: 18),
                              onPressed: () {
                                if (_searchRadiusKm > 1.0) {
                                  setState(() => _searchRadiusKm -= 1.0);
                                  _updateMarkers();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton.small(
                              heroTag: 'radiusUp',
                              backgroundColor: Colors.green.withOpacity(0.8),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                              onPressed: () {
                                if (_searchRadiusKm < 25.0) {
                                  setState(() => _searchRadiusKm += 1.0);
                                  _updateMarkers();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 3. YÜKLENİYOR İNDİKATÖRÜ
          if (_isLoading)
            Positioned(
              top: 130, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text("Yükleniyor...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ),

          // 4. ALT AKSİYON BUTONLARI (Konum & Rota & Ring)
          Positioned(
            bottom: 30, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // YENİ: Ring Seferleri Butonu
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.small(
                    heroTag: 'ringSchedule',
                    backgroundColor: Colors.amber[700],
                    child: const Icon(Icons.directions_bus, color: Colors.white),
                    onPressed: _showRingSchedule, // Yeni fonksiyon
                  ),
                ),

                if (_isRouteActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FloatingActionButton.small(
                      heroTag: 'clearRoute',
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _polylines.clear();
                          _isRouteActive = false;
                        });
                      },
                    ),
                  ),
                
                FloatingActionButton(
                  key: _myLocationButtonKey,
                  heroTag: 'myLoc',
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 16));
                    } else {
                      _initializeLocationStream(); // Konum yoksa tekrar iste
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
