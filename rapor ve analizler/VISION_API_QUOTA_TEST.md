# Vision API Quota Sistemi - Test Kılavuzu

**Tarih:** 4 Aralık 2025

---

## 🧪 QUOTA SİSTEMİNİ TEST ETMEK

### Test 1: Quota Durumunu Kontrol Et

**Adımlar:**
1. Firebase Console aç
2. Cloud Functions git
3. `getVisionApiQuotaStatus` fonksiyonunu çağır
4. Parameter: boş {} 
5. Çalıştır

**Beklenen Sonuç:**
```json
{
  "success": true,
  "monthlyFreeQuota": 1000,
  "used": 0,
  "remaining": 1000,
  "quotaExceeded": false,
  "enabled": true,
  "fallbackStrategy": "deny",
  "currentMonth": "2025_12",
  "message": "✅ Quota OK: 1000/1000 kaldı"
}
```

**Ne Anlama Geliyor?**
- ✅ Sistem çalışıyor
- ✅ Bu ayın quota'sı boş
- ✅ 1000 resim yükleyebilir

---

### Test 2: API'yi Kapat

**Adımlar:**
1. `setVisionApiEnabled` fonksiyonunu çağır
2. Parameter: `{"enabled": false}`
3. Çalıştır

**Beklenen Sonuç:**
```json
{
  "success": true,
  "message": "Vision API devre dışı bırakıldı",
  "enabled": false
}
```

**Etki:**
- ❌ Artık hiçbir resim analiz edilmez
- ✅ Hata almadan yükleme başarısız olur

---

### Test 3: API'yi Aç

**Adımlar:**
1. `setVisionApiEnabled` fonksiyonunu çağır
2. Parameter: `{"enabled": true}`
3. Çalıştır

**Beklenen Sonuç:**
```json
{
  "success": true,
  "message": "Vision API aktifleştirildi",
  "enabled": true
}
```

**Etki:**
- ✅ Resim analizi normal çalışmaya devam eder

---

### Test 4: Fallback Strategisini Değiştir

**Senaryo:** Quota dolduruldu ama izin vermek istiyoruz

**Adımlar:**
1. `setVisionApiFallbackStrategy` fonksiyonunu çağır
2. Parameter: `{"strategy": "allow"}`
3. Çalıştır

**Beklenen Sonuç:**
```json
{
  "success": true,
  "message": "Fallback stratejisi \"allow\" olarak ayarlandı",
  "strategy": "allow"
}
```

**Etki:**
- Quota aşıldıktan sonra bile resimler kontrol edilmeden yüklenir

---

### Test 5: Stratejiyi "deny"ye Geri Al

**Adımlar:**
1. `setVisionApiFallbackStrategy` çağır
2. Parameter: `{"strategy": "deny"}`
3. Çalıştır

**Beklenen Sonuç:**
```json
{
  "success": true,
  "message": "Fallback stratejisi \"deny\" olarak ayarlandı",
  "strategy": "deny"
}
```

**Etki:**
- Quota aşıldığında resim yükleme reddedilir

---

## 🔄 ENTEGRE TEST (Uçtan Uca)

### Senaryo: Quota'yı Doldur (Simülasyon)

**Amaç:** Sistemin quota aşıldığında nasıl davrandığını görmek

**Adımlar:**

#### 1. Firestore'da Sayaç Oluştur

Cloud Firestore → New Collection

```
Collection: vision_api_quota
Document ID: 2025_12
Alanlar:
  monthKey: "2025_12"
  usageCount: 999  ← 1000'e yakın
  lastUpdated: now()
```

#### 2. Resim Yükle

Kampüs Forum uygulamasında resim yükle

**Beklenen Davranış:**
```
1. Resim yüklenir
2. moderateUploadedImage Trigger çalışır
3. canUseVisionApi() kontrol eder
4. Kalan: 1 istek kalacak
5. Vision API çağrılır
6. sayaç: usageCount = 1000 olur
```

#### 3. Tekrar Resim Yükle

Başka bir resim yükle

**Beklenen Davranış:**
```
1. Resim yüklenir
2. moderateUploadedImage Trigger çalışır
3. canUseVisionApi() kontrol eder
4. ⚠️ Kalan: 0 istek
5. throwError: "Quota Exceeded"
6. checkImageSafety() fallback yapar
7. fallbackStrategy = "deny" → resim reddedilir
```

#### 4. Console Logları Kontrol Et

Firebase Functions → Logs

**Bulacağın Mesajlar:**
```
[QUOTA_OK] Kalan quota: 1/1000
[ANALYZING] Resim analiz ediliyor...
[QUOTA_EXCEEDED] Aylık quota tükendi!
[VISION_BLOCKED] API kullanılmıyor: QUOTA_EXCEEDED
```

---

## 📱 KULLANICI TEST (Frontend)

### Test Akışı

```
1. Kampüs Forum uygulamasını aç
2. Gönder sayfasına git
3. Resim seç
4. Görüntü Kontrolü (ön kontrol) - isteğe bağlı
   └─ "Resim Kontrol Et" butonuna tıkla
5. "Gönder" butonuna tıkla
6. Resim yüklenir ve kontrol edilir
```

### Hata Alırsa

```
❌ "Sistem bakımda, resim yüklenemedi"
   └─ Quota bitti, fallback = "deny"

❌ "Vision API Quota Exceeded"
   └─ Admin tarafında hata, logs kontrol et

✅ "Resim başarıyla yüklendi!"
   └─ Kontrol geçti, normal yükleme
```

---

## 🔍 DEBUG MOD

### Firestore Loglarını Oku

```
Collection: vision_api_quota
Document ID: 2025_12

Field: usageCount
→ Burası artmalı her resim yüklendikçe
```

### Cloud Functions Loglarını Oku

```
1. Firebase Console aç
2. Cloud Functions git
3. İlgili fonksiyon git (moderateUploadedImage)
4. Logs sekmesine tıkla
5. Saatine göre filtrele
6. Mesajları oku:
   - [QUOTA_OK] ← iyi
   - [QUOTA_EXCEEDED] ← quota bitti
   - [VISION_BLOCKED] ← API kapalı
```

---

## ⚙️ BEKLENEN DAVRANIŞLAR

### Senaryo A: Quota OK (Normal)

```
Kondisyon: used < 1000
Action: Vision API çağrısı yap
Result: ✅ Resim analiz edilir
Log: [QUOTA_OK] Kalan quota: XXX/1000
```

---

### Senaryo B: Quota EXCEEDED (Fallback Deny)

```
Kondisyon: used >= 1000 ve fallback = "deny"
Action: Vision API çağrısı yapma
Result: ❌ Resim reddedilir
Log: [QUOTA_EXCEEDED] Aylık quota tükendi!
User: "Sistem bakımda..."
```

---

### Senaryo C: Quota EXCEEDED (Fallback Allow)

```
Kondisyon: used >= 1000 ve fallback = "allow"
Action: Vision API çağrısı yapma, izin ver
Result: ✅ Resim yüklenir (kontrol edilmez)
Log: [QUOTA_EXCEEDED] ... [FALLBACK_ALLOW]
User: "Resim başarıyla yüklendi!"
```

---

### Senaryo D: API Disabled

```
Kondisyon: VISION_API_CONFIG.ENABLED = false
Action: Vision API çağrısı yapma
Result: ❌ Sistem devre dışı
Log: [VISION_DISABLED] Vision API global olarak devre dışı
```

---

## 🐛 HATA ÇÖZMEK

### Problem: Logs'ta Quota kontrol başarısız

```
Log: [QUOTA_ERROR] Quota kontrol başarısız
Sebep: Firestore bağlantı hatası
Çözüm: 
  1. Firestore status sayfasını kontrol et
  2. Rules'ı kontrol et (okuma izni var mı?)
  3. Fonksiyonu tekrar çalıştır
```

---

### Problem: Sayaç artmıyor

```
Symptom: usageCount artmasa rağmen API çağrılıyor
Sebep: sayaç artırma başarısız
Çözüm:
  1. [ANALYZING] logu var mı kontrol et
  2. Eğer varsa API çağrıldı, sayaç artırılmalı
  3. Eğer sayıcı artmıyorsa Firestore write hatası
  4. Rules kontrol et
```

---

### Problem: Quota'da hata görülüyor

```
Symptom: Firestore'da 2025_12 dökümanı yok
Sebep: İlk kez bu ay test ediliyor
Çözüm: Otomatik oluşur ilk API çağrısında
```

---

## 📊 PERFORMANS TESTİ

### Quota Kontrolü CPU Maliyeti

```
✅ Firestore Read: 1 (Quota kontrolü)
✅ Vision API Call: 1 (Analiz)
✅ Firestore Write: 1 (Sayaç artırma)

Toplam: 3 okuma + 1 yazma
Maliyet: ~$0.000003 per image (Firestore)
        + $0.0000035 per image (Vision API)
```

---

### Test Sonuçları Tablosu

| Test | Sonuç | Logs | Firestore |
|------|-------|------|-----------|
| Quota Kontrol | ✅ OK | [QUOTA_OK] | usageCount artabilir |
| API Kapalı | ❌ BLOCKED | [VISION_DISABLED] | Logs only |
| Quota Full | ❌ EXCEEDED | [QUOTA_EXCEEDED] | usageCount=1000 |
| Fallback Allow | ✅ ALLOWED | [FALLBACK_ALLOW] | Kontrol atlanır |
| Fallback Deny | ❌ DENIED | [FALLBACK_DENY] | Kontrol atlanır |

---

## ✅ TEST CHECKLIST

- [ ] `getVisionApiQuotaStatus` normal çalışıyor
- [ ] `setVisionApiEnabled` disable/enable yapıyor
- [ ] `setVisionApiFallbackStrategy` stratejisi değiştiriyor
- [ ] Resim yükleme normal yapılıyor
- [ ] Firestore'da usageCount artıyor
- [ ] Logs'ta doğru mesajlar görülüyor
- [ ] Quota aşıldığında fallback çalışıyor
- [ ] API kapalıyken sistem çalışmıyor

---

## 🚀 DEPLOYMENT ÖNCESİ

```
1. ✅ Tüm testleri geç
2. ✅ Logs'ta hata yok
3. ✅ Firestore kurallarını kontrol et (vision_api_quota)
4. ✅ Admin rolü ayarlanmış kullanıcılar olduğunu kontrol et
5. ✅ Deployment yap
6. ✅ Prod'da bir resim yükle ve kontrol et
7. ✅ Logs'ta [QUOTA_OK] mesajı var mı kontrol et
```

---

**Sonuç:** Sistem otomatik olarak çalışıyor. Test ediliyorsa tüm kontroller işliyor demektir!
