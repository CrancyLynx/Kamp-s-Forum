import 'package:flutter_dotenv/flutter_dotenv.dart';

// BU DOSYAYI GİT'E EKLEYEBİLİRSİNİZ, ÇÜNKÜ ARTIK ŞİFRE İÇERMİYOR.
// Anahtarlar .env dosyasından çekiliyor.

// Getter kullanarak uygulama çalıştığında güncel değerin çekilmesini sağlıyoruz.
String get newsApiKey => dotenv.env['NEWS_API_KEY'] ?? '';
String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';