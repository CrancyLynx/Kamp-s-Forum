import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, atan2, pi, sin; 

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

  // HATA DÜZELTMESİ: late Stream'i initState'de hemen tanımlayacağız.
  late Stream<List<LocationModel>> _locationsStream;
  String _currentFilter = 'all';
  bool _isLoadingLocation = true;
  bool _permissionGranted = false;
  LatLng? _userLocation;

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
    
    // HATA ÇÖZÜMÜ: Stream'i initState içinde beklemeden başlatıyoruz.
    _locationsStream = _mapDataService.getLocationsStream(_currentFilter);

    // Veritabanı boşsa doldur
    _mapDataService.seedDatabaseIfEmpty();

    // Marker ikonlarını oluştur
    _createCustomMarkers().then((_) {
      if (mounted) setState(() {}); // İkonlar yüklenince yenile
      
      if (widget.initialFocus == null) {
        _getUserLocation();
      } else {
        setState(() => _isLoadingLocation = false);
      }
    });
  }

  void _refreshLocationsStream() {
    setState(() {
      _locationsStream = _mapDataService.getLocationsStream(_currentFilter);
    });
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
      if (!serviceEnabled) { throw Exception('Servis kapalı'); }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('İzin reddedildi');
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
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Set<Marker> _buildMarkersFromData(List<LocationModel> locations) {
      final newMarkers = <Marker>{};
      for (var loc in locations) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(loc.id),
            position: loc.position,
            icon: loc.icon ?? BitmapDescriptor.defaultMarker,
            onTap: () => _showLocationDetails(loc),
          ),
        );
      }
      if (_userLocation != null) {
        newMarkers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _userLocation!,
              infoWindow: const InfoWindow(title: 'Siz Buradasınız', snippet: 'Yaklaşık Konum'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              zIndex: 2,
            ),
          );
      }
      return newMarkers;
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

  // --- GÜNCELLENEN DETAY PANELİ (Galeri + Oylama) ---
  Widget _buildLocationDetailsSheet(LocationModel location) {
    final bool locationKnown = _userLocation != null;
    double distanceKm = locationKnown ? _calculateDistance(_userLocation!, location.position) : 0.0;
    int walkingTimeMinutes = locationKnown ? (distanceKm / 4.5 * 60).round() : 0;
    String distanceText = locationKnown ? "${distanceKm.toStringAsFixed(2)} km" : "Bilinmiyor";
    String timeText = locationKnown ? "~$walkingTimeMinutes dk" : "---";
    
    final PageController pageController = PageController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, 
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Fotoğraf Galerisi (PageView)
          Stack(
            children: [
              SizedBox(
                height: 200, 
                width: double.infinity,
                child: location.photoUrls.isNotEmpty
                    ? PageView.builder(
                        controller: pageController,
                        itemCount: location.photoUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showFullScreenImage(context, location.photoUrls, index),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
                              child: Image.network(
                                location.photoUrls[index], 
                                fit: BoxFit.cover, 
                                errorBuilder: (c,e,s) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 50))
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
                        ),
                        child: Center(child: Icon(Icons.image_outlined, size: 50, color: AppColors.primary)),
                      ),
              ),
              
              // Kapat Butonu
              Positioned(
                top: 15, 
                right: 15, 
                child: CircleAvatar(
                  backgroundColor: Colors.black45, 
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                )
              ),

              // Sayfa Göstergesi (Dots)
              if (location.photoUrls.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(location.photoUrls.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.8)),
                    );
                  }),
                ),
              ),
            ],
          ),
          
          // 2. İçerik ve Oylama
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Expanded(child: Text(location.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                         decoration: BoxDecoration(color: _getStatusColor(location.liveStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _getStatusColor(location.liveStatus))),
                         child: Text(location.liveStatus ?? "Normal", style: TextStyle(color: _getStatusColor(location.liveStatus), fontWeight: FontWeight.bold)),
                       ),
                     ],
                   ),
                   const SizedBox(height: 20),

                  Row(
                    children: [
                      _buildQuickInfoBox(icon: Icons.alt_route, value: distanceText, label: "Mesafe", color: AppColors.primary),
                      const SizedBox(width: 15),
                      _buildQuickInfoBox(icon: Icons.directions_walk, value: timeText, label: "Yürüyüş", color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildDetailRow(label: "Kategori", value: location.type.toUpperCase(), icon: _mapDataService.getIconForType(location.type) != null ? Icons.place : Icons.info, color: AppColors.primary),
                  _buildDetailRow(label: "Açıklama", value: location.snippet, icon: Icons.info_outline, color: Colors.grey),
                  _buildDetailRow(label: "Çalışma Saatleri", value: location.openingHours ?? "Bilinmiyor", icon: Icons.access_time, color: Colors.green),
                  
                  const Divider(height: 30),
                  
                  // OYLAMA ALANI
                  const Text("Sizce şu an burası nasıl?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  const SizedBox(height: 20),
                  
                  // AKSİYON BUTONLARI
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                             _mapDataService.addPhotoToLocation(location.id, "https://picsum.photos/800/600?random=${DateTime.now().millisecondsSinceEpoch}");
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf yüklendi!')));
                          },
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text("Foto Ekle"),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _launchDirections(location.position);
                          },
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: const Text("Yol Tarifi Al", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                    ],
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

  void _showFullScreenImage(BuildContext context, List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: photos.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) {
                return InteractiveViewer(child: Image.network(photos[index], fit: BoxFit.contain));
              },
            ),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Sakin': return Colors.green;
      case 'Yoğun': case 'Kalabalık': return Colors.red;
      default: return Colors.orange;
    }
  }

  Widget _buildDetailRow({required String label, required String value, required IconData icon, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          )),
        ],
      ),
    );
  }
  
  Widget _buildQuickInfoBox({required IconData icon, required String value, required String label, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 5), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))]),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  
  Future<void> _launchDirections(LatLng destination) async {
    final String destinationLat = destination.latitude.toString();
    final String destinationLng = destination.longitude.toString();
    String url = 'comgooglemaps://?daddr=$destinationLat,$destinationLng';
    if (_userLocation != null) {
      url += '&saddr=${_userLocation!.latitude},${_userLocation!.longitude}';
    }
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
       await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = widget.initialFocus ?? _kDefaultLocation.target;
    
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<List<LocationModel>>(
            stream: _locationsStream,
            builder: (context, snapshot) {
              final locations = snapshot.hasData ? snapshot.data! : _mapDataService.getFallbackLocations(_currentFilter);
              
              return GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(target: initialTarget, zoom: widget.initialZoom),
                markers: _buildMarkersFromData(locations),
                myLocationEnabled: _permissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (c) { if(!_controller.isCompleted) _controller.complete(c); _setMapStyle(); },
              );
            },
          ),
          
          // ÜST BAR (Filtreler)
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
              ],
            ),
          ),

          // KONUM BUTONU
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'myloc',
              backgroundColor: AppColors.primary,
              child: _isLoadingLocation ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.my_location, color: Colors.white),
              onPressed: _getUserLocation,
            ),
          ),
          if (_userLocation != null || widget.initialFocus != null)
            Positioned(
              bottom: 30,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Text(_userLocation != null ? "Konumunuz Alındı" : "Odaklanılan Merkez", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
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
          _refreshLocationsStream();
          LatLng target = _userLocation ?? widget.initialFocus ?? _kDefaultLocation.target;
          double zoom = widget.initialZoom;
          if (filterKey == 'universite') { target = const LatLng(41.0082, 28.9784); zoom = 10; }
          _controller.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)));
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