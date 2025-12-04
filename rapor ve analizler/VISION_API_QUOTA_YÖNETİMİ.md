# Vision API Quota Yönetimi - Admin Kılavuzu

**Tarih:** 4 Aralık 2025  
**Sistem:** Kampüs Forum Resim Kontrol Sistemi

---

## 📊 QUOTA SISTEMI

### Temel Kurallar

```
Aylık Free Quota: 1000 istek
Sonrası Maliyet: $3.50 / 1000 istek

Bütçe Tahtası:
┌─────────────────────────────────┐
│ 0-1000   │ 🟢 ÜCRETSİZ           │
├─────────────────────────────────┤
│ 1000+    │ 🔴 PARA GEREKLI        │
│          │ ($3.50/1000)           │
└─────────────────────────────────┘
```

### Quota Dolduruldu Saati?

**Sistem Otomatik Yapar:**
1. ✅ Resim analiz işlemi başlar
2. ✅ Quota kontrol edilir
3. ✅ Eğer kalmamışsa sistem **reddeder**
4. ✅ Admin'e **uyarı** gönderilir

---

## 🎮 ADMIN KOMUTLARI

### 1️⃣ Quota Durumunu Kontrol Et

**Fonksiyon:** `getVisionApiQuotaStatus`

```javascript
{
  "monthlyFreeQuota": 1000,      // Aylık serbest limit
  "used": 847,                   // Kullanılan sayısı
  "remaining": 153,              // Kalan sayısı
  "quotaExceeded": false,        // Aşıldı mı?
  "enabled": true,               // Sistem aktif mi?
  "fallbackStrategy": "deny",    // Quota aşıldığında ne yapacak?
  "currentMonth": "2025_12"      // Hangi ay?
}
```

**Kullanım Örneği (Firebase Console):**
```
Fonksiyon Çağırma → getVisionApiQuotaStatus
Parametreler: {} (boş)
↓
Sonuç: quota durumu gösterilir
```

---

### 2️⃣ Vision API'yi Etkinleştir/Devre Dışı Bırak

**Fonksiyon:** `setVisionApiEnabled`

```javascript
// API'yi KAPATMAK (para tasarrufu için):
{
  "enabled": false
}

// API'yi AÇMAK:
{
  "enabled": true
}
```

**Sonuç:**
```
enabled = false → Hiçbir resim kontrol edilmez (sistem devre dışı)
enabled = true  → Normal çalışma
```

**Senaryo:** Para bitmişse `false` yaparak sistem kapatabilirsin.

---

### 3️⃣ Fallback Stratejisi Değiştir

**Fonksiyon:** `setVisionApiFallbackStrategy`

Quota aşıldığında ne yapacak?

```javascript
// Opsiyon 1: REDDET (varsayılan)
{
  "strategy": "deny"
}
// → Kullanıcı: "Sistem bakımda, resim yüklenemiyor"

// Opsiyon 2: İZİN VER
{
  "strategy": "allow"
}
// → Kullanıcı: Resim yüklenebiliyor ama kontrol edilmiyor

// Opsiyon 3: UYAR
{
  "strategy": "warn"
}
// → Kullanıcı: Uyarı alır ama yükleme devam eder
```

**Hangisini Seçmeliyim?**

| Strateji | Ne Zaman | Neden |
|----------|----------|-------|
| **deny** | 🏠 Kampüs başında | Para yok, güvenli olsun |
| **allow** | 📱 Büyüdüğü zaman | Hizmet kesilmesini istemesin |
| **warn** | ⚠️ Kısmen | Uyar ama yüklenebilir |

---

### 4️⃣ Quota'yı Sıfırla (ACİL)

**Fonksiyon:** `resetVisionApiQuota`

⚠️ **DIKKAT:** Yalnızca acil durumlarda kullan!

```javascript
{
  // Parametre yok, doğrudan çağır
}

// Sonuç:
{
  "success": true,
  "message": "2025_12 ayı quota'ı sıfırlandı. Sistem 1000 yeni istekle başladı."
}
```

**Ne Zaman Kullanalım?**
- ✅ Hatalı sayım (sistem hata yaptıysa)
- ✅ Yeni pakete yükseltme
- ❌ Normal durumda KULLANMA!

---

## 📋 QUOTA KONTROL AKIŞI

```
Kullanıcı Resim Yüklüyor
    ↓
moderateUploadedImage Trigger
    ↓
checkImageSafety() çağrısı
    ↓
canUseVisionApi() kontrol
    ↓
┌─────────────────────────────┐
│ Quota kaldı mı?             │
├─────────────────────────────┤
│ EVET → analyzeImageWithVision│
│        API çağrısı yap       │
│        Sayaç +1              │
│        Resim analiz et       │
│                              │
│ HAYIR → Fallback Strategy    │
│ "deny" → REDDET 🚫           │
│ "allow" → İZİN VER ✅        │
│ "warn" → UYAR ⚠️             │
└─────────────────────────────┘
    ↓
Sonuç Kullanıcıya Gösterilir
```

---

## 🔍 LOG DOSYALARI

### Console'da Göreceğin Mesajlar

**Başarılı Çağrı:**
```
[QUOTA_OK] Kalan quota: 153/1000
[ANALYZING] Resim analiz ediliyor: gs://bucket/...
```

**Quota Aşıldı:**
```
[QUOTA_EXCEEDED] Aylık quota tükendi! Kullanılan: 1000/1000
[VISION_BLOCKED] API kullanılmıyor: QUOTA_EXCEEDED
```

**API Kapalı:**
```
[VISION_DISABLED] Vision API global olarak devre dışı
```

**Hata Durumunda:**
```
[QUOTA_ERROR] Quota kontrol hatası
[FALLBACK_DENY] Quota kontrol başarısız, reddedildi
```

---

## 💾 FIRESTORE KOLEKSİYONLARI

### 1. `vision_api_quota` Koleksiyonu

Her ayın quota'sı burada tutulur.

**Döküman Yapısı:**
```
Koleksiyon: vision_api_quota
Döküman ID: "2025_12" (YYYY_MM format)

{
  "monthKey": "2025_12",
  "usageCount": 847,                    // Kullanılan sayı
  "lastUpdated": Timestamp(2025-12-04)
}
```

---

### 2. `system_config` Koleksiyonu

Sistem ayarlarının geçmişi.

**Döküman Yapısı:**
```
Koleksiyon: system_config
Döküman ID: "vision_api"

{
  "enabled": true,
  "fallbackStrategy": "deny",
  "updatedAt": Timestamp(...),
  "updatedBy": "user_id_of_admin"
}
```

---

## 🎯 SENARYOLAR

### Senaryo 1: Normal Ay (Quota Var)

```
Tarih: 1-15 Aralık
Quota: 847/1000 kullanıldı
Durum: ✅ Normal çalışma

Yapılacak: Hiçbir şey (sistem otomatik)
```

---

### Senaryo 2: Quota Bitti

```
Tarih: 20 Aralık
Quota: 1000/1000 kullanıldı
Durum: 🚫 Sistem çalışmıyor

Seçenekler:
1. Para yükleme (Google Cloud)
2. API'yi kapat: setVisionApiEnabled({enabled: false})
3. Stratejiyi değiştir: setVisionApiFallbackStrategy({strategy: "allow"})
```

**Adım Adım:**

```
1. Admin olarak gir
2. getVisionApiQuotaStatus() çağır
3. "Quota Exceeded" uyarısını gör
4. Karar ver:
   a) Para yok → setVisionApiEnabled({enabled: false})
   b) Para var → Billing'den ödeme yap
   c) Özel durum → setVisionApiFallbackStrategy({strategy: "allow"})
```

---

### Senaryo 3: Hatalı Sayım

```
Tarih: 10 Aralık
Sorun: Quota gösterge yanlış (1000 yazıyor ama para kaldı)
Çözüm: resetVisionApiQuota() çağır

Uyarı: Bu yalnızca Google Cloud'dan kontrol ettikten sonra!
```

---

## 🛡️ GÜVENLIK

### Kimin Yapabilir?

```
Fonksiyon                         | Yetki
----------------------------------|----------
getVisionApiQuotaStatus           | Giriş yapan her admin
setVisionApiEnabled               | Sadece admin
setVisionApiFallbackStrategy      | Sadece admin
resetVisionApiQuota               | Sadece admin
```

### Kontrol Noktası

```javascript
// Her admin fonksiyonda:
const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
if (userDoc.data()?.role !== "admin") {
  throw new Error("Sadece admin yapabilir");
}
```

---

## 💡 BEST PRACTICES

### 1. **Aylık Kontrol Rutini**

Her ayın ilk günü:
```
1. getVisionApiQuotaStatus() kontrol et
2. Eğer 800+ ise, bütçe planla
3. Eğer 1000 ise, acil karar ver
```

---

### 2. **Kullanıcılara Bildir**

Quota bittikten sonra:
```
"Sistem bakımda. Uygulamayı güncelleyin.
Resim yükleme 1 Ocak'ta açılacak. Teşekkürler!"
```

---

### 3. **Fallback Strateji**

Para yok ise:
```
setVisionApiFallbackStrategy({strategy: "allow"})
// → Resimler kontrol edilmeden yüklenir
//   (Moderatör insan gözüyle kontrol edebilir)
```

---

## 📞 İLGİLİ FONKSİYONLAR

| Fonksiyon | İlgili |
|-----------|--------|
| `analyzeImageWithVision` | Quota kontrolü yapıp API çağrısı |
| `checkImageSafety` | Quota aşıldıysa fallback yapıyor |
| `moderateUploadedImage` | Storage trigger, image kontrol |
| `analyzeImageBeforeUpload` | Client-side ön kontrol |

---

## ⚙️ KOD YAPISI

### Quota Kontrol Fonksiyonları

```javascript
// 1. Quota kullanımını sorgula
const quota = await getVisionApiQuotaUsage();

// 2. Kullanabilir mi kontrol et
const quotaCheck = await canUseVisionApi();

// 3. Kullanıldıktan sonra sayaç artır
await incrementVisionApiQuota(monthKey);
```

### Ayarlar (Runtime)

```javascript
VISION_API_CONFIG = {
  MONTHLY_FREE_QUOTA: 1000,    // Sabit
  ENABLED: true,               // Değişken (admin değiştirebilir)
  FALLBACK_STRATEGY: "deny"    // Değişken (admin değiştirebilir)
}
```

---

## 🚨 TROUBLESHOOTING

### Problem: "Quota kontrol başarısız"

**Neden:** Firestore okuma hatası  
**Çözüm:** Firestore bağlantısını kontrol et

```javascript
// Console mesajı:
[QUOTA_ERROR] Quota kontrol başarısız
// →fallback strategy uygulanır
```

---

### Problem: "API çağrısı başarısız"

**Neden:** Vision API hatası (API key, network, vb.)  
**Çözüm:** Hata mesajını kontrol et

```javascript
// Hata durumunda:
isUnsafe: true,
error: "API Key invalid"
blockedReasons: ['API hatası - sistem tarafından reddedildi']
```

---

### Problem: Sayaç yanlış

**Neden:** Hata veya sistem hatası  
**Çözüm:** `resetVisionApiQuota()` çağır

```javascript
// Doğru kontrol:
Google Cloud Console → Vision API → Quotas
// Orada gösterilen sayı "gerçek sayı"
// Eğer farklıysa → resetVisionApiQuota()
```

---

## ✅ CHECKLIST

- [ ] **Ayın ilk günü:** `getVisionApiQuotaStatus()` kontrol et
- [ ] **800+ ise:** Bütçe planlaması yap
- [ ] **1000 ise:** Karar ver (para mi, false mi, strategy değiştir mi)
- [ ] **Para yok:** `setVisionApiEnabled({enabled: false})` yap
- [ ] **Aylık kontrol:** Logs'ta hata var mı bak

---

## 📝 ÖZET

| İşlem | Fonksiyon | Parametre |
|-------|-----------|-----------|
| Quota görüntüle | `getVisionApiQuotaStatus` | {} |
| API aç/kapat | `setVisionApiEnabled` | `{enabled: boolean}` |
| Strateji değiştir | `setVisionApiFallbackStrategy` | `{strategy: "deny"\|"allow"\|"warn"}` |
| Quota sıfırla | `resetVisionApiQuota` | {} |

---

**Son Not:** Sistem otomatik olarak quota'yı takip ediyor. Admin'in yapması gereken sadece aylık kontrol ve gerekli karar alması.

**Para bitti mi?** → `setVisionApiEnabled({enabled: false})` yap. Sistem kapanır, resim yükleme durdurulur.
