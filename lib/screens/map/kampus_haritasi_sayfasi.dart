import 'dart:async';
import 'dart:math' show cos, sqrt, atan2, pi, sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Servis ve Yardımcılar
import '../../services/map_data_service.dart';
import '../../utils/app_colors.dart';
import '../../services/image_cache_manager.dart';
import '../../utils/maskot_helper.dart';

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
  LatLng? _userLocation;
  BitmapDescriptor? _iconUser;
  bool _isLoading = false;
  bool _isRouteActive = false;
  bool _isMapCreated = false;

  // Veri Havuzları
  List<LocationModel> _firestoreLocations = [];
  List<LocationModel> _googleLocations = [];

  // Arama İşlemleri
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

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

  /// Harita Başlatma Sırası: İkonlar -> Konum -> Veriler -> Tutorial
  Future<void> _initializeMapSequence() async {
    setState(() => _isLoading = true);

    try {
      // 1. İkonları hazırla
      await _prepareCustomMarkers();

      // 2. Konumu al ve dinlemeye başla
      await _initializeLocationStream();

      // 3. Mekanları yükle (Konum alındıktan sonra)
      await _loadPlaces();

      // 4. Tutorial göster (UI çizildikten sonra)
      if (mounted) {
        _showTutorial();
      }
    } catch (e) {
      debugPrint("Harita başlatma hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. Marker İkonlarını Oluşturma ---
  Future<void> _prepareCustomMarkers() async {
    try {
      // YENİ: Kullanıcı ikonu
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
      // Hata olsa bile devam et, varsayılan ikonlar kullanılır.
    }
  }

  Future<BitmapDescriptor> _createMarkerBitmap(IconData icon, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const size = Size(120, 120); // Boyut biraz artırıldı netlik için

    final Paint paint = Paint()..color = color;
    final Paint shadowPaint = Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Gölge
    canvas.drawCircle(Offset(size.width / 2, size.height / 2 + 4), size.width / 2 - 4, shadowPaint);
    // Ana Daire
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

  // --- 2. Kullanıcı Konumu ---
  Future<void> _initializeLocationStream() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // İlk konumu hızlıca al
      Position initialPos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(initialPos.latitude, initialPos.longitude);
        });
        if (widget.initialFocus == null && _mapController != null) {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15));
        }
      }

      // Konum değişikliklerini dinle
      _locationSubscription = Geolocator.getPositionStream().listen((Position pos) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
            _updateMarkers(); // Konum değiştikçe marker'ı güncelle
          });
        }
      });

    } catch (e) {
      debugPrint("Konum alma hatası: $e");
    }
  }

  // --- 3. Mekanları Getirme (Firestore + Google Places) ---
  Future<void> _loadPlaces() async {
    if (!mounted) return;
    
    // Eski aboneliği temizle
    await _firestoreSubscription?.cancel();

    // Merkez belirle (Kullanıcı konumu yoksa varsayılan İstanbul)
    final center = _userLocation ?? widget.initialFocus ?? const LatLng(41.0082, 28.9784);

    // A. Firestore'u Dinle
    _firestoreSubscription = _mapDataService.getLocationsStream(_currentFilter).listen((firestorePlaces) {
      if (mounted) {
        _firestoreLocations = firestorePlaces;
        _updateMarkers(); // Firestore her güncellendiğinde markerları yenile
      }
    });

    // B. Google Places API Çek
    try {
      final googlePlaces = await _mapDataService.searchNearbyPlaces(center: center, typeFilter: _currentFilter);
      if (mounted) {
        _googleLocations = googlePlaces;
        _updateMarkers(); // Google verisi gelince markerları yenile
      }
    } catch (e) {
      debugPrint("Google Places Hatası: $e");
    }
  }

  // --- Markerları Birleştirme ve Güncelleme ---
  void _updateMarkers() {
    if (!mounted) return;

    Set<Marker> newMarkers = {};

    // 1. Kullanıcı Konumu
    if (_userLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: _iconUser ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Konumun'),
          zIndex: 2,
        ),
      );
    }

    // 2. Arama Sonucu Markeri (Varsa)
    // Eğer arama yapılmış ve bir sonuç seçilmişse, o marker `_markers` setinde `s_` prefixi ile duruyordur.
    // Onu korumak için mevcut setten `s_` ile başlayanları alıp ekleyebiliriz veya 
    // `_onSearchResultSelected` içinde listeye ekleyip burada tekrar oluşturabiliriz.
    // Basitlik için burada sıfırdan oluşturuyoruz, arama sonucu logic'i aşağıda ayrıca ekleniyor.

    // 3. Firestore Mekanları (Öncelikli)
    for (var loc in _firestoreLocations) {
      newMarkers.add(Marker(
        markerId: MarkerId("fs_${loc.id}"),
        position: loc.position,
        icon: loc.icon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: loc.title, snippet: loc.snippet),
        onTap: () => _showLocationDetails(loc),
      ));
    }

    // 4. Google Places Mekanları (Çakışma Kontrolü ile)
    for (var loc in _googleLocations) {
      // Eğer aynı konumda veya çok yakınında Firestore verisi varsa, Google verisini ekleme (Firestore öncelikli)
      bool isDuplicate = _firestoreLocations.any((f) {
        // İsim benzerliği veya mesafe kontrolü
        double dist = _calculateDistance(f.position, loc.position);
        return dist < 0.05; // 50 metreye kadar yakınsa aynı say
      });

      if (!isDuplicate) {
        newMarkers.add(Marker(
          markerId: MarkerId("g_${loc.id}"),
          position: loc.position,
          icon: loc.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: loc.title),
          onTap: () => _showLocationDetails(loc),
        ));
      }
    }

    // 5. Arama Sonucu Markeri (Eğer varsa ve _markers içinde s_ ile başlıyorsa koru)
    final searchMarkers = _markers.where((m) => m.markerId.value.startsWith("s_"));
    newMarkers.addAll(searchMarkers);

    setState(() {
      _markers = newMarkers;
    });
  }

  // --- Yardımcı Fonksiyonlar ---
  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371.0; // Dünya yarıçapı (km)
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
    _isMapCreated = true;
    
    // Tema kontrolü
    if (Theme.of(context).brightness == Brightness.dark) {
      try {
        controller.setMapStyle(_darkMapStyle);
      } catch (e) {
        debugPrint("Map stili yüklenemedi: $e");
      }
    }

    if (widget.initialFocus != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(widget.initialFocus!, 16));
    }
  }

  // --- Arama İşlemleri ---
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

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _mapDataService.getPlacePredictions(query, _userLocation);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _onSearchResultSelected(String placeId) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _isLoading = true; // Yükleniyor göstergesi
    });
    _searchController.clear();

    final location = await _mapDataService.getPlaceDetails(placeId);
    
    if (location != null && mounted) {
      setState(() {
        _isLoading = false;
        // Önceki arama marker'larını temizle
        _markers.removeWhere((m) => m.markerId.value.startsWith("s_"));
        // Arama sonucunu marker olarak ekle (Diğerlerinden ayırt etmek için s_ prefixi)
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
        _showLocationDetails(location);
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konum detayları alınamadı.")));
      }
    }
  }

  // --- Rota Çizme ---
  Future<void> _drawRoute(LatLng destination) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konumunuz alınamadı.")));
      return;
    }
    
    Navigator.pop(context); // BottomSheet'i kapat
    setState(() => _isLoading = true);

    try {
      final points = await _mapDataService.getRouteCoordinates(_userLocation!, destination);
      
      if (points.isNotEmpty && mounted) {
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
        });

        // Rotayı ekrana sığdır
        LatLngBounds bounds = _boundsFromLatLngList(points);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rota bulunamadı.")));
      }
    } catch (e) {
      debugPrint("Rota hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    Navigator.pop(context); // Dialogu kapat
                    
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
      int mins = (km / 4.5 * 60).round(); // Ortalama 4.5 km/sa yürüme hızı
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
                              cacheManager: ImageCacheManager.instance,
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
        setState(() => _currentFilter = key);
        _loadPlaces(); // Filtre değişince verileri yeniden yükle
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
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Kendi butonumuzu kullanıyoruz
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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

          // 4. ALT AKSİYON BUTONLARI (Konum & Rota)
          Positioned(
            bottom: 30, right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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