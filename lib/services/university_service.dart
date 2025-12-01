import 'dart:convert';
import 'package:flutter/services.dart';

class UniversityService {
  static final UniversityService _instance = UniversityService._internal();
  factory UniversityService() => _instance;
  UniversityService._internal();

  List<Map<String, dynamic>> _universities = [];

  Future<void> loadData() async {
    if (_universities.isNotEmpty) return;

    try {
      final String response = await rootBundle.loadString('assets/json/universities.json');
      final List<dynamic> data = json.decode(response);
      
      _universities = data.map((e) => {
        "name": e['name'].toString(),
        "departments": List<String>.from(e['departments'] ?? [])
      }).toList();
    } catch (e) {
      print("Hata: Üniversite verisi yüklenemedi -> $e");
    }
  }

  List<String> getUniversityNames() {
    return _universities.map((e) => e['name'] as String).toList();
  }

  List<String> getDepartmentsForUniversity(String uniName) {
    final uni = _universities.firstWhere(
      (e) => e['name'] == uniName, 
      orElse: () => {"name": "", "departments": []}
    );
    return uni['departments'] as List<String>;
  }
}