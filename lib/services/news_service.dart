import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_keys.dart';

class Article {
  final String title;
  final String? description;
  final String? urlToImage;
  final String url;
  final String sourceName;
  final String category; // Filtreleme için kategori bilgisi eklendi

  Article({
    required this.title,
    this.description,
    this.urlToImage,
    required this.url,
    required this.sourceName,
    this.category = 'general',
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? 'Başlık Yok',
      description: json['description'],
      urlToImage: json['urlToImage'],
      url: json['url'] ?? '',
      sourceName: (json['source'] as Map<String, dynamic>?)?['name'] ?? 'Kaynak',
    );
  }
}

class NewsService {
  // GÜNCELLEME: static const yerine getter kullanıyoruz.
  // Çünkü api_keys.dart artık runtime'da değer dönüyor.
  String get _apiKey => newsApiKey;
  
  final String _baseUrl = 'https://newsapi.org/v2/top-headlines';

  Future<List<Article>> fetchTopHeadlines({String? category}) async {
    // API Key yoksa veya limit dolduysa direkt mock veriye dön
    if (_apiKey.isEmpty || _apiKey.contains('API_KEY')) {
      return _getMockArticles(category);
    }

    final queryParameters = {
      'country': 'tr',
      'apiKey': _apiKey,
      if (category != null && category.isNotEmpty && category != 'general') 'category': category,
    };
    
    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> articlesJson = json['articles'] ?? [];
        if (articlesJson.isEmpty) return _getMockArticles(category);
        return articlesJson.map((article) => Article.fromJson(article)).toList();
      } else {
        debugPrint("API Hatası: ${response.statusCode} - Mock veriye geçiliyor.");
        return _getMockArticles(category);
      }
    } catch (e) {
      debugPrint("Bağlantı Hatası: $e - Mock veriye geçiliyor.");
      return _getMockArticles(category);
    }
  }

  // GÜNCELLENMİŞ GENİŞ MOCK VERİ HAVUZU
  List<Article> _getMockArticles(String? category) {
    final List<Article> allArticles = [
      // --- GENEL / GÜNDEM ---
      Article(
        title: "YÖK'ten Üniversiteler İçin Yeni Akademik Takvim Açıklaması",
        description: "Gelecek dönem akademik takvimi ve tatil süreleri hakkında yeni düzenlemeler duyuruldu.",
        urlToImage: "https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=600&q=80",
        url: "https://www.yok.gov.tr",
        sourceName: "Resmi Gazete",
        category: "general",
      ),
      Article(
        title: "KYK Burs ve Kredi Başvuruları Başladı: İşte Detaylar",
        description: "Gençlik ve Spor Bakanlığı, burs başvuru şartlarını ve tarihlerini yayınladı.",
        urlToImage: "https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600&q=80",
        url: "https://kygm.gsb.gov.tr/",
        sourceName: "Öğrenci İşleri",
        category: "general",
      ),
      Article(
        title: "Erasmus Hibelerine Zam Geldi: Öğrenciler İçin Büyük Fırsat",
        description: "Avrupa Birliği, öğrenci değişim programı hibelerinde artışa gitti.",
        urlToImage: "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600&q=80",
        url: "https://erasmus-plus.ec.europa.eu/tr",
        sourceName: "Global Eğitim",
        category: "general",
      ),

      // --- TEKNOLOJİ ---
      Article(
        title: "Yapay Zeka Mühendisliği Bölümleri Artıyor",
        description: "Üniversitelerde yapay zeka odaklı yeni lisans programları açılıyor.",
        urlToImage: "https://images.unsplash.com/photo-1677442136019-21780ecad995?w=600&q=80",
        url: "https://openai.com",
        sourceName: "TechCrunch",
        category: "technology",
      ),
      Article(
        title: "Kampüste Kodlama Maratonu: Hackathon 2025 Başlıyor",
        description: "48 saat sürecek dev kodlama yarışması için kayıtlar açıldı. Büyük ödül Silikon Vadisi gezisi.",
        urlToImage: "https://images.unsplash.com/photo-1504384308090-c54be3852f92?w=600&q=80",
        url: "https://github.com",
        sourceName: "DevNews",
        category: "technology",
      ),
      Article(
        title: "Yerli Teknoloji Devlerinden Staj Müjdesi",
        description: "Teknopark firmaları, mühendislik öğrencileri için 5000 kişilik staj kontenjanı ayırdı.",
        urlToImage: "https://images.unsplash.com/photo-1531482615713-2afd69097998?w=600&q=80",
        url: "https://teknofest.org",
        sourceName: "TeknoKariyer",
        category: "technology",
      ),

      // --- BİLİM ---
      Article(
        title: "Mars'ta Yaşam İzleri: Öğrenci Projesi NASA'nın Dikkatini Çekti",
        description: "Türk öğrencilerin geliştirdiği uzay tarım projesi ödül aldı.",
        urlToImage: "https://images.unsplash.com/photo-1614728853970-c8f1943d3e9e?w=600&q=80",
        url: "https://nasa.gov",
        sourceName: "Bilim Teknik",
        category: "science",
      ),
      Article(
        title: "Sürdürülebilir Enerji İçin Kampüslerde Güneş Paneli Dönemi",
        description: "Yeşil kampüs projesi kapsamında üniversiteler kendi elektriğini üretecek.",
        urlToImage: "https://images.unsplash.com/photo-1509391366360-2e959784a276?w=600&q=80",
        url: "https://www.tubitak.gov.tr",
        sourceName: "Yeşil Gelecek",
        category: "science",
      ),

      // --- EKONOMİ / BUSINESS ---
      Article(
        title: "Girişimci Öğrencilere Hibe Desteği: KOSGEB Duyurdu",
        description: "Kendi işini kurmak isteyen öğrencilere 100 bin TL hibe verilecek.",
        urlToImage: "https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&q=80",
        url: "https://www.kosgeb.gov.tr",
        sourceName: "Ekonomi Dünyası",
        category: "business",
      ),
      Article(
        title: "Finans Sektöründe Kariyer Günleri Başlıyor",
        description: "Bankalar ve finans kuruluşları kampüse geliyor. CV'nizi hazırlayın!",
        urlToImage: "https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=600&q=80",
        url: "#",
        sourceName: "Kariyer.net",
        category: "business",
      ),

      // --- KÜLTÜR / EĞLENCE ---
      Article(
        title: "Bahar Şenlikleri Takvimi Kesinleşti: Ünlü İsimler Geliyor",
        description: "Bu yıl şenliklerde sahne alacak sanatçılar ve etkinlik programı belli oldu.",
        urlToImage: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&q=80",
        url: "#",
        sourceName: "Kampüs Life",
        category: "entertainment",
      ),
      Article(
        title: "Üniversiteler Arası Tiyatro Festivali Perdelerini Açıyor",
        description: "Türkiye'nin dört bir yanından tiyatro kulüpleri yeteneklerini sergileyecek.",
        urlToImage: "https://images.unsplash.com/photo-1507676184212-d03ab07a11d0?w=600&q=80",
        url: "#",
        sourceName: "Sanat Kültür",
        category: "entertainment",
      ),

      // --- SAĞLIK ---
      Article(
        title: "Sınav Dönemi Stresiyle Başa Çıkma Yolları",
        description: "Uzman psikologlar, vize haftasında stresi azaltmak için 5 altın kuralı paylaştı.",
        urlToImage: "https://images.unsplash.com/photo-1505576399279-565b52d4ac71?w=600&q=80",
        url: "#",
        sourceName: "Sağlıklı Yaşam",
        category: "health",
      ),
      Article(
        title: "Kampüs Yemekhanelerinde Yeni Dönem: Vegan ve Vejetaryen Menüler",
        description: "Öğrenci talepleri üzerine yemekhane menüleri çeşitlendiriliyor.",
        urlToImage: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&q=80",
        url: "#",
        sourceName: "Beslenme Bülteni",
        category: "health",
      ),
    ];

    // Eğer "general" (Tümü/Gündem) seçiliyse, karma bir liste döndür (özellikle general etiketliler + popüler diğerleri)
    if (category == null || category == 'general') {
      // General olanları al + diğerlerinden random birkaç tane serpiştir
      final generalNews = allArticles.where((a) => a.category == 'general').toList();
      final otherNews = allArticles.where((a) => a.category != 'general').take(3).toList(); // Karışıklık olsun diye
      return [...generalNews, ...otherNews];
    }

    // Belirli bir kategori seçildiyse sadece onları filtrele
    final filtered = allArticles.where((article) => article.category == category).toList();
    
    // Eğer o kategoride hiç haber yoksa boş dönmemek için general'den ver
    return filtered.isNotEmpty ? filtered : allArticles.where((a) => a.category == 'general').toList();
  }
}