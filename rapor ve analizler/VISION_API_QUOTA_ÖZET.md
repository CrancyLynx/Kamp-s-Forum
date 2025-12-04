# VISION API QUOTA SİSTEMİ - ÖZET

**Tarih:** 4 Aralık 2025  
**Status:** ✅ TAMAMLANDI

---

## 🎯 NE YAPTİK?

Para bitmişken Vision API'yi otomatik olarak kapatacak sistem ekledik.

### Öncesi (Problem)
```
❌ 1000 quota doldurulunca sistem çöküyor
❌ Kullanıcılara kötü hata mesajı gösteriyor
❌ Admin farkında değil quota bitti
❌ Beklenmedik ödeme riski
```

### Sonrası (Çözüm)
```
✅ Quota doldurulunca sistem otomatik kontrol ediyor
✅ Para yoksa resim yükleme durdurulur
✅ Admin kolayca kontrol edebiliyor
✅ 3 farklı fallback stratejisi seçebiliyor
```

---

## 🔧 EKLENEN SİSTEM

### 1. Quota Kontrol Fonksiyonları

```javascript
// Quota'yı oku
getVisionApiQuotaUsage()

// Kullanabilir mi kontrol et
canUseVisionApi()

// API çağrısını artır
incrementVisionApiQuota()
```

### 2. Admin Komutları

```javascript
// Quota durumu kontrol et
getVisionApiQuotaStatus()

// API aç/kapat
setVisionApiEnabled({enabled: boolean})

// Fallback stratejisi değiştir (deny/allow/warn)
setVisionApiFallbackStrategy({strategy: "deny"})

// Quota sıfırla (acil durum)
resetVisionApiQuota()
```

### 3. Firestore Koleksiyonu

```
vision_api_quota/{monthKey}
  ├─ monthKey: "2025_12"
  ├─ usageCount: 847
  └─ lastUpdated: Timestamp
```

---

## 📊 MALIYET KONTROL

### Aylık Tahsis

```
Free Quota: 1000 istek/ay
Sonrası: $3.50 / 1000 istek
Dönem: Takvim ayına göre (1-30)
```

### Kullanım Özeti

| Senaryo | Maliyet | Durum |
|---------|---------|-------|
| İlk 1000 | 🆓 ÜCRETSİZ | OK |
| 1000+ | 💰 PARA GEREKLİ | ⚠️ Bloklanır |
| Quota dolu | 🚫 SISTEM KAPALI | Admin kontrol |

---

## 🎮 ADMIN KULLANIM

### Senaryo 1: Normal Durum

```
1. Admin olarak gir
2. getVisionApiQuotaStatus() kontrol et
3. Message: "✅ Quota OK: 847/1000 kaldı"
4. Hiçbir şey yapma (otomatik çalışıyor)
```

### Senaryo 2: Quota Dindi

```
1. Mesaj: "🚨 QUOTA FULL: 1000 istek kullanıldı"
2. Para yok ise:
   setVisionApiEnabled({enabled: false})
3. Sistem kapanır, resim yükleme durdurulur
```

### Senaryo 3: Para Vardı Yükselt

```
1. Google Cloud Billing'den ödeme yap
2. resetVisionApiQuota() çağır (isteğe bağlı)
3. setVisionApiEnabled({enabled: true})
4. Sistem yeniden açılır
```

---

## 📋 DOSYALAR

### Eklenen Fonksiyonlar (index.js)

```javascript
// Quota yönetimi
getVisionApiQuotaUsage()
canUseVisionApi()
incrementVisionApiQuota()

// Admin komutları
exports.getVisionApiQuotaStatus
exports.setVisionApiEnabled
exports.setVisionApiFallbackStrategy
exports.resetVisionApiQuota
```

### Belgeler

```
📄 VISION_API_MALIYET_ANALİZİ.md
   → Detaylı maliyet hesabı

📄 VISION_API_QUOTA_YÖNETİMİ.md
   → Admin kılavuzu + örnekler

📄 VISION_API_QUOTA_TEST.md
   → Test senaryoları + debug yardımı
```

---

## ⚙️ AYARLAR

### index.js'te

```javascript
const VISION_API_CONFIG = {
  MONTHLY_FREE_QUOTA: 1000,    // Aylık limit
  ENABLED: true,               // Açık/kapalı
  FALLBACK_STRATEGY: "deny"    // deny/allow/warn
};
```

### Değiştirilmesi Gereken Kısımlar

#### 1. Admin Functions Bağlama
```javascript
// index.js'in sonunda var:
exports.getVisionApiQuotaStatus = ...
exports.setVisionApiEnabled = ...
// ✅ Otomatik Firebase'de görülecek
```

#### 2. Firestore Rules (Firestore Security Rules)
```javascript
// vision_api_quota koleksiyonuna read izni
match /vision_api_quota/{document=**} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}
```

#### 3. İsteğe Bağlı: Aylık Quota Limiti Değiştir
```javascript
// Para varsa 2000 yapmak istersen:
MONTHLY_FREE_QUOTA: 2000  // ← Burası
```

---

## 🔄 İŞLEYİŞ AKIŞI

```
KULLANICI RESIM YÜKLÜYOR
        ↓
moderateUploadedImage Trigger
        ↓
checkImageSafety(imagePath)
        ↓
canUseVisionApi() KONTROL
        ↓
    ┌───┴───┐
    │       │
  EVET    HAYIR
    │       │
    ↓       ↓
  API   Fallback
 ÇAĞRI  Strategy
    │       │
    ↓       ↓
Quota   "deny" → ❌ Reddet
Artır   "allow"→ ✅ İzin ver
    │       │
    ↓       ↓
Sonuç Kullanıcıya Göster
```

---

## ⏰ AYLIK KONTROL TAKVIMI

### 1 Aralık - 31 Aralık

```
┌─────────────────────────────────┐
│ 1 Aralık (günü başında)         │
│ → getVisionApiQuotaStatus()     │
│   (Kontrol et, rapor al)        │
│                                 │
│ 15 Aralık (ortasında)           │
│ → Tekrar kontrol               │
│   (Eğer 500+ ise uyar)         │
│                                 │
│ 25 Aralık (sonunda)             │
│ → Final kontrol                │
│   (Eğer 900+ ise karar al)     │
│                                 │
│ 1 Ocak (ayın başında)           │
│ → Otomatik sıfırlanır          │
│ (Yeni ay = yeni 1000)          │
└─────────────────────────────────┘
```

---

## 🛡️ KORUNMA MEKANIZMLARI

### 1. Otomatik Sayaç
```
✅ Her API çağrısında +1 artır
✅ Firestore'da kaydedilir
✅ Ay sonunda sıfırlanır
```

### 2. Quota Kontrol
```
✅ API çağrısından ÖNCE kontrol et
✅ Kaldı mı kontrol et
✅ Aşıldıysa fallback yap
```

### 3. Fallback Stratejiler
```
deny   → Sistem kapalı, resim yüklenemiyor
allow  → Sistem açık, resim yüklenir ama kontrol yok
warn   → Uyarı göster ama yükleme devam et
```

### 4. Admin Kontrol
```
✅ Sadece admin değiştirebilir
✅ Log kaydı tutulur (updateBy)
✅ Firestore'da geçmiş saklanır
```

---

## 💾 FIRESTORE VERI YAPISI

### vision_api_quota koleksiyonu

```
koleksiyon: vision_api_quota
│
└─ döküman: "2025_12"
   ├─ monthKey: "2025_12"
   ├─ usageCount: 847
   └─ lastUpdated: Timestamp(2025-12-04 14:32:00)
```

Otomatik Yönetim:
- ✅ İlk resim yükleme: Döküman otomatik oluşur
- ✅ Her çağrı: usageCount +1 artır
- ✅ Ayın başında: Otomatik sıfırlanır

---

## 🚀 DEPLOYMENT

### Adım 1: Code Push
```
git add functions/index.js
git commit -m "Add Vision API quota control"
git push
```

### Adım 2: Deploy
```
firebase deploy --only functions
```

### Adım 3: Verify
```
1. Firestore console aç
2. vision_api_quota koleksiyonunu gör
3. Test et: getVisionApiQuotaStatus()
4. Bir resim yükle
5. usageCount artmış mı kontrol et
```

---

## ⚠️ ÖNEMLİ NOTLAR

### Para Bittiyse Ne Yapacak?

```javascript
// Seçenek 1: Sistem kapanacak (fail-safe)
setVisionApiEnabled({enabled: false})
// → Resim yükleme reddedilir

// Seçenek 2: Kontrol atlanacak (risk)
setVisionApiFallbackStrategy({strategy: "allow"})
// → Resim yüklenir ama kontrol yok

// Seçenek 3: Uyarı gösterecek
setVisionApiFallbackStrategy({strategy: "warn"})
// → Uyarı ama yükleme devam eder
```

### Hangisini Seçmeli?
- 🏠 **Başlangıçta:** `deny` (para yok, güvenli ol)
- 📱 **Büyüdüğü zaman:** `allow` (hizmet kesme)
- ⚠️ **Alternatif:** `warn` (bildir ama yükle)

---

## 📞 İLETİŞİM

### Logs Nereden Bakılır?

```
Firebase Console
├─ Functions
│  ├─ moderateUploadedImage (resim upload trigger)
│  ├─ analyzeImageBeforeUpload (ön kontrol)
│  └─ Logs sekmesi
│     └─ Search: [QUOTA] veya [VISION]
```

### Beklenen Log Mesajları

```
✅ [QUOTA_OK] Kalan quota: 847/1000
❌ [QUOTA_EXCEEDED] Aylık quota tükendi!
⚠️ [VISION_DISABLED] Vision API global olarak devre dışı
📊 [ANALYZING] Resim analiz ediliyor: gs://bucket/...
```

---

## 🎓 KULLANICI İLE İLETİŞİM

### Resim Kabul Edilirse
```
✅ "Resminiz başarıyla yüklendi!"
```

### Quota Aşıldıysa (deny)
```
❌ "Sistem bakımda. Lütfen daha sonra tekrar deneyin."
```

### Fallback Allow'da
```
⚠️ "Resim yüklendi ama güvenlik kontrolü atlanmıştır."
```

---

## ✅ SON KONTROL LİSTESİ

- [x] Quota kontrol fonksiyonları eklendi
- [x] Admin komutları eklendi
- [x] Firestore koleksiyonu tasarlandı
- [x] Fallback stratejileri uygulandı
- [x] Error handling eklendi
- [x] Logs yapılandırıldı
- [x] Belgeler yazıldı
- [x] Test senaryoları hazırlandı
- [ ] Deployment (yapılacak)
- [ ] Prod test (yapılacak)

---

## 💡 ÖZET

**Sistemin Amacı:** Para bittiğinde Vision API'yi otomatik olarak kapatmak

**Ana Özellikler:**
1. ✅ Otomatik quota takibi
2. ✅ 3 fallback stratejisi
3. ✅ Admin kontrol paneli
4. ✅ Detaylı logging
5. ✅ Aylık otomatik sıfırlama

**Sonuç:** Başarı başında "para yok" krizi yaşanmayacak. Sistem kontrollü kapatılacak.

---

**Son Not:** Sistem tamamen otomatiktir. Admin'in yapması gereken sadece aylık kontrol ve gerekirse karar almak. Geri kalan her şey otomatik çalışıyor!
