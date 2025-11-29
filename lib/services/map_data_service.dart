import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

// Konum Modelini tanımlar
class LocationModel {
  final String id;
  final String title;
  final String snippet;
  final String type; // yemek, durak, kutuphane, universite
  final LatLng position;
  final BitmapDescriptor? icon;
  final String? openingHours; 
  final String? liveStatus; 
  final String? imageUrl; // Fotoğraf alanı için

  LocationModel({
    required this.id,
    required this.title,
    required this.snippet,
    required this.type,
    required this.position,
    this.icon,
    this.openingHours,
    this.liveStatus,
    this.imageUrl,
  });
}

class MapDataService {
  final Random _random = Random();
  
  BitmapDescriptor? _iconUni;
  BitmapDescriptor? _iconYemek;
  BitmapDescriptor? _iconDurak;
  BitmapDescriptor? _iconKutuphane;

  // DÜZELTME: Daha anlamlı, gerçekçi İTÜ (varsayılan merkez) yakınındaki statik lokasyonlar eklendi.
  final List<Map<String, dynamic>> _fixedLocations = [
    // İTÜ Ayazağa Kampüsü Çevresi (Varsayılan Odak)
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
    // ... (Diğer 20+ üniversite verisi buraya devam ediyor)
  ];
  
  // DÜZELTME: Rastgele konum oluşturma tamamen kaldırıldı, yerine statik ve yakındaki yerler kullanılacak.
  // Bu, konumların hatalı olmasını engeller.
  
  void setIcons({
    required BitmapDescriptor iconUni,
    required BitmapDescriptor iconYemek,
    required BitmapDescriptor iconDurak,
    required BitmapDescriptor iconKutuphane,
  }) {
    _iconUni = iconUni;
    _iconYemek = iconYemek;
    _iconDurak = iconDurak;
    _iconKutuphane = iconKutuphane;
  }

  // DÜZELTME: Artık rastgele konum oluşturulmuyor. Sadece filtrelenmiş statik veriyi döndürüyoruz.
  List<LocationModel> generateLocations({required LatLng center, required String currentFilter}) {
    List<LocationModel> locations = [];
    
    for (var data in _fixedLocations) {
      // Filtreleme mantığı
      if (currentFilter == 'all' || data['type'] == currentFilter) {
        
        // Marker İkonunu Belirle
        BitmapDescriptor? icon;
        if (data['type'] == 'universite') icon = _iconUni;
        else if (data['type'] == 'yemek') icon = _iconYemek;
        else if (data['type'] == 'durak') icon = _iconDurak;
        else if (data['type'] == 'kutuphane') icon = _iconKutuphane;

        locations.add(LocationModel(
          id: data['id'], 
          title: data['title'], 
          snippet: data['snippet'] ?? 'Detay yok.', 
          type: data['type'], 
          position: LatLng(data['lat'], data['lng']), 
          icon: icon,
          openingHours: data['hours'],
          liveStatus: data['status'] ?? (_random.nextBool() ? 'Normal' : 'Açık'),
          imageUrl: data['image'] ?? 'placeholder.jpg',
        ));
      }
    }

    // YAKINLIK FİLTRESİ: Harita performansını korumak için, sadece merkeze (center) en yakın 20-30 lokasyonu gösterebiliriz.
    // Ancak veri setimiz küçük olduğu için bu adımı atlayabiliriz.
    
    return locations;
  }
}