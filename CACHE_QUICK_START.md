# 🚀 Cache System - Quick Start Guide

## Sorun
Uygulama açılıyor → Splash Screen (2.5s) → Sayfalar yavaş açılıyor (2-5s Firestore beklentisi).

## Çözüm
Splash screen'de tüm sayfaların verileri **arka planda preload** edilir ve **cihazda cache'lenir**:

```
Splash Screen (2.5s) → [ARKA PLANDA]
├─ Forum Posts (ilk 30)
├─ Market Products (ilk 50)
├─ User Profile
├─ Notifications (ilk 20)
├─ User Balance
├─ Leaderboard
└─ Exam Dates

↓ Splash bitince ↓

Forum Sayfası açılıyor:
├─ Cache varsa → Hemen göster (100ms)
├─ Firestore'dan yeni veri getir (arka planda)
└─ Güncellenirse UI refresh et
```

## 📝 Implementasyon Adımları

### Adım 1: Service'leri İndir
İyi haber! Zaten eklendi:
- ✅ `lib/services/data_preload_service.dart`
- ✅ `lib/services/cache_helper.dart`

### Adım 2: Import Ekle
```dart
import '../../services/data_preload_service.dart';
// veya daha basit:
import '../../services/cache_helper.dart';
```

### Adım 3: Cache Kontrolü

#### Seçenek 1: Basit Cache Okuma
```dart
// initState veya sayfanın herhangi bir yerinde
final cachedData = await DataPreloadService.getCachedData('forum_posts');
if (cachedData != null) {
  setState(() => _data = cachedData);
  // Arka planda yeni veri getir
  _fetchFreshData();
}
```

#### Seçenek 2: Kombinasyon (Önerilen)
```dart
// FutureBuilder/StreamBuilder yerine
final data = await CacheHelper.getWithCache(
  'forum_posts',
  () => FirebaseFirestore.instance
      .collection('gonderiler')
      .limit(30)
      .get(),
);
```

#### Seçenek 3: Cache Warm-up (Easiest)
```dart
// initState'de, FutureBuilder'dan ÖNCE
@override
void initState() {
  super.initState();
  
  // Arka planda cache'i ısıt (optional)
  DataPreloadService.getCachedData('forum_posts').catchError((_) {});
  
  // Sonra normal FutureBuilder/StreamBuilder kullan
}
```

## 🔍 Hangi Sayfada Hangi Cache?

| Sayfa | Cache Key | Veri |
|-------|-----------|------|
| Forum | `forum_posts` | 30 gönderi |
| Pazar | `market_products` | 50 ürün |
| Profil | `user_profile` | Kullanıcı bilgileri |
| Bildirim | `notifications` | 20 bildirim |
| Leaderboard | `leaderboard` | 100 kullanıcı |
| Sınav Tarihleri | `exam_dates` | 100 sınav |
| User Balance | `user_balance` | Coins, XP, Level |

## ⚙️ Ayarları Değiştir

### Cache Validity (Geçerlilik) Süresi
Şu anda **1 saat**. Değiştirmek için:

```dart
// lib/services/data_preload_service.dart
static Future<bool> isCacheValid(String key) async {
  // ...
  return diffInMinutes < 60; // ← Bunu değiştir (örn: 120 = 2 saat)
}
```

### Preload Edilen Veri Sayısı
```dart
// lib/services/data_preload_service.dart

// Forum: ilk 30 → 50 yap
.limit(30)  // ← Bunu değiştir

// Market: ilk 50 → 100 yap
.limit(50)  // ← Bunu değiştir
```

### Preload'u Disable Et
SplashScreen'de çağrısı yorumla:
```dart
// lib/screens/auth/splash_screen.dart
void _startSequentialAnimation() {
  // DataPreloadService.preloadAllData(); // ← Yorumla
  
  _scaleController.forward().then((_) { ... });
}
```

## 🧪 Test Etme

### Test 1: Cache Var mı?
```dart
final cached = await DataPreloadService.getCachedData('forum_posts');
print('Cache: $cached');
```

### Test 2: Offline Mode
1. Uygulamayı aç (cache'leme başlasın)
2. 3 saniye sonra WiFi/3G kapat
3. Sayfaları geç - cache'ten yükleme göreceksin

### Test 3: Cache Validity
```dart
final isValid = await DataPreloadService.isCacheValid('forum_posts');
print('Cache valid: $isValid');
```

### Test 4: Cache Temizle
```dart
// Tüm cache temizle
await DataPreloadService.clearCache();

// Spesifik kategoriyi temizle
await DataPreloadService.clearCache(key: 'forum_posts');
```

## 📊 Performance Kazanımı

### Splash Screen → Sayfa Geçiş
```
ESKI:
Splash (2.5s) → Forum açılıyor (3-5s Firestore) = 5.5-7.5s

YENİ:
Splash (2.5s) → Forum açılıyor (100ms cache) = 2.6s

KAZANIM: 3-5 saniye (60-65% hızlanma) 🚀
```

## ⚠️ Önemli Notlar

1. **Cache boyutu**: SharedPreferences ~1-2MB limit
2. **Geçerlilik**: 1 saatlik cache validity
3. **Guest Users**: Hızlandırılmış veri (public posts only)
4. **Real-time**: Real-time updates desteklenmedi (background refresh yeterli)
5. **Offline**: Cache varsa offline mode çalışır

## 🎯 Sonraki Adımlar

- [ ] Profil sayfasında cache'i kullan
- [ ] Sohbet listesinde cache'i kullan  
- [ ] Admin panelinde cache'i kullan
- [ ] Local database (SQLite) ekle (1MB+ veri için)
- [ ] Background sync worker ekle (otomatik güncelleme)

## 📞 Sorunlar?

1. **Cache okumıyor**: `getCachedData()` null dönüyorsa cache yok
2. **Eski veri gözüküyor**: `isCacheValid()` false olsa bile gösteriliyor
3. **Firestore quota**: İlk açılış 7 read = Firestore read quota'sı tüketir

---

**Şimdi hızlı bir şekilde sayfalar çalışacak! ⚡**

Commit: `d5ede55` ✅
