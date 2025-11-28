import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// Düzeltilmiş Importlar
import '../../utils/app_colors.dart';


class KampusHaritasiSayfasi extends StatefulWidget {
  final String initialFilter;

  const KampusHaritasiSayfasi({super.key, this.initialFilter = 'all'});

  @override
  State<KampusHaritasiSayfasi> createState() => _KampusHaritasiSayfasiState();
}

class _KampusHaritasiSayfasiState extends State<KampusHaritasiSayfasi> {
  final Completer<GoogleMapController> _controller = Completer();
  
  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 13,
  );

  Set<Marker> _markers = {};
  String _currentFilter = 'all';
  bool _isLoadingLocation = true;
  bool _permissionGranted = false;
  LatLng? _userLocation;

  BitmapDescriptor? _iconUni;
  BitmapDescriptor? _iconYemek;
  BitmapDescriptor? _iconDurak;
  BitmapDescriptor? _iconKutuphane;

  final List<Map<String, dynamic>> _universities = [
    {'id': 'vak_u25', 'title': 'İstanbul Galata Üniversitesi', 'lat': 41.0286, 'lng': 28.9744}, // Şişhane Kampüsü
    {'id': 'vak_u1', 'title': 'Koç Üniversitesi', 'lat': 41.2049, 'lng': 29.0718},
    {'id': 'vak_u2', 'title': 'Sabancı Üniversitesi', 'lat': 40.8912, 'lng': 29.3787},
    {'id': 'vak_u3', 'title': 'İstanbul Bilgi Üniversitesi (Santral)', 'lat': 41.0664, 'lng': 28.9458},
    {'id': 'vak_u4', 'title': 'Bahçeşehir Üniversitesi (Beşiktaş)', 'lat': 41.0423, 'lng': 29.0095},
    {'id': 'vak_u5', 'title': 'Yeditepe Üniversitesi', 'lat': 40.9739, 'lng': 29.1517},
    {'id': 'vak_u6', 'title': 'İstanbul Aydın Üniversitesi', 'lat': 40.9930, 'lng': 28.7989},
    {'id': 'vak_u7', 'title': 'İstanbul Medipol Üniversitesi (Kavacık)', 'lat': 41.0927, 'lng': 29.0935},
    {'id': 'vak_u8', 'title': 'Özyeğin Üniversitesi', 'lat': 41.0347, 'lng': 29.2618},
    {'id': 'vak_u9', 'title': 'Kadir Has Üniversitesi', 'lat': 41.0253, 'lng': 28.9592},
    {'id': 'vak_u10', 'title': 'Acıbadem Üniversitesi', 'lat': 40.9764, 'lng': 29.1086},
    {'id': 'vak_u11', 'title': 'Beykent Üniversitesi', 'lat': 41.1090, 'lng': 29.0060},
    {'id': 'vak_u12', 'title': 'Haliç Üniversitesi', 'lat': 41.0663, 'lng': 28.9472},
    {'id': 'vak_u13', 'title': 'Üsküdar Üniversitesi', 'lat': 41.0247, 'lng': 29.0353},
    {'id': 'vak_u14', 'title': 'Piri Reis Üniversitesi', 'lat': 40.8936, 'lng': 29.3033},
    {'id': 'vak_u15', 'title': 'İstanbul Ticaret Üniversitesi', 'lat': 41.0633, 'lng': 28.9511},
    {'id': 'vak_u16', 'title': 'MEF Üniversitesi', 'lat': 41.1077, 'lng': 29.0232},
    {'id': 'vak_u17', 'title': 'Bezmiâlem Vakıf Üniversitesi', 'lat': 41.0186, 'lng': 28.9392},
    {'id': 'vak_u18', 'title': 'Fatih Sultan Mehmet Vakıf Üni.', 'lat': 41.0644, 'lng': 28.9497},
    {'id': 'vak_u19', 'title': 'İstanbul Sabahattin Zaim Üni.', 'lat': 41.0294, 'lng': 28.7917},
    {'id': 'vak_u20', 'title': 'Maltepe Üniversitesi', 'lat': 40.9572, 'lng': 29.2089},
    {'id': 'vak_u21', 'title': 'Doğuş Üniversitesi (Dudullu)', 'lat': 41.0003, 'lng': 29.1561},
    {'id': 'vak_u22', 'title': 'Işık Üniversitesi (Şile)', 'lat': 41.1714, 'lng': 29.5622},
    {'id': 'vak_u23', 'title': 'Altınbaş Üniversitesi', 'lat': 41.0635, 'lng': 28.8239},
    {'id': 'vak_u24', 'title': 'İstanbul Gelişim Üniversitesi', 'lat': 40.9936, 'lng': 28.7061},

    // DEVLET ÜNİVERSİTELERİ
    {'id': 'ist_u1', 'title': 'İstanbul Üniversitesi (Beyazıt)', 'lat': 41.0130, 'lng': 28.9636},
    {'id': 'ist_u2', 'title': 'İstanbul Teknik Üniversitesi (Ayazağa)', 'lat': 41.1065, 'lng': 29.0229},
    {'id': 'ist_u3', 'title': 'Boğaziçi Üniversitesi (Güney)', 'lat': 41.0833, 'lng': 29.0503},
    {'id': 'ist_u4', 'title': 'Yıldız Teknik Üniversitesi (Davutpaşa)', 'lat': 41.0522, 'lng': 28.8927},
    {'id': 'ist_u5', 'title': 'Marmara Üniversitesi (Göztepe)', 'lat': 40.9877, 'lng': 29.0528},
    {'id': 'ist_u6', 'title': 'Mimar Sinan Güzel Sanatlar Üni.', 'lat': 41.0312, 'lng': 28.9902},
    {'id': 'ist_u7', 'title': 'Türk-Alman Üniversitesi', 'lat': 41.1394, 'lng': 29.0833},
    {'id': 'ist_u8', 'title': 'İstanbul Medeniyet Üniversitesi', 'lat': 40.9990, 'lng': 29.0622},
    {'id': 'ist_u9', 'title': 'Galatasaray Üniversitesi', 'lat': 41.0475, 'lng': 29.0222},
    {'id': 'ist_u10', 'title': 'Sağlık Bilimleri Üniversitesi', 'lat': 41.0053, 'lng': 29.0225},
    {'id': 'ist_u11', 'title': 'İstanbul Cerrahpaşa Üniversitesi', 'lat': 40.9922, 'lng': 28.7303},
    // ANKARA
    {'id': 'ank1', 'title': 'ODTÜ (METU)', 'lat': 39.8914, 'lng': 32.7760},
    {'id': 'ank2', 'title': 'Bilkent Üniversitesi', 'lat': 39.8687, 'lng': 32.7483},
    {'id': 'ank3', 'title': 'Hacettepe Üniversitesi (Beytepe)', 'lat': 39.8656, 'lng': 32.7339},
    {'id': 'ank4', 'title': 'Ankara Üniversitesi', 'lat': 39.9366, 'lng': 32.8303},
    {'id': 'ank5', 'title': 'Gazi Üniversitesi', 'lat': 39.9372, 'lng': 32.8229},

    // İZMİR
    {'id': 'izm1', 'title': 'Ege Üniversitesi', 'lat': 38.4595, 'lng': 27.2275},
    {'id': 'izm2', 'title': 'Dokuz Eylül Üniversitesi', 'lat': 38.3707, 'lng': 27.2023},
    {'id': 'izm3', 'title': 'İzmir Yüksek Teknoloji Enstitüsü', 'lat': 38.3236, 'lng': 26.6366},

    // DİĞER ŞEHİRLER
    {'id': 'ant1', 'title': 'Akdeniz Üniversitesi (Antalya)', 'lat': 36.8970, 'lng': 30.6483},
    {'id': 'esk1', 'title': 'Anadolu Üniversitesi (Eskişehir)', 'lat': 39.7915, 'lng': 30.5009},
    {'id': 'bur1', 'title': 'Uludağ Üniversitesi (Bursa)', 'lat': 40.2234, 'lng': 28.8727},
    {'id': 'kon1', 'title': 'Selçuk Üniversitesi (Konya)', 'lat': 38.0254, 'lng': 32.5108},
    {'id': 'tra1', 'title': 'Karadeniz Teknik Üniversitesi (Trabzon)', 'lat': 40.9950, 'lng': 39.7717},
    {'id': 'erz1', 'title': 'Atatürk Üniversitesi (Erzurum)', 'lat': 39.9022, 'lng': 41.2425},
    {'id': 'gaz1', 'title': 'Gaziantep Üniversitesi', 'lat': 37.0346, 'lng': 37.3367},
    {'id': 'kay1', 'title': 'Erciyes Üniversitesi (Kayseri)', 'lat': 38.7077, 'lng': 35.5262},
    {'id': 'sak1', 'title': 'Sakarya Üniversitesi', 'lat': 40.7431, 'lng': 30.3323},
    {'id': 'koc1', 'title': 'Kocaeli Üniversitesi', 'lat': 40.8225, 'lng': 29.9213},
    {'id': 'can1', 'title': 'Çanakkale Onsekiz Mart Üniversitesi', 'lat': 40.1177, 'lng': 26.4109},
  ];

  List<Map<String, dynamic>> _nearbyLocations = [];

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _createCustomMarkers().then((_) {
      _getUserLocation();
    });
  }

  // --- SADE İKON OLUŞTURUCU (Arka plansız, sadece sembol) ---
  Future<void> _createCustomMarkers() async {
    _iconUni = await _createMarkerImageFromIcon(Icons.school, Colors.red); 
    _iconYemek = await _createMarkerImageFromIcon(Icons.restaurant, Colors.orange); 
    _iconDurak = await _createMarkerImageFromIcon(Icons.directions_bus, Colors.blue); 
    _iconKutuphane = await _createMarkerImageFromIcon(Icons.menu_book, Colors.purple); 
    if(mounted) setState(() {}); 
  }

  Future<BitmapDescriptor> _createMarkerImageFromIcon(IconData iconData, Color iconColor) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0; // Biraz küçülttük

    // Sadece ikonu çiziyoruz, daire yok.
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size, // İkon tüm alanı kaplasın
        fontFamily: iconData.fontFamily,
        color: iconColor,
        // Hafif gölge ekleyelim ki haritada görünsün
        shadows: [Shadow(color: Colors.black38, blurRadius: 5, offset: Offset(2, 2))],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Servis kapalıysa varsayılanı göster
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
      // Timeout süresini kısalttık ve hata yönetimini iyileştirdik
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Hız için medium
        timeLimit: const Duration(seconds: 5), 
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
        CameraPosition(target: _userLocation!, zoom: 15),
      ));

      _generateNearbyPlaces(_userLocation!);

    } catch (e) {
      _fallbackToDefault();
    }
  }

  void _fallbackToDefault() {
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
        _permissionGranted = false;
      });
      _generateNearbyPlaces(_kDefaultLocation.target);
    }
  }

  void _generateNearbyPlaces(LatLng center) {
    _nearbyLocations.clear();
    final random = Random();

    LatLng createRandomLocation(double lat, double lng, double radius) {
      double r = radius / 111300; 
      double u = random.nextDouble();
      double v = random.nextDouble();
      double w = r * sqrt(u);
      double t = 2 * pi * v;
      return LatLng(lat + (w * cos(t)), lng + (w * sin(t)));
    }

    for (int i = 0; i < 4; i++) {
      LatLng loc = createRandomLocation(center.latitude, center.longitude, 600);
      _nearbyLocations.add({
        'id': 'y_$i', 'title': 'Yemek Noktası ${i+1}', 'snippet': 'Menü: ${30 + random.nextInt(50)} TL', 'type': 'yemek', 'lat': loc.latitude, 'lng': loc.longitude, 'icon': _iconYemek,
      });
    }
    for (int i = 0; i < 3; i++) {
      LatLng loc = createRandomLocation(center.latitude, center.longitude, 500);
      _nearbyLocations.add({
        'id': 'd_$i', 'title': 'Durak ${i+1}', 'snippet': '${random.nextInt(5) + 1} hat geçiyor', 'type': 'durak', 'lat': loc.latitude, 'lng': loc.longitude, 'icon': _iconDurak,
      });
    }
    for (int i = 0; i < 2; i++) {
      LatLng loc = createRandomLocation(center.latitude, center.longitude, 800);
      _nearbyLocations.add({
        'id': 'k_$i', 'title': 'Kütüphane Şubesi', 'snippet': 'Doluluk: %${random.nextInt(80) + 10}', 'type': 'kutuphane', 'lat': loc.latitude, 'lng': loc.longitude, 'icon': _iconKutuphane,
      });
    }
    for (var uni in _universities) {
      _nearbyLocations.add({
        'id': uni['id'], 'title': uni['title'], 'snippet': 'Kampüs', 'type': 'universite', 'lat': uni['lat'], 'lng': uni['lng'], 'icon': _iconUni,
      });
    }
    _updateMarkers();
  }

  void _updateMarkers() {
    setState(() {
      _markers = _nearbyLocations
          .where((loc) => _currentFilter == 'all' || loc['type'] == _currentFilter)
          .map((loc) {
        return Marker(
          markerId: MarkerId(loc['id']),
          position: LatLng(loc['lat'], loc['lng']),
          infoWindow: InfoWindow(title: loc['title'], snippet: loc['snippet']),
          icon: loc['icon'] ?? BitmapDescriptor.defaultMarker,
        );
      }).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kDefaultLocation,
            markers: _markers,
            myLocationEnabled: _permissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
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
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
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
                setState(() => _isLoadingLocation = true);
                _getUserLocation();
              },
            ),
          ),
          if (_userLocation != null)
            Positioned(
              bottom: 30,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: const Text("Yakınındaki yerler", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
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
          _updateMarkers();
          
          if (filterKey == 'universite') {
             _controller.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(41.0082, 28.9784), 10)));
          } else if (_userLocation != null) {
             _controller.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15)));
          }
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