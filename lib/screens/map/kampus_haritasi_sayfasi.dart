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
import '../../models/location_marker_model.dart'; // LocationMarker model için
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
  Set<Circle> _circles = {}; // DÜZELTME: _radiusCircles -> _circles
  LatLng? _userLocation;
  double _currentAccuracy = 0.0; // YENİ: GPS doğruluğu için
  BitmapDescriptor? _iconUser;
  bool _isLoading = false;
  bool _isRouteActive = false;

  // RADIUS KONTROLLERİ
  double _searchRadiusKm = 5.0; 
  bool _showRadiusCircle = true; 
  
  // YENİ: Error state tracking
  String? _locationError;
  bool _permissionDenied = false;
  
  // Kullanıcı Üniversitesi (Ring sistemi için)
  String? _userUniversity;

  // YENİ: Location Markers
  bool _showCustomMarkers = true;
  List<LocationMarker> _customLocationMarkers = [];

  // Veri Havuzları
  List<LocationModel> _firestoreLocations = [];
  List<LocationModel> _googleLocations = [];

  // Arama İşlemleri
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  DateTime? _lastApiCall;

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
    _fetchUserUniversity();
  }

  Future<void> _fetchUserUniversity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
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
      await _loadCustomLocationMarkers();
      if (mounted) _showTutorial();
    } catch (e) {
      debugPrint("Harita başlatma hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

      LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0, // YENİ: En ufak hareketi bile yakala
          forceLocationManager: true, // YENİ: Sadece GPS kullanmaya zorla
          intervalDuration: const Duration(seconds: 2),
        );
      } else {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      }

      try {
        Position initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 20),
        );
        
        if (mounted) {
          setState(() {
            _userLocation = LatLng(initialPos.latitude, initialPos.longitude);
            _currentAccuracy = initialPos.accuracy;
            _locationError = null;
          });
          
          _updateMarkers();
          
          if (widget.initialFocus == null && _mapController != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, 15),
            );
          }
        }
      } catch (e) {
        debugPrint("İlk konum alınamadı: $e");
      }

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position pos) {
          if (mounted) {
            setState(() {
              _userLocation = LatLng(pos.latitude, pos.longitude);
              _currentAccuracy = pos.accuracy; // YENİ: Doğruluk bilgisini anlık güncelle
              _updateMarkers();
            });
          }
        },
        onError: (e) {
          debugPrint("Location stream hatası: $e");
          if (mounted) {
            setState(() => _locationError = "Konum alma hatası");
            _showLocationErrorDialog("Konumunuz alınamadı. Lütfen konum izninizi kontrol edin.");
          }
        },
      );

    } catch (e) {
      debugPrint("Konum sistemi hatası: $e");
      if (mounted) {
        setState(() => _locationError = "Konum servisi başlatılamadı");
        _showLocationErrorDialog("Konum servisi başlatılamadı. Tekrar deneyin.");
      }
    }
  }

  void _showLocationErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.red.shade50,
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/uzgun_bay.png',
                width: 100,
                height: 100,
                errorBuilder: (c, e, s) => Icon(
                  Icons.location_off_rounded,
                  size: 80,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Konum Hatası ⚠️",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Anlaşıldı",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadPlaces({bool refreshFirestore = true}) async {
    if (!mounted) return;
    final center = _userLocation ?? widget.initialFocus ?? const LatLng(41.0082, 28.9784);

    if (refreshFirestore) {
      await _firestoreSubscription?.cancel();
      _firestoreSubscription = _mapDataService.getLocationsStream(_currentFilter).listen((firestorePlaces) {
        if (mounted) {
          _firestoreLocations = firestorePlaces;
          _updateMarkers(); 
        }
      });
    }

    try {
      List<LocationModel> googlePlaces = [];
      
      // "Tümü" ise tüm kategorileri yükle
      if (_currentFilter == 'all') {
        final uniPlaces = await _mapDataService.searchNearbyPlaces(
          center: center,
          typeFilter: 'universite',
          radiusKm: _searchRadiusKm,
        );
        final restPlaces = await _mapDataService.searchNearbyPlaces(
          center: center,
          typeFilter: 'yemek',
          radiusKm: _searchRadiusKm,
        );
        final transitPlaces = await _mapDataService.searchNearbyPlaces(
          center: center,
          typeFilter: 'durak',
          radiusKm: _searchRadiusKm,
        );
        final libPlaces = await _mapDataService.searchNearbyPlaces(
          center: center,
          typeFilter: 'kutuphane',
          radiusKm: _searchRadiusKm,
        );
        googlePlaces = [...uniPlaces, ...restPlaces, ...transitPlaces, ...libPlaces];
      } else {
        googlePlaces = await _mapDataService.searchNearbyPlaces(
          center: center,
          typeFilter: _currentFilter,
          radiusKm: _searchRadiusKm,
        );
      }
      
      if (mounted) {
        _googleLocations = googlePlaces;
        _updateMarkers(); 
      }
    } catch (e) {
      debugPrint("Google Places Hatası: $e");
    }
  }

  void _updateMarkers() {
    if (!mounted) return;
    Set<Marker> newMarkers = {};
    Set<Circle> newCircles = {};

    if (_userLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: _iconUser ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Konumun'),
          zIndex: 3,
          anchor: const Offset(0.5, 0.5), // YENİ: İkonu ortala
        ),
      );
      
      // YENİ: GPS Doğruluk Dairesi
      newCircles.add(
        Circle(
          circleId: const CircleId('accuracy_circle'),
          center: _userLocation!,
          radius: _currentAccuracy, // Konumun doğruluk (sapma) payı
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue.withOpacity(0.3),
          strokeWidth: 1,
          zIndex: 0,
        )
      );

      if (_showRadiusCircle) {
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

    for (var loc in _firestoreLocations) {
      bool isInRadius = true;
      if (_userLocation != null && _showRadiusCircle) {
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

    for (var loc in _googleLocations) {
      bool isDuplicate = _firestoreLocations.any((f) {
        double dist = _calculateDistance(f.position, loc.position);
        return dist < 0.05; 
      });

      bool isInRadius = true;
      if (_userLocation != null && _showRadiusCircle) {
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

    final searchMarkers = _markers.where((m) => m.markerId.value.startsWith("s_"));
    newMarkers.addAll(searchMarkers);

    // YENİ: Custom location markers ekle
    if (_showCustomMarkers) {
      for (var marker in _customLocationMarkers) {
        final iconColor = _getMarkerColorByType(marker.iconType);
        newMarkers.add(Marker(
          markerId: MarkerId("cm_${marker.id}"),
          position: LatLng(marker.latitude, marker.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getHueForColor(iconColor)),
          infoWindow: InfoWindow(
            title: marker.name,
            snippet: marker.description,
          ),
          onTap: () => _showCustomMarkerDetails(marker),
        ));
      }
    }

    setState(() {
      _markers = newMarkers;
      _circles = newCircles; // DÜZELTME: _radiusCircles -> _circles
    });
    
    if (_mapController != null && _showRadiusCircle && _userLocation != null) {
      _optimizeZoomLevel();
    }
  }

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
    _animateZoomToLevel(baseZoom);
  }

  void _animateZoomForRadius() {
    if (_mapController == null || _userLocation == null) return;
    double baseZoom = 15.0;
    if (_searchRadiusKm > 15) baseZoom = 12.0;
    else if (_searchRadiusKm > 10) baseZoom = 13.0;
    else if (_searchRadiusKm > 5) baseZoom = 14.0;
    baseZoom = baseZoom.clamp(10.0, 18.0);
    _animateZoomToLevel(baseZoom);
  }

  void _animateZoomToLevel(double zoom) {
    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, zoom),
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

    final now = DateTime.now();
    if (_lastApiCall != null && now.difference(_lastApiCall!).inSeconds < 5) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      setState(() => _lastApiCall = DateTime.now());
      
      try {
        final loc = _userLocation ?? const LatLng(39.9334, 32.8597);
        final results = await _mapDataService.getPlacePredictions(
          query,
          loc,
          radiusKm: _searchRadiusKm,
        );
        if (mounted) {
          setState(() => _searchResults = List<Map<String, dynamic>>.from(results));
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

  Future<void> _onSearchResultSelected(Map<String, dynamic> item) async {
    FocusScope.of(context).unfocus();
    setState(() { 
      _searchResults = []; 
      _isRouteActive = false; 
      _isLoading = true;
    });
    _searchController.clear();

    try {
      final placeId = item['place_id'] as String?;
      if (placeId == null) {
        throw Exception('Mekan detayı alınamadı');
      }

      final fallbackType = _predictionType(item);
      final location = await _mapDataService.getPlaceDetails(
        placeId,
        fallbackType: fallbackType,
        fallbackIcon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
      );

      if (location == null) {
        throw Exception('Mekan bulunamadı');
      }

      if (mounted) {
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
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _showLocationDetails(location);
          }
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

  // Tür için uygun ikonu al
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'universite':
        return Icons.school;
      case 'yemek':
        return Icons.restaurant;
      case 'durak':
        return Icons.directions_bus;
      case 'kutuphane':
        return Icons.menu_book;
      default:
        return Icons.location_on_outlined;
    }
  }

  String _predictionType(Map<String, dynamic> prediction) {
    final types = (prediction['types'] as List?)?.cast<String>() ?? const [];

    bool matches(List<String> needles) {
      return types.any((t) => needles.any((needle) => t.toLowerCase().contains(needle)));
    }

    if (matches(['university', 'school'])) return 'universite';
    if (matches(['restaurant', 'cafe', 'food', 'meal_takeaway', 'meal_delivery'])) return 'yemek';
    if (matches(['bus_station', 'transit_station', 'subway', 'train', 'light_rail'])) return 'durak';
    if (matches(['library', 'book_store'])) return 'kutuphane';
    return 'diger';
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

  void _showRingSchedule() {
    if (_userUniversity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profilinizde üniversite bilgisi bulunamadı.")));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => RingSeferleriSheet(universityName: _userUniversity!),
    );
  }

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

  void _showTutorial() {
    // Google Maps hazır olana kadar ekstra bekleme süresini ekle
    Future.delayed(Duration(milliseconds: 1000), () {
      if (!mounted) return;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeTutorialTargets();
      });
    });
  }

  void _initializeTutorialTargets() {
    List<TargetFocus> targets = [];

    // Search Bar
    if (_searchBarKey.currentContext != null && _searchBarKey.currentContext!.findRenderObject() != null) {
      targets.add(
        TargetFocus(
          identify: "search-bar",
          keyTarget: _searchBarKey,
          alignSkip: Alignment.bottomRight,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => MaskotHelper.buildTutorialContent(
                context,
                title: 'Kampüsü Keşfet!',
                description: 'Fakülteler, kafeler, kütüphane... Aradığın her yeri buradan arayarak kolayca bulabilirsin.',
                mascotAssetPath: 'assets/images/düsünceli_bay.png',
              ),
            )
          ],
        ),
      );
    }

    // Filter Chips
    if (_filterChipKey.currentContext != null && _filterChipKey.currentContext!.findRenderObject() != null) {
      targets.add(
        TargetFocus(
          identify: "filter-chips",
          keyTarget: _filterChipKey,
          alignSkip: Alignment.bottomRight,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => MaskotHelper.buildTutorialContent(
                context,
                title: 'Kategorilere Göz At',
                description: 'İstersen mekanları kategorilerine göre filtreleyerek de haritada görebilirsin.',
                mascotAssetPath: 'assets/images/mutlu_bay.png',
              ),
            )
          ],
        ),
      );
    }

    // My Location Button
    if (_myLocationButtonKey.currentContext != null && _myLocationButtonKey.currentContext!.findRenderObject() != null) {
      targets.add(
        TargetFocus(
          identify: "my-location-button",
          keyTarget: _myLocationButtonKey,
          alignSkip: Alignment.topLeft,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => MaskotHelper.buildTutorialContent(
                context,
                title: 'Konumunu Bul',
                description: 'Haritada kaybolursan bu butona basarak anında kendi konumuna dönebilirsin.',
                mascotAssetPath: 'assets/images/duyuru_bay.png',
              ),
            )
          ],
        ),
      );
    }

    if (targets.isNotEmpty) {
      MaskotHelper.checkAndShowSafe(
        context,
        featureKey: 'harita_tutorial_gosterildi',
        rawTargets: targets,
        delay: Duration(milliseconds: 300),
        maxRetries: 2,
      );
    } else {
      debugPrint('⚠️ Harita maskotu: Geçerli hedef bulunamadı (maps henüz hazır değil)');
    }
  }

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
          _mapDataService.voteForStatus(locId, 'review_default', text.toLowerCase());
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
          _currentFilter = key.toLowerCase();
          _showRadiusCircle = true;
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
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 12),
            onMapCreated: _onMapCreated,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            myLocationEnabled: false, 
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

              // YENİ: Gradient Overlay Katmanı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 250, // Geniş bir alan vererek yumuşak geçiş sağla
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0], // Geçişin nerede biteceğini ayarla
                  ),
                ),
              ),
            ),
          ),

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

          // YENİ: UI Katmanı (Gradient'in üzerinde)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: _searchBarKey,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.95), // YARI-ŞEFFAF ARKA PLAN
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
                              _onSearchChanged('');
                            },
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

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
                          final structured = item['structured_formatting'] as Map<String, dynamic>?;
                          final title = structured?['main_text'] ?? item['description'] ?? '';
                          final subtitle = structured?['secondary_text'] ?? item['description'] ?? '';
                          final type = _predictionType(item);
                          
                          return ListTile(
                            leading: Icon(
                              _getIconForType(type),
                              color: Colors.grey,
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(subtitle, maxLines: 1),
                            onTap: () => _onSearchResultSelected(item),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),

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

          if (_showRadiusCircle && _userLocation != null)
            Positioned(
              left: 16,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.02),
                    ],
                  ),
                ),
                child: Column(
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
                              _loadPlaces(refreshFirestore: false);
                              _updateMarkers();
                              _animateZoomForRadius();
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
                              _loadPlaces(refreshFirestore: false);
                              _updateMarkers();
                              _animateZoomForRadius();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

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

          Positioned(
            bottom: 30, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.small(
                    heroTag: 'ringSchedule',
                    backgroundColor: Colors.amber[700],
                    child: const Icon(Icons.directions_bus, color: Colors.white),
                    onPressed: _showRingSchedule, 
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
                      _initializeLocationStream(); 
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

  // YENİ: Location Marker yardımcı metodlar
  Future<void> _loadCustomLocationMarkers() async {
    try {
      // TODO: LocationMarkerService implement edilecek
      // final markers = await LocationMarkerService.getAllMarkers().first;
      if (mounted) {
        setState(() {
          _customLocationMarkers = [];
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint("Location markers yükleme hatası: $e");
    }
  }

  Color _getMarkerColorByType(String iconType) {
    switch (iconType.toLowerCase()) {
      case 'canteen':
        return Colors.orangeAccent;
      case 'library':
        return Colors.purpleAccent;
      case 'classroom':
        return Colors.blueAccent;
      case 'event':
        return Colors.redAccent;
      default:
        return Colors.greenAccent;
    }
  }

  double _getHueForColor(Color color) {
    // Renk değerini HSV hue değerine dönüştür
    if (color == Colors.orangeAccent) return BitmapDescriptor.hueOrange;
    if (color == Colors.purpleAccent) return BitmapDescriptor.hueViolet;
    if (color == Colors.blueAccent) return BitmapDescriptor.hueBlue;
    if (color == Colors.redAccent) return BitmapDescriptor.hueRed;
    return BitmapDescriptor.hueGreen;
  }

  void _showCustomMarkerDetails(LocationMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marker.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${marker.category}'),
            const SizedBox(height: 8),
            Text('Tür: ${marker.iconType}'),
            const SizedBox(height: 8),
            Text(marker.description),
            const SizedBox(height: 8),
            Text('Konum: (${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_mapController != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(marker.latitude, marker.longitude),
                    16,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Merkeze Al'),
          ),
        ],
      ),
    );
  }
}