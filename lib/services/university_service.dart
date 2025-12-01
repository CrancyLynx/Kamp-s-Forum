import 'dart:convert';
import 'package:flutter/services.dart';

class UniversityService {
  // Singleton yapısı
  static final UniversityService _instance = UniversityService._internal();
  factory UniversityService() => _instance;
  UniversityService._internal();

  List<Map<String, dynamic>> _universities = [];

  // Uygulama açılınca veya ekran yüklenince çağrılmalı
  Future<void> loadData() async {
    // Veri zaten yüklüyse tekrar yükleme
    if (_universities.isNotEmpty) return;

    try {
      final String response = await rootBundle.loadString('assets/json/universities.json');
      final List<dynamic> data = json.decode(response);
      
      _universities = data.map((e) => {
        "name": e['name'].toString(),
        // Listeyi güvenli bir şekilde String listesine çeviriyoruz
        "departments": (e['departments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[]
      }).toList();
      
      print("✅ Üniversite verisi yüklendi: ${_universities.length} adet.");
    } catch (e) {
      print("❌ HATA: Üniversite verisi okunamadı: $e");
    }
  }

  // Tüm üniversite isimlerini getir
  List<String> getUniversityNames() {
    return _universities.map((e) => e['name'] as String).toList();
  }

  // Seçilen üniversiteye göre bölümleri getir
  List<String> getDepartmentsForUniversity(String uniName) {
    try {
      // DÜZELTME: orElse null değil, boş bir Map döndürmeli.
      final uni = _universities.firstWhere(
        (e) => e['name'].toString().toLowerCase() == uniName.toLowerCase(),
        orElse: () => {"name": "", "departments": <String>[]}, 
      );

      // uni artık null olamaz, ancak departments içeriğini kontrol ediyoruz.
      final departments = uni['departments'];
      if (departments == null) return [];

      // Listeyi güvenli bir şekilde al ve sırala
      List<String> depts = List<String>.from(departments);
      depts.sort();
      return depts;
    } catch (e) {
      print("Bölüm getirme hatası: $e");
      return [];
    }
  }
}