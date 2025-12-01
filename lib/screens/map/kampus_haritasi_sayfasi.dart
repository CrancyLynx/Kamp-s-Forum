import 'dart:async';
import 'dart:math' show cos, sqrt, atan2, pi, sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/map_data_service.dart';
import '../../utils/app_colors.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../services/image_cache_manager.dart'; // YENİ: Merkezi önbellek yöneticisi
import '../../utils/maskot_helper.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  // Controller
  GoogleMapController? _mapController;
  final MapDataService _mapDataService = MapDataService();
  StreamSubscription? _firestoreSubscription; // YENİ: Stream aboneliğini yönetmek için

  // State Variables
  String _currentFilter = 'all';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _userLocation;
  bool _isLoading = false;
  bool _isRouteActive = false;

  // Veri Kaynakları
  List<LocationModel> _firestoreLocations = [];
  List<LocationModel> _googleLocations = [];
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  // Global Key'ler
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _filterChipKey = GlobalKey();
  final GlobalKey _myLocationButtonKey = GlobalKey();

  // Harita Stili
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
  void dispose() {
    _firestoreSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    await _prepareCustomMarkers();
    final bool hasPermission = await _getUserLocation();

    // Sadece konum izni varsa yerleri yükle ve tanıtımı göster.
    if (hasPermission) {
      await _loadPlaces();
      _showTutorial(); // Tanıtımı göster.
    }

    setState(() => _isLoading = false);
  }

  // 1. İkonları Oluştur
  Future<void> _prepareCustomMarkers() async {
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
  }

  Future<BitmapDescriptor> _createMarkerBitmap(IconData icon, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const size = Size(100, 100);
    
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
    
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontSize: 60, fontFamily: icon.fontFamily, color: Colors.white),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));

    final img = await pictureRecorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // 2. Kullanıcı Konumu
  Future<bool> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) { // mounted kontrolü önemli
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
        if (widget.initialFocus == null && _mapController != null) {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 16));
        }
      }
      return true; // İzin alındı ve konum mevcut.
    } catch (e) {
      debugPrint("Konum hatası: $e");
      return false; // Hata durumunda false dön.
    }
  }

  // Tanıtımı gösteren fonksiyon
  void _showTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Widget ağaçtan kaldırıldıysa işlem yapma.
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

  // 3. Mekanları Getir
  Future<void> _loadPlaces() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Önceki stream aboneliğini iptal et
    await _firestoreSubscription?.cancel();

    final center = _userLocation ?? widget.initialFocus ?? const LatLng(41.0082, 28.9784);

    // Firestore stream'ini dinlemeye başla
    _firestoreSubscription = _mapDataService.getLocationsStream(_currentFilter).listen((firestorePlaces) {
      if (!mounted) return;
      _firestoreLocations = firestorePlaces;
      _rebuildMarkers(); // Firestore'dan her yeni veri geldiğinde marker'ları güncelle
    });

    // Google Places verisini tek seferde çek
    _googleLocations = await _mapDataService.searchNearbyPlaces(center: center, typeFilter: _currentFilter);

    // Tüm işlemler bittikten sonra state'i güncelle
    if (!mounted) return;
    setState(() => _isLoading = false);
    _rebuildMarkers(); // Google verisi de geldikten sonra marker'ları son kez güncelle
  }

  void _rebuildMarkers() {
    Set<Marker> newMarkers = {};
    if (_userLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Konumun'),
        ),
      );
    }

    for (var loc in _firestoreLocations) {
      newMarkers.add(Marker(
        markerId: MarkerId("fs_${loc.id}"),
        position: loc.position,
        icon: loc.icon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: loc.title),
        onTap: () => _showLocationDetails(loc),
      ));
    }

    for (var loc in _googleLocations) {
      bool isDuplicate = _firestoreLocations.any((f) => f.title == loc.title && _calculateDistance(f.position, loc.position) < 0.1);
      if (!isDuplicate) {
        newMarkers.add(Marker(
          markerId: MarkerId("g_${loc.id}"),
          position: loc.position,
          icon: loc.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onTap: () => _showLocationDetails(loc),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  // 4. Harita Oluştuğunda
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (Theme.of(context).brightness == Brightness.dark) {
      controller.setMapStyle(_darkMapStyle);
    }
    if (widget.initialFocus != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(widget.initialFocus!, 16));
    }
  }

  // Mesare
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

  // Arama
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) setState(() => _searchResults = []);
        return;
      }
      final results = await _mapDataService.getPlacePredictions(query, _userLocation);
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _onSearchResultSelected(String placeId) async {
    FocusScope.of(context).unfocus();
    setState(() => _searchResults = []);
    _searchController.clear();

    final location = await _mapDataService.getPlaceDetails(placeId);
    if (location != null && _mapController != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location.position, 17));
      _showLocationDetails(location);
      
      setState(() {
        _markers.add(Marker(
          markerId: MarkerId("s_${location.id}"),
          position: location.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
          onTap: () => _showLocationDetails(location),
        ));
      });
    }
  }

  // Rota
  Future<void> _drawRoute(LatLng destination) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konumunuz alınamadı.")));
      return;
    }
    
    Navigator.pop(context);
    setState(() => _isLoading = true);

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
        _isLoading = false;
      });

      LatLngBounds bounds = _boundsFromLatLngList(points);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rota bulunamadı.")));
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

  // --- YENİ: YORUM WIDGET'LARI ---

  void _showAddReviewDialog(LocationModel location) {
    double _rating = 3.0;
    final _commentController = TextEditingController();

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
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () => setDialogState(() => _rating = index + 1.0),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentController,
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
                    final comment = _commentController.text.trim();
                    if (comment.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum boş bırakılamaz.")));
                      return;
                    }
                    Navigator.pop(context); // Yorum gönderme dialogunu kapat
                    final error = await _mapDataService.addReview(location.id, _rating, comment);
                    if (!mounted) return;
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yorum eklenirken hata oluştu: $error"), backgroundColor: AppColors.error));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Değerlendirmeniz için teşekkürler! Yorumunuz eklendi."), backgroundColor: AppColors.success));
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

  void _showReviewsSheet(LocationModel location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("${location.title} Yorumları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Expanded(
                  child: StreamBuilder<List<ReviewModel>>(
                    stream: _mapDataService.getReviewsStream(location.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Yorumlar yüklenirken bir hata oluştu: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("Henüz yorum yapılmamış."));
                      }
                      final reviews = snapshot.data!;
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: reviews.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (c, i) => _buildReviewTile(reviews[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTile(ReviewModel review) {
    final timeStr = timeago.format(review.timestamp.toDate(), locale: 'tr');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: (review.userAvatar != null && review.userAvatar!.isNotEmpty)
                ? CachedNetworkImageProvider(
                    review.userAvatar!,
                    cacheManager: ImageCacheManager.instance,
                  )
                : null,
            child: (review.userAvatar == null || review.userAvatar!.isEmpty)
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(children: List.generate(5, (index) => Icon(index < review.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                const SizedBox(height: 4),
                Text(review.comment, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8))),
                const SizedBox(height: 4),
                Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Detay Penceresi
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
                              cacheManager: ImageCacheManager.instance, // YENİ: Merkezi önbellek yöneticisi kullanılıyor.
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
                          // YENİ: Uygulama içi puanlama
                          if (location.reviewCount > 0)
                            _buildInfoBadge(Icons.star, "${location.firestoreRating.toStringAsFixed(1)} (${location.reviewCount})", Colors.purple),
                          if (location.rating > 0) 
                            _buildInfoBadge(Icons.public, "Google: ${location.rating}", Colors.amber),
                          if (location.openingHours != null)
                            _buildInfoBadge(Icons.access_time, location.openingHours!, Colors.green),
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
                              onPressed: () {
                                 // TODO: Gerçek fotoğraf ekleme işlevi eklenecek.
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf ekleme özelliği yakında gelecek!')));
                              },
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text("Foto Ekle"),
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
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Harita uygulaması açılamadı.")),
                                    );
                                  }
                                }
                            },
                            icon: const Icon(Icons.map),
                            tooltip: "Google Maps",
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

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Oylandı: $text"), duration: const Duration(seconds: 1)));
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
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. ARAMA VE FİLTRE BAR
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
                              setState(() => _searchResults = []);
                            },
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  
                  // Arama Sonuçları
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

          // 3. YÜKLENİYOR
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
                      Text("Yükleniyor...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // 4. KONUM & ROTA
          Positioned(
            bottom: 30, right: 20,
            child: Column(
              children: [
                if (_isRouteActive)
                  FloatingActionButton.small(
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
                const SizedBox(height: 12),
                FloatingActionButton(
                  key: _myLocationButtonKey, 
                  heroTag: 'myLoc',
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () {
                    if (_userLocation != null) {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 16));
                    } else {
                      _getUserLocation();
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

  Widget _buildFilterChip(String label, String key, IconData icon) {
    final isSelected = _currentFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _currentFilter = key);
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
}