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

  // State Variables
  String _currentFilter = 'all';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _userLocation;
  bool _isLoading = false;
  bool _isRouteActive = false;

  // Veri Kaynakları (Hata Düzeltmesi İçin Ayrıldı)
  List<LocationModel> _firestoreLocations = [];
  List<LocationModel> _googleLocations = [];
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  // Harita Stili (Dark Mode için)
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
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);
    await _prepareCustomMarkers();
    await _getUserLocation();
    await _loadPlaces();
    setState(() => _isLoading = false);
  }

  // 1. İkonları Oluştur (Canvas ile yüksek kalite)
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
    
    // Arka plan dairesi
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
    
    // İkon
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

  // 2. Kullanıcı Konumu (Güvenli)
  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
        // Eğer focus noktası verilmemişse kullanıcıya git
        if (widget.initialFocus == null && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15));
        }
      }
    } catch (e) {
      debugPrint("Konum hatası: $e");
    }
  }

  // 3. Mekanları Getir ve Marker Oluştur (DÜZELTİLMİŞ YAPI)
  Future<void> _loadPlaces() async {
    // A) Firestore Mekanları (Dinleyerek)
    // Stream olduğu için veri geldikçe listeyi günceller ve markerları yeniden oluştururuz.
    _mapDataService.getLocationsStream(_currentFilter).listen((firestorePlaces) {
      if (mounted) {
        setState(() {
          _firestoreLocations = firestorePlaces;
        });
        _rebuildMarkers();
      }
    });

    // B) Google API Mekanları (Konum varsa tek seferlik çekilir)
    final center = _userLocation ?? widget.initialFocus ?? const LatLng(41.0082, 28.9784);
    final googlePlaces = await _mapDataService.searchNearbyPlaces(center: center, typeFilter: _currentFilter);
    
    if (mounted) {
      setState(() {
        _googleLocations = googlePlaces;
      });
      _rebuildMarkers();
    }
  }

  // DÜZELTME: Tek bir Marker Oluşturma Fonksiyonu
  // İki listeyi birleştirip tek seferde haritaya basar, hatayı ve flicker'ı önler.
  void _rebuildMarkers() {
    Set<Marker> newMarkers = {};

    // 1. Firestore Markerları
    for (var loc in _firestoreLocations) {
      newMarkers.add(Marker(
        markerId: MarkerId("fs_${loc.id}"),
        position: loc.position,
        icon: loc.icon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: loc.title),
        onTap: () => _showLocationDetails(loc),
      ));
    }

    // 2. Google API Markerları
    for (var loc in _googleLocations) {
      // Eğer Firestore'da aynı isimde mekan varsa Google'dan gelenini ekleme (Duplicate önleme)
      bool exists = _firestoreLocations.any((f) => f.title == loc.title);
      if (!exists) {
        newMarkers.add(Marker(
          markerId: MarkerId("g_${loc.id}"),
          position: loc.position,
          icon: loc.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onTap: () => _showLocationDetails(loc),
        ));
      }
    }

    if (mounted) setState(() => _markers = newMarkers);
  }

  // 4. Harita Oluştuğunda
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Tema Kontrolü
    if (Theme.of(context).brightness == Brightness.dark) {
      controller.setMapStyle(_darkMapStyle);
    }

    // İlk animasyon
    if (widget.initialFocus != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(widget.initialFocus!, 16));
    }
  }

  // --- MESAFE HESAPLAMA ---
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

  // --- ARAMA İŞLEMLERİ ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _searchResults = []);
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
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location.position, 17));
      _showLocationDetails(location);
      
      // Arama sonucunu marker olarak ekle
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

  // --- ROTA İŞLEMİ ---
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

  // --- DETAY PENCERESİ ---
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
                              imageUrl: location.photoUrls[i],
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(color: Colors.grey[200]),
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
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_userLocation != null) ...[
                              _buildInfoBadge(Icons.straighten, distanceText, AppColors.primary),
                              _buildInfoBadge(Icons.directions_walk, timeText, Colors.blue),
                            ],
                            if (location.rating > 0) 
                              _buildInfoBadge(Icons.star, "${location.rating}", Colors.amber),
                            if (location.openingHours != null)
                              _buildInfoBadge(Icons.access_time, location.openingHours!, Colors.green),
                          ],
                        ),
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
                                 _mapDataService.addPhotoToLocation(location.id, "https://placehold.co/600x400/png?text=Yeni+Foto");
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklendi!')));
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
                            onPressed: () {
                                final url = 'https://www.google.com/maps/search/?api=1&query=${location.position.latitude},${location.position.longitude}';
                                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

          // 2. ARAMA VE FİLTRE BAR (Yüzen)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arama Çubuğu
                  Container(
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
                  
                  // Arama Sonuçları (Autocomplete)
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
                      Text("Yükleniyor...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // 4. KONUM & ROTA BUTONLARI
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
                  heroTag: 'myLoc',
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () {
                    if (_userLocation != null && _mapController != null) {
                      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 16));
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