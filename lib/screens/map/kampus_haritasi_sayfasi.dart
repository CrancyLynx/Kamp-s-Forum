import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, atan2, pi, sin; 
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
  final Completer<GoogleMapController> _controller = Completer();
  final MapDataService _mapDataService = MapDataService(); 
  
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(41.1065, 29.0229), 
    zoom: 13,
  );

  late Stream<List<LocationModel>> _firestoreStream;
  List<LocationModel> _googleApiLocations = [];
  Set<Polyline> _polylines = {}; 
  
  String _currentFilter = 'all';
  bool _isLoadingLocation = true;
  bool _isFetchingApi = false;
  bool _permissionGranted = false;
  bool _isRouting = false; 

  LatLng? _userLocation;

  // ARAMA DEĞİŞKENLERİ
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  final String _darkMapStyle = '''
    [
      {"elementType": "geometry","stylers": [{"color": "#212121"}]},
      {"elementType": "labels.icon","stylers": [{"visibility": "off"}]},
      {"elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
      {"elementType": "labels.text.stroke","stylers": [{"color": "#212121"}]},
      {"featureType": "administrative","elementType": "geometry","stylers": [{"color": "#757575"}]},
      {"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
      {"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#181818"}]},
      {"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2c2c2c"}]},
      {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#8a8a8a"}]},
      {"featureType": "water","elementType": "geometry","stylers": [{"color": "#000000"}]}
    ]
  ''';

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    
    _firestoreStream = _mapDataService.getLocationsStream(_currentFilter);

    _createCustomMarkers().then((_) {
      if (mounted) setState(() {});
      if (widget.initialFocus == null) {
        _getUserLocation();
      } else {
        setState(() => _isLoadingLocation = false);
        _fetchNearbyPlaces(widget.initialFocus!);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _mapDataService.getPlacePredictions(query, _userLocation);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = true;
        });
      }
    });
  }

  Future<void> _onResultSelected(String placeId) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
    });

    final location = await _mapDataService.getPlaceDetails(placeId);
    if (location != null) {
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location.position, 18));
      
      setState(() {
        _googleApiLocations = [location]; 
      });

      _showLocationDetails(location);
    }
  }

  Future<void> _drawRoute(LatLng destination) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konumunuz alınamadı.")));
      return;
    }

    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rota hesaplanıyor..."), duration: Duration(seconds: 1)));

    final coordinates = await _mapDataService.getRouteCoordinates(_userLocation!, destination);

    if (coordinates.isNotEmpty) {
      if (mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: coordinates,
              color: AppColors.primary,
              width: 5,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            )
          };
          _isRouting = true;
        });

        final controller = await _controller.future;
        LatLngBounds bounds = _boundsFromLatLngList(coordinates);
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rota bulunamadı.")));
    }
  }

  void _clearRoute() {
    setState(() {
      _polylines = {};
      _isRouting = false;
    });
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

  Future<void> _fetchNearbyPlaces(LatLng center) async {
    if (_isFetchingApi) return;
    if (mounted) setState(() => _isFetchingApi = true);

    try {
      final results = await _mapDataService.searchNearbyPlaces(
        center: center,
        typeFilter: _currentFilter,
      );
      if (mounted) {
        setState(() {
          _googleApiLocations = results;
          _isFetchingApi = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingApi = false);
    }
  }

  void _refreshLocations() {
    setState(() {
      _firestoreStream = _mapDataService.getLocationsStream(_currentFilter);
      _googleApiLocations = []; 
    });
    LatLng searchCenter = _userLocation ?? widget.initialFocus ?? _kDefaultLocation.target;
    _fetchNearbyPlaces(searchCenter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setMapStyle(); 
  }

  Future<void> _setMapStyle() async {
    final Brightness brightness = Theme.of(context).brightness;
    if (!_controller.isCompleted) return;
    final GoogleMapController controller = await _controller.future;
    if (brightness == Brightness.dark) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(null); 
    }
  }

  Future<BitmapDescriptor> _createMarkerImageFromIcon(IconData iconData, Color iconColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0; 
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(fontSize: size, fontFamily: iconData.fontFamily, color: iconColor, shadows: const [Shadow(color: Colors.black38, blurRadius: 5, offset: Offset(2, 2))]),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));
    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _createCustomMarkers() async {
    final iconUni = await _createMarkerImageFromIcon(Icons.school, Colors.red); 
    final iconYemek = await _createMarkerImageFromIcon(Icons.restaurant, Colors.orange); 
    final iconDurak = await _createMarkerImageFromIcon(Icons.directions_bus, Colors.blue); 
    final iconKutuphane = await _createMarkerImageFromIcon(Icons.menu_book, Colors.purple); 
    
    _mapDataService.setIcons(
      iconUni: iconUni,
      iconYemek: iconYemek,
      iconDurak: iconDurak,
      iconKutuphane: iconKutuphane,
    );
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

  Future<void> _getUserLocation() async {
    if(mounted) setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      Position position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10));
      _userLocation = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _isLoadingLocation = false;
        });
        
        if (widget.initialFocus == null) {
          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _userLocation!, zoom: widget.initialZoom)));
          _fetchNearbyPlaces(_userLocation!);
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Set<Marker> _buildCombinedMarkers(List<LocationModel> firestoreLocations) {
      final allMarkers = <Marker>{};
      
      for (var loc in firestoreLocations) {
        allMarkers.add(Marker(
            markerId: MarkerId("fs_${loc.id}"),
            position: loc.position,
            icon: loc.icon ?? BitmapDescriptor.defaultMarker,
            onTap: () => _showLocationDetails(loc),
            infoWindow: InfoWindow(title: loc.title),
        ));
      }

      for (var loc in _googleApiLocations) {
        bool existsInFirestore = firestoreLocations.any((f) => f.id == loc.id);
        if (!existsInFirestore) {
           allMarkers.add(Marker(
              markerId: MarkerId("g_${loc.id}"),
              position: loc.position,
              icon: loc.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              onTap: () => _showLocationDetails(loc),
              infoWindow: InfoWindow(title: loc.title),
           ));
        }
      }

      if (_userLocation != null) {
        allMarkers.add(Marker(
              markerId: const MarkerId('current_location'),
              position: _userLocation!,
              infoWindow: const InfoWindow(title: 'Siz Buradasınız', snippet: 'Yaklaşık Konum'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              zIndex: 2,
        ));
      }
      return allMarkers;
  }
  
  void _showLocationDetails(LocationModel location) {
    _controller.future.then((controller) {
      controller.animateCamera(CameraUpdate.newLatLng(location.position));
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLocationDetailsSheet(location),
    );
  }

  Widget _buildLocationDetailsSheet(LocationModel location) {
    final bool locationKnown = _userLocation != null;
    double distanceKm = locationKnown ? _calculateDistance(_userLocation!, location.position) : 0.0;
    int walkingTimeMinutes = locationKnown ? (distanceKm / 4.5 * 60).round() : 0;
    String distanceText = locationKnown ? "${distanceKm.toStringAsFixed(2)} km" : "Bilinmiyor";
    String timeText = locationKnown ? "~$walkingTimeMinutes dk" : "---";
    
    String displayTitle = location.title;
    if (location.type == 'durak' && !displayTitle.toLowerCase().contains('durak')) {
      displayTitle += " (Durak)";
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, 
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 200, 
                width: double.infinity,
                child: location.photoUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: location.photoUrls.length,
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: location.photoUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => Image.network("https://placehold.co/600x400/png?text=Fotograf+Yok", fit: BoxFit.cover),
                          );
                        },
                      )
                    : Image.network("https://placehold.co/600x400/png?text=Fotograf+Yok", fit: BoxFit.cover),
              ),
              Positioned(top: 15, right: 15, child: CircleAvatar(backgroundColor: Colors.black45, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))),
            ],
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 5),
                   Text(location.snippet, style: const TextStyle(color: Colors.grey)),
                   const SizedBox(height: 20),

                   Row(
                    children: [
                      _buildQuickInfoBox(icon: Icons.alt_route, value: distanceText, label: "Mesafe", color: AppColors.primary),
                      const SizedBox(width: 15),
                      _buildQuickInfoBox(icon: Icons.directions_walk, value: timeText, label: "Yürüyüş", color: Colors.green),
                      const SizedBox(width: 15),
                      _buildQuickInfoBox(icon: Icons.access_time, value: location.openingHours ?? "-", label: "Saatler", color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 25),

                  const Text("Şu an burası nasıl?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildVoteButton(location, "Sakin", Colors.green),
                      const SizedBox(width: 10),
                      _buildVoteButton(location, "Normal", Colors.orange),
                      const SizedBox(width: 10),
                      _buildVoteButton(location, "Kalabalık", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                             _mapDataService.addPhotoToLocation(location.id, "https://placehold.co/600x400/png?text=Yeni+Foto");
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklendi (Demo)!')));
                          },
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text("Foto Ekle"),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _drawRoute(location.position), 
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: const Text("Rota Çiz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => _launchDirections(location.position),
                      child: const Text("Google Haritalar'da Aç", style: TextStyle(color: Colors.grey)),
                    )
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoBox({required IconData icon, required String value, required String label, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(LocationModel loc, String status, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _mapDataService.voteForStatus(loc.id, status);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Durum '$status' olarak işaretlendi."), backgroundColor: color, duration: const Duration(seconds: 1)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
          child: Column(
            children: [
              Icon(Icons.thumb_up_alt_outlined, color: color, size: 16),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _launchDirections(LatLng destination) async {
    final String url = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=walking';
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harita açılamadı.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = widget.initialFocus ?? _kDefaultLocation.target;
    
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<List<LocationModel>>(
            stream: _firestoreStream,
            builder: (context, snapshot) {
              final firestoreLocations = snapshot.hasData ? snapshot.data! : <LocationModel>[];
              return GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(target: initialTarget, zoom: widget.initialZoom),
                markers: _buildCombinedMarkers(firestoreLocations),
                polylines: _polylines, 
                myLocationEnabled: _permissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (c) { if(!_controller.isCompleted) _controller.complete(c); _setMapStyle(); },
              );
            },
          ),
          
          if (_isFetchingApi)
            Positioned(
              top: 100, left: 0, right: 0, 
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)]),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text("Yükleniyor...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                          child: const Icon(Icons.arrow_back, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isRouting 
                        ? GestureDetector(
                            onTap: _clearRoute,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Rotayı Temizle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: "Mekan veya durak ara...",
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                suffixIcon: _searchController.text.isNotEmpty 
                                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _onSearchChanged(''); }) 
                                  : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                      ),
                    ],
                  ),
                ),

                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxHeight: 300), 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final mainText = item['structured_formatting']['main_text'] ?? item['description'];
                        final secondaryText = item['structured_formatting']['secondary_text'] ?? '';
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                          title: Text(mainText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: secondaryText.isNotEmpty ? Text(secondaryText, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          onTap: () => _onResultSelected(item['place_id']),
                        );
                      },
                    ),
                  ),

                if (!_isSearching && _searchResults.isEmpty && !_isRouting)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tümü', 'all', Icons.map),
                          _buildFilterChip('Üniversiteler', 'universite', Icons.school),
                          _buildFilterChip('Yemek', 'yemek', Icons.restaurant),
                          _buildFilterChip('Durak', 'durak', Icons.directions_bus),
                          _buildFilterChip('Kütüphane', 'kutuphane', Icons.menu_book),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            bottom: 30, right: 20,
            child: FloatingActionButton(
              heroTag: 'myloc',
              backgroundColor: AppColors.primary,
              child: _isLoadingLocation ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.my_location, color: Colors.white),
              onPressed: _getUserLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, IconData icon) {
    final bool isSelected = _currentFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filterKey;
          _refreshLocations(); 
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.black12, blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}