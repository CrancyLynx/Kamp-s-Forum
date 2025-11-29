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
  // MapDataService instance'ı korunur
  final MapDataService _mapDataService = MapDataService(); 
  
  // Varsayılan Kampüs Merkezi (ITÜ Ayazağa, İstanbul)
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(41.1065, 29.0229), 
    zoom: 13,
  );

  Set<Marker> _markers = {};
  String _currentFilter = 'all';
  bool _isLoadingLocation = true;
  bool _permissionGranted = false;
  LatLng? _userLocation;
  
  List<LocationModel> _allLocationModels = [];
  
  // KARANLIK TEMA HARİTA STİLİ (Kod korunur)
  final String _darkMapStyle = '''
    [
      {"elementType": "geometry","stylers": [{"color": "#212121"}]},
      {"elementType": "labels.icon","stylers": [{"visibility": "off"}]},
      {"elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
      {"elementType": "labels.text.stroke","stylers": [{"color": "#212121"}]},
      {"featureType": "administrative","elementType": "geometry","stylers": [{"color": "#757575"}]},
      {"featureType": "administrative.country","elementType": "labels.text.fill","stylers": [{"color": "#9e9e9e"}]},
      {"featureType": "administrative.land_parcel","stylers": [{"visibility": "off"}]},
      {"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#bdbdbd"}]},
      {"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
      {"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#181818"}]},
      {"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#616161"}]},
      {"featureType": "poi.park","elementType": "labels.text.stroke","stylers": [{"color": "#1b1b1b"}]},
      {"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2c2c2c"}]},
      {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#8a8a8a"}]},
      {"featureType": "road.arterial","elementType": "geometry","stylers": [{"color": "#373737"}]},
      {"featureType": "road.highway","elementType": "geometry","stylers": [{"color": "#3c3c3c"}]},
      {"featureType": "road.highway.controlled_access","elementType": "geometry","stylers": [{"color": "#4e4e4e"}]},
      {"featureType": "road.local","elementType": "labels.text.fill","stylers": [{"color": "#616161"}]},
      {"featureType": "transit","elementType": "labels.text.fill","stylers": [{"color": "#757575"}]},
      {"featureType": "water","elementType": "geometry","stylers": [{"color": "#000000"}]},
      {"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#3d3d3d"}]}
    ]
  ''';


  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    // 1. İkonları oluştur ve servise ata
    _createCustomMarkers().then((_) {
      // 2. Konumu almayı dene, başarısız olursa varsayılan merkeze (İstanbul) odaklan
      _getUserLocation(initialLoad: true); 
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


  // --- Yardımcı İkon Oluşturucu (Korunur) ---
  Future<BitmapDescriptor> _createMarkerImageFromIcon(IconData iconData, Color iconColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0; 

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size, 
        fontFamily: iconData.fontFamily,
        color: iconColor,
        shadows: const [Shadow(color: Colors.black38, blurRadius: 5, offset: Offset(2, 2))],
      ),
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
    if(mounted) setState(() {}); 
  }

  // --- MESAFA HESAPLAMA (Korunur) ---
  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371.0; 
    
    double degToRad(double deg) => deg * (pi / 180);

    double lat1Rad = degToRad(p1.latitude);
    double lon1Rad = degToRad(p1.longitude);
    double lat2Rad = degToRad(p2.latitude);
    double lon2Rad = degToRad(p2.longitude);

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; 
  }
  
  // --- YÖNLENDİRME (Korunur) ---
  Future<void> _launchDirections(LatLng destination) async {
    final String destinationLat = destination.latitude.toString();
    final String destinationLng = destination.longitude.toString();
    
    String url;
    
    if (_userLocation != null) {
      final String startLat = _userLocation!.latitude.toString();
      final String startLng = _userLocation!.longitude.toString();
      url = 'comgooglemaps://?saddr=$startLat,$startLng&daddr=$destinationLat,$destinationLng&dirflg=w';
    } else {
      url = 'comgooglemaps://?q=$destinationLat,$destinationLng';
    }

    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      String fallbackUrl = 'http://maps.google.com/maps?daddr=$destinationLat,$destinationLng';
      if (_userLocation != null) {
        fallbackUrl += '&saddr=${_userLocation!.latitude},${_userLocation!.longitude}';
      }
       final Uri fallbackUri = Uri.parse(fallbackUrl);
       if(await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
       } else {
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Haritalar uygulaması veya web sitesi açılamadı.'), backgroundColor: AppColors.error)
           );
         }
       }
    }
  }

  // --- Konum Bulma Mantığı (Korunur) ---
  Future<void> _getUserLocation({bool initialLoad = false}) async {
    if(mounted) setState(() => _isLoadingLocation = true);
    // ... (İzin kontrolü ve konum alma mantığı korunur)
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fallbackToDefault();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _fallbackToDefault();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _fallbackToDefault();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      
      _userLocation = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _isLoadingLocation = false;
        });
      }

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _userLocation!, zoom: widget.initialZoom),
      ));

      // Konum bulunduğunda, merkez kullanıcı konumu olur.
      _generateNearbyPlaces(_userLocation!);

    } catch (e) {
      debugPrint("Mevcut konum alınamadı: $e");
      _fallbackToDefault();
    }
  }
  
  // KRİTİK DÜZELTME: Konum bulunamazsa doğru başlangıç noktasına odaklanmayı garanti eder.
  void _fallbackToDefault() {
    if (mounted) {
      // initialFocus varsa onu kullan, yoksa varsayılan kampüs merkezini kullan.
      final center = widget.initialFocus ?? _kDefaultLocation.target;
      
      setState(() {
        _isLoadingLocation = false;
        _permissionGranted = false;
      });
      
      _generateNearbyPlaces(center);
      
      // Harita controller hazırsa yeni konuma odaklan.
      _controller.future.then((controller) {
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: widget.initialZoom),
        ));
      });
    }
  }

  // --- Konumları Üretme ve Markerları Güncelleme ---
  void _generateNearbyPlaces(LatLng center) {
    // Servisten konumları çekerken filtrelemeyi uyguluyor.
    final List<LocationModel> locations = _mapDataService.generateLocations(
      center: center,
      currentFilter: _currentFilter,
    );
    
    _updateMarkers(locations);
  }

  void _updateMarkers(List<LocationModel> locations) {
    setState(() {
      _allLocationModels = locations;
      final newMarkers = <Marker>{};
      
      for (var loc in locations) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(loc.id),
            position: loc.position,
            icon: loc.icon ?? BitmapDescriptor.defaultMarker,
            infoWindow: const InfoWindow(title: '', snippet: ''), 
            onTap: () => _showLocationDetails(loc),
          ),
        );
      }
      
      // Kullanıcı konumu markeri
      if (_userLocation != null) {
        newMarkers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _userLocation!,
              infoWindow: const InfoWindow(title: 'Siz Buradasınız', snippet: 'Yaklaşık Konum'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              onTap: () {},
            ),
          );
      }
      _markers = newMarkers;
    });
  }
  
  // --- HARİTA DETAY SAYFASI (BOTTOM SHEET) (Korunur) ---
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
  
  // Bottom Sheet içeriği (Korunur)
  Widget _buildLocationDetailsSheet(LocationModel location) {
    final bool locationKnown = _userLocation != null;
    double distanceKm = locationKnown ? _calculateDistance(_userLocation!, location.position) : 0.0;
    int walkingTimeMinutes = locationKnown ? (distanceKm / 4.5 * 60).round() : 0;
    
    String distanceText = locationKnown ? "${distanceKm.toStringAsFixed(2)} km" : "Konumunuz Bilinmiyor";
    String timeText = locationKnown ? "~$walkingTimeMinutes dk" : "Hesaplanamıyor";
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, 
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fotoğraf Alanı
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 50, color: AppColors.primary),
                  Text(location.title, style: TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
          ),

          // Başlık ve Kapatma Butonu
          Padding(
            padding: const EdgeInsets.only(top: 15, left: 20, right: 10, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(location.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Detaylar
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mesafe ve Süre
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Row(
                      children: [
                        _buildQuickInfoBox(
                          icon: Icons.alt_route, 
                          value: distanceText, 
                          label: "Tahmini Düz Mesafe", 
                          color: AppColors.primary
                        ),
                        const SizedBox(width: 15),
                        _buildQuickInfoBox(
                          icon: Icons.directions_walk, 
                          value: timeText, 
                          label: "Tahmini Yürüyüş Süresi", 
                          color: Colors.green
                        ),
                      ],
                    ),
                  ),

                  _buildDetailRow(
                    label: "Kategori",
                    value: location.type.toUpperCase(),
                    icon: _getIconForType(location.type),
                    color: AppColors.primary,
                  ),
                  _buildDetailRow(
                    label: "Açıklama",
                    value: location.snippet,
                    icon: Icons.info_outline,
                    color: Colors.grey,
                  ),
                  _buildDetailRow(
                    label: "Çalışma Saatleri",
                    value: location.openingHours ?? "Bilinmiyor",
                    icon: Icons.access_time,
                    color: Colors.green,
                  ),
                  _buildDetailRow(
                    label: "Canlı Durum",
                    value: location.liveStatus ?? "Normal",
                    icon: Icons.person_pin_circle,
                    color: location.liveStatus == 'Yoğun' ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 20),
                  
                  // Yol Tarifi Butonu
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchDirections(location.position);
                      },
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text("Yol Tarifi Al (Google Haritalar)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
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

  Widget _buildDetailRow({required String label, required String value, required IconData icon, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickInfoBox({required IconData icon, required String value, required String label, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 5),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  
  IconData _getIconForType(String type) {
    switch (type) {
      case 'yemek': return Icons.restaurant;
      case 'durak': return Icons.directions_bus;
      case 'kutuphane': return Icons.menu_book;
      case 'universite': return Icons.school;
      default: return Icons.place;
    }
  }


  @override
  Widget build(BuildContext context) {
    final LatLng initialTarget = widget.initialFocus ?? _kDefaultLocation.target;
    
    final CameraPosition initialCameraPosition = CameraPosition(
      target: initialTarget,
      zoom: widget.initialZoom,
    );
    
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: initialCameraPosition,
            markers: _markers,
            myLocationEnabled: _permissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _setMapStyle(); 
              
              if (widget.initialFocus == null && _userLocation == null) {
                  _getUserLocation();
              } else {
                  _generateNearbyPlaces(initialTarget);
              }
            },
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
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: _isLoadingLocation 
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.white),
              onPressed: () {
                _getUserLocation();
              },
            ),
          ),
          if (_userLocation != null || widget.initialFocus != null)
            Positioned(
              bottom: 30,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Text(
                  _userLocation != null ? "Yakınındaki yerler" : "Odaklanılan Merkez", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)
                ),
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
          
          LatLng target = _userLocation ?? widget.initialFocus ?? _kDefaultLocation.target;
          double zoom = widget.initialZoom;
          
          if (filterKey == 'universite') {
             target = const LatLng(41.0082, 28.9784); 
             zoom = 10;
          }
          
          _controller.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)));
          _generateNearbyPlaces(target);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.black12,
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}