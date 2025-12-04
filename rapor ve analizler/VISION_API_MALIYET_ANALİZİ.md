# Google Cloud Vision API - MALIYET ANALİZİ

**Tarih:** 4 Aralık 2025  
**Sistem:** Kampüs Forum Resim Kontrol Sistemi

---

## 💰 VISION API PARA ÖDEDİĞİ Mİ?

### Kısa Cevap
✅ **EVET, paralı.** Google Cloud Vision API ücretlidir.

---

## 📊 MALIYET YAPISI

### Vision API Safe Search Detection Fiyatlandırması

| İşlem | Fiyat | Sınır |
|-------|-------|-------|
| **İlk 1000 istek/ay** | 🆓 **ÜCRETSİZ** | Free tier |
| **1000+ istek** | **$3.50 / 1000 istek** | Ödeme gerekli |
| **Kampüs Forum örneği** | 100 resim/gün | ~3000/ay = **$10.50/ay** |

### Örnek Hesaplama

```
📱 Kampüs Forum'da 50 aktif kullanıcı:
- Günlük 100 resim upload = 3000/ay
- 1000 tanesi free (ilk ay)
- 2000 tanesi ücretli: 2000 ÷ 1000 × $3.50 = $7.00/ay

💸 Aylık Maliyet: ~$7-10
💶 Yıllık Maliyet: ~$84-120
```

---

## 🔍 RESİM KONTROL KAÇ YERDE ÇALIŞIYOR?

### 1. **Upload Sırasında (Storage Trigger)**
**Fonksiyon:** `moderateUploadedImage`
- **Trigger:** Resim Firebase Storage'a yüklenir
- **İşlem:** Vision API çağrısı (**1 API çağrısı = 1 resim**)
- **Sıklık:** Her upload'ta otomatik çalışır

```javascript
exports.moderateUploadedImage = functions.region(REGION).storage
  .object()
  .onFinalize(async (object) => {
    // ... 
    const safetyResult = await checkImageSafety(gcsPath); // ⚠️ VISION API ÇAĞRISI
    // ...
  });
```

**Maliyet:** 💰 Her resim upload'u = 1 API çağrısı

---

### 2. **Upload Öncesi Ön Kontrol (Client-Side)**
**Fonksiyon:** `analyzeImageBeforeUpload`
- **Trigger:** Kullanıcı resim seçer, upload'a tıklamadan önce kontrol eder
- **İşlem:** Vision API çağrısı (**1 API çağrısı = 1 resim**)
- **Sıklık:** Kullanıcı isterse çalışır

```javascript
exports.analyzeImageBeforeUpload = functions.region(REGION).https.onCall(
  async (data, context) => {
    const safetyResult = await checkImageSafety(imageUrl); // ⚠️ VISION API ÇAĞRISI
    // ...
  }
);
```

**Maliyet:** 💰 Her ön kontrol = 1 API çağrısı

---

### 3. **Yeniden Yükleme (Reddetilen Resimler)**
**Fonksiyon:** `reuploadAfterRejection`
- **Trigger:** Kullanıcı reddedilen resmi yeniden yüklemeye çalışır
- **İşlem:** Vision API çağrısı (**1 API çağrısı = 1 resim**)
- **Sıklık:** Kullanıcı yeniden yüklerse çalışır

```javascript
exports.reuploadAfterRejection = functions.region(REGION).https.onCall(
  async (data, context) => {
    const safetyResult = await checkImageSafety(newImageUrl); // ⚠️ VISION API ÇAĞRISI
    // ...
  }
);
```

**Maliyet:** 💰 Her yeniden yükleme = 1 API çağrısı

---

## ⚠️ MALIYET PROBLEMİ

### Sorun: **Çiftli API Çağrısı**

Eğer kullanıcı:
1. **Önce `analyzeImageBeforeUpload` çağırır** (ön kontrol) → **1 API çağrısı** 💰
2. **Sonra storage'a upload eder** → **moderateUploadedImage trigger** → **1 API çağrısı** 💰

**Sonuç: Aynı resim 2 kez analiz edilir!**

```
Kullanıcı akışı:
┌─────────────────────────────────────────────┐
│ 1. Resim seçer                              │
│ 2. "Kontrol et" → analyzeImageBeforeUpload  │  🔴 API ÇAĞRISI #1
│ 3. "Tamam, upload et"                       │
│ 4. Storage'a yükler                         │
│ 5. moderateUploadedImage trigger            │  🔴 API ÇAĞRISI #2
│ 6. Aynı resim 2. kez analiz edilir!         │
└─────────────────────────────────────────────┘

Çift Maliyet! 💸💸
```

---

## 🛠️ NASIL ÇALIŞIYOR DETAYLI

### Safe Search Detection Nedir?

Google Cloud Vision, resmi analiz ederken:

```
Resim
  ↓
Vision API
  ↓
┌─────────────────────────────────────┐
│ 1. ADULT CONTENT (Cinsel İçerik)    │ → % kaç olasılık
│ 2. RACY (Kışkırtıcı İçerik)         │ → % kaç olasılık
│ 3. VIOLENCE (Şiddet)                │ → % kaç olasılık
│ 4. MEDICAL (Tıbbi Görüntü)          │ → % kaç olasılık
│ 5. SPOOF (Sahte/Manipüle)           │ → % kaç olasılık
└─────────────────────────────────────┘
  ↓
Sonuç: LIKELY, VERY_LIKELY, POSSIBLE, UNLIKELY, vb.
```

### Kampüs Forum'da Eşikler

```javascript
const IMAGE_MODERATION_CONFIG = {
  ADULT_THRESHOLD: 0.6,      // 60% üzeri → KIRMIZI BAYRAK 🚫
  RACY_THRESHOLD: 0.7,       // 70% üzeri → KIRMIZI BAYRAK 🚫
  VIOLENCE_THRESHOLD: 0.7,   // 70% üzeri → KIRMIZI BAYRAK 🚫
  MEDICAL_THRESHOLD: 0.8,    // 80% üzeri → KIRMIZI BAYRAK 🚫
};
```

---

## 💡 MALİYET AZALTMA STRATEJİLERİ

### 1. **Çiftli API Çağrısını Ortadan Kaldır**

❌ **Mevcut Akış (2 API çağrısı):**
```
analyzeImageBeforeUpload() → API #1
     ↓
moderateUploadedImage() → API #2  ❌ Gereksiz!
```

✅ **Düzeltilmiş Akış (1 API çağrısı):**
```
Opsiyonlar:
a) ÖN KONTROL AT → Sadece upload'ta kontrol et
b) CACHING → Aynı resim yeniden analiz edilmesin
c) CLIENT-SIDE → Sadece storage'da kontrol et
```

**Tasarruf:** 50% maliyet indirimi = **$42-60/yıl**

---

### 2. **Boyut Limiti Kontrol Et**

```javascript
const IMAGE_MODERATION_CONFIG = {
  ALLOWED_TYPES: ["image/jpeg", "image/png", "image/gif", "image/webp"],
  MAX_SIZE: 10 * 1024 * 1024, // ✅ 10MB limit var
};
```

**Daha sıkı limit yapabilir:**
```javascript
MAX_SIZE: 3 * 1024 * 1024, // 3MB'a düşür
// Daha küçük = daha az işlem = biraz tasarruf
```

---

### 3. **Yalnızca Şüpheli Resimler Kontrol Et**

```javascript
// Ön kontrol: Yalnızca kullanıcı isterse yap
// (Zorunlu değil, isteğe bağlı)

exports.analyzeImageBeforeUpload = functions.region(REGION)
  .https.onCall(async (data, context) => {
    // Bu fonksiyon OPSIYONELDIR
    // Kullanıcı isterse çalışır, istemezse atlar
  });
```

**Tasarruf:** Ön kontrol atlanırsa = **50% tasarruf**

---

### 4. **Profil Resmi vs. Post Resmi Ayrımı**

```javascript
// Profil resmi: 1 kez upload, hemen delete olanlar
// Post resmi: Sık reşletilen, kalıcı olanlar

if (filePath.includes('profil_resimleri')) {
  // Daha sıkı kontrol (maliyete değer)
  const result = await checkImageSafety(gcsPath);
} else if (filePath.includes('post_images')) {
  // Cache ile kontrol → tasarruf
  const cached = await checkCachedSafety(gcsPath);
}
```

---

### 5. **Batch Processing**

Vision API batch endpoint kullanarak:
- Bir çağrıda 16 resim kontrol edebilir
- **Maliyet azalması:** Minimal ama yardımcı

---

## 📈 BÜTÇE SENARYOLARI

### Senaryo 1: **Düşük Kullanım (Test/MVP)**
```
Günlük: 10 resim
Aylık: 300 resim
1. Ay: FREE (ilk 1000 dahil)
2. Ay: 300 - 1000 = ÜCRETSİZ
Yıllık: ✅ ÜCRETSİZ
```

### Senaryo 2: **Orta Kullanım (Normal Kampüs)**
```
Günlük: 50 resim
Aylık: 1500 resim
1. Ay: 500 × $0.0035 = $1.75
2-12. Ay: 1500 × $0.0035 = $5.25 × 11 = $57.75
Yıllık: ~$60
```

### Senaryo 3: **Yüksek Kullanım (Viral)**
```
Günlük: 200 resim
Aylık: 6000 resim (ÇIFIT ÇAĞRI)
Aylık maliyet: (6000 ÷ 1000) × $3.50 = $21
Yıllık: ~$252
```

**⚠️ DİKKAT:** Çiftli çağrı yapılıyorsa, maliyetler **2 katına çıkar!**

---

## 🔐 FIREBASE BİLGİ

### Vision API Nerden Gelir?

```
Firebase Project
    ↓
Google Cloud Project (bağlı)
    ↓
Google Cloud Vision API
    ↓
Billing Account (Google Cloud Billing)
```

**Ödeme şu kişi tarafından yapılır:**
- 📧 Proje sahibi (Firebase Console → Projekt ayarları)
- 💳 Bağlı Google Cloud Billing account

---

## 📋 YAPILACAKLAR

### Hemen (Acil):
1. ✅ Çiftli API çağrısını kontrol et
2. ✅ Ön kontrol fonksiyonunu opsiyonel yap
3. ✅ Cache mekanizması ekle

### Kısa Vadede:
4. ⏳ Kullanım metrikleri takip et
5. ⏳ Batch processing ekle
6. ⏳ Resim boyut limitini düşür

### Uzun Vadede:
7. 📅 Alternatif API araştır (açık kaynak)
8. 📅 Moderasyon manuel panel ekle (insan doğrulaması)

---

## 🎯 MALIYET ÖZETI

| Kategori | Aylık Maliyet |
|----------|---------------|
| **İlk 1000 istek** | 🆓 ÜCRETSİZ |
| **Düşük kullanım (300)** | 🆓 ÜCRETSİZ |
| **Orta kullanım (1500)** | ~$5 |
| **Yüksek kullanım (6000)** | ~$21 |
| **Çiftli çağrı durumu** | **2x Maliyet** |

---

## ✅ SONUÇ

### Maliyet Malı mı?
- **Küçük kampüs:** ÜCRETSİZ (1000 limit altında)
- **Orta kampüs:** ~$5-10/ay (çok ucuz)
- **Büyük kampüs:** ~$20-30/ay (yönetilebilir)

### Hangisi Pahalı?
- ❌ Çiftli API çağrısı (Mevcut sorun)
- ❌ Gereksiz ön kontrol
- ❌ Yüksek çözünürlüklü resimler

### Hangisi Ucuz?
- ✅ İlk 1000 istek/ay (FREE)
- ✅ Storage (resim depolama ~$0.020/GB)
- ✅ Firestore (meta veri depolama minimal)

**🎯 En büyük tasarruf:** Çiftli çağrı sorununu çözmek = **50% tasarruf**

---

**Son Not:** Vision API ucuz bir hizmettir. Asıl maliyet **Firebase Functions CPU zamanı** (compute) olabilir. İçerik kontrol Logic'i kendisi Vision API'den daha pahalıya gelebilir!
