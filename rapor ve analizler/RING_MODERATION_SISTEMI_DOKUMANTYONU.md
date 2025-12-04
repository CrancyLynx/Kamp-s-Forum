<!-- RING SEFER MODERASYONVESİSTEMİ DÖKÜMANTASYONU -->

# 🚌 Ring Sefer Moderation ve Bildirim Sistemi

## ✨ Genel Bakış

Ring sefer (ulaşım tarifeleri) için geliştirilmiş bir **admin onay sistemi** ve **bildirim yönetimi** uygulanmıştır. Artık öğrenciler ring/servis fotoğrafı yüklediklerinde, admin panelden incelenip onaylanmak üzere beklemede kalacak ve onay sonrasında otomatik olarak ilgili üniversite kullanıcılarına bildirim gönderilecektir.

---

## 🔧 Teknik Mimarisi

### 1. **Firebase Firestore Kuralları (Güncellenmiş)**

#### Yeni Koleksiyonlar:

- **`ulasim_bilgileri/{universityName}`** (Onaylı fotoğraflar)
  - Herkese okuma açık
  - Admin/Moderatör yazma izni
  - İçerik: `imageUrl`, `updaterName`, `approvedBy`, `approvedAt`, `approvedByName`

- **`pending_ring_photos/{photoId}`** (Bekleme aşamasındaki fotoğraflar)
  - Admin/Moderatör okuması
  - Kullanıcı kendisinin yüklediklerini görebilir
  - İçerik: `photoUrl`, `status` (pending/approved/rejected), `rejectionReason`, `approvedBy`

- **`ring_photo_moderation/{recordId}`** (Moderasyon log)
  - Admin/Moderatör erişimi
  - Tüm onay/ret işlemlerinin kaydı
  - İçerik: `action` (approved/rejected), `photoId`, `reason`, `timestamp`

---

### 2. **Firebase Storage Kuralları (Güncelleme)**

Mevcut Storage kurallarında Ring sistemi için 4 klasör tanımlanmıştır:

- **`pending_ring_photos/{universityName}/{fileName}`** - Moderasyon beklemede
- **`ring_resimleri/{ringId}/{fileName}`** - Ring grup resimleri
- **`ring_sefer_resimleri/{ringId}/{sefarId}/{fileName}`** - Sefer zamanı fotoğrafları
- **`ring_duyuru_resimleri/{ringId}/{duyuruId}/{fileName}`** - Ring duyuruları

---

### 3. **Yeni Services (Servisler)**

#### **RingModerationService** (`lib/services/ring_moderation_service.dart`)
Fotoğraf onay/red işlemlerini yönetir:

```dart
// Fotoğrafı pending status'unda yükle
await RingModerationService.uploadRingPhotoForApproval(
  universityName: 'İTÜ',
  photoStoragePath: 'pending_ring_photos/...',
  uploadedByUserId: userId,
  uploaderName: userName,
);

// Fotoğrafı onayla ve herkese aç
await RingModerationService.approvePendingPhoto(
  photoId: 'photo123',
  adminUserId: adminId,
  adminName: 'Admin Adı',
);

// Fotoğrafı reddet ve sebep belirt
await RingModerationService.rejectPendingPhoto(
  photoId: 'photo123',
  adminUserId: adminId,
  adminName: 'Admin Adı',
  rejectionReason: 'Kalitesiz fotoğraf',
);
```

#### **RingNotificationService** (`lib/services/ring_notification_service.dart`)
Bildirim gönderme işlemlerini yönetir:

```dart
// Üniversite kullanıcılarına yeni ring info bildirimi
await RingNotificationService.notifyUniversityUsersAboutNewRingInfo(
  universityName: 'İTÜ',
  uploaderName: 'Ahmet',
);

// Uploader'a onay bildirimi
await RingNotificationService.notifyUploaderPhotoApproved(
  uploaderUserId: userId,
  uploaderName: userName,
  universityName: 'İTÜ',
  approverName: 'Admin Adı',
);

// Uploader'a ret bildirimi
await RingNotificationService.notifyUploaderPhotoRejected(
  uploaderUserId: userId,
  uploaderName: userName,
  universityName: 'İTÜ',
  rejectionReason: 'Kalitesiz fotoğraf',
  approverName: 'Admin Adı',
);

// Adminlere pending fotoğraf var bildirimi
await RingNotificationService.notifyAdminPendingPhoto(
  universityName: 'İTÜ',
  uploaderName: 'Ahmet',
);
```

---

## 🎨 UI/UX Güncellemeleri

### 1. **Ring Sefer Yükleme Paneli** (`ring_seferleri_sheet.dart`)

**Değişiklikler:**
- Fotoğraf artık direkt olarak `pending_ring_photos` koleksiyonuna kaydedilir
- Kullanıcı geri bildirim alır: "Fotoğraf yüklendi! Admin incelemesinden sonra herkese görünür olacak. Teşekkürler! 🎉"
- Admin otomatik olarak bildirilir

**Akış:**
```
Kullanıcı Fotoğraf Seçer
    ↓
Storage'a Yükle (pending_ring_photos klasörü)
    ↓
Firestore pending_ring_photos'a Kaydet
    ↓
Admin Panel'e Bildirim Gönder
    ↓
Başarı Mesajı Göster
```

### 2. **Admin Panel - Ring Moderation Tab** (`admin_panel_ekrani.dart`)

**Yeni Tab Eklendi:** "Ring Modü" (Ikon: 🚌)

**İki Alt Tab:**
- **Beklemede:** Admin onayı beklenen fotoğraflar
  - Fotoğraf önizlemesi
  - Üniversite adı, yükleyen kişi, tarih
  - "Onayla" (Yeşil) ve "Reddet" (Kırmızı) butonları

- **Onaylı:** Herkese açık hale getirilen fotoğraflar
  - Fotoğraf önizlemesi
  - Üniversite adı, yükleyen, onaylayan kişi, tarih
  - Salt görüntüleme (read-only)

**Onay Süreci:**
```
Admin "Onayla" basarsa:
  1. Fotoğraf pending'den ulasim_bilgileri'ne taşınır
  2. Uploader'a onay bildirimi gönderilir
  3. Üniversite kullanıcılarına yeni ring info bildirimi gönderilir
  4. Ring panelinde otomatik olarak güncellenir

Admin "Reddet" basarsa:
  1. Sebep seçilir (modal dialog)
  2. Storage dosyası silinir
  3. Uploader'a ret bildirimi gönderilir
  4. Moderasyon log'a kaydedilir
```

---

## 📱 Bildirim Türleri

### 1. **Kullanıcı → Admin Bildirimleri**
- **Tür:** `pending_ring_photo_admin`
- **Alıcı:** Tüm admin kullanıcıları
- **Mesaj:** "$Üniversite için $UploaderAdı tarafından yeni bir ring/servis fotoğrafı yüklendi"
- **Action URL:** `admin://moderation/ring_photos`

### 2. **Admin → Uploader Bildirimleri (Onay)**
- **Tür:** `ring_photo_approved`
- **Alıcı:** Fotoğrafı yükleyen kullanıcı
- **Mesaj:** "✅ Yüklediğin $Üniversite ring/servis fotoğrafı onaylandı! Harika iş çıkardın! 🎉"
- **Action URL:** `map://ring/$Üniversite`

### 3. **Admin → Uploader Bildirimleri (Red)**
- **Tür:** `ring_photo_rejected`
- **Alıcı:** Fotoğrafı yükleyen kullanıcı
- **Mesaj:** "⚠️ $Üniversite için yüklediğin fotoğraf reddedildi. Sebep: $Sebep. Lütfen başka bir fotoğraf dene."
- **Action URL:** `map://ring/$Üniversite`

### 4. **Üniversite Kullanıcılarına Bildirimleri (Onay Sonrası)**
- **Tür:** `ring_info_update`
- **Alıcı:** Fotoğrafı onaylanan üniversiteye ait tüm kullanıcılar
- **Mesaj:** "🚌 Yeni Ring Sefer Bilgisi - $Üniversite için ring/servis tarifesi güncellendi (Üyeler: $UploaderAdı)"
- **Action URL:** `map://ring/$Üniversite`

---

## 🔒 Güvenlik Kuralları

### Firebase Firestore Rules
```
pending_ring_photos koleksiyonu:
  - Okuma: Admin/Moderatör + Uploader (kendi dosyaları)
  - Yazma: Yalnızca sistem (uploadRingPhotoForApproval via servis)
  - Güncelleme: Admin/Moderatör (status, approvedBy, rejectionReason)

ulasim_bilgileri koleksiyonu:
  - Okuma: Herkese açık
  - Yazma: Admin/Moderatör
  - Silme: Admin

ring_photo_moderation koleksiyonu:
  - Okuma: Admin/Moderatör
  - Yazma: Admin/Moderatör
```

### Firebase Storage Rules
```
pending_ring_photos: 
  - Okuma: İmage metadata only
  - Yazma: Oturum açmış kullanıcılar
  - Silme: Admin/Sistem (moderation sonrası)
```

---

## 📊 Veri Akışı Diyagramı

```
┌─────────────────────────────────────────────────────────────┐
│                    RING SEFER SISTEMI                       │
└─────────────────────────────────────────────────────────────┘

1. YÜKLEME AŞAMASI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Kullanıcı Üniversitesine Git
        ↓
   Ring Sefer Paneli Aç (RingSeferleriSheet)
        ↓
   "Güncel Tarifeyi Yükle" Butonu Tıkla
        ↓
   Fotoğraf Seç
        ↓
   Storage'a Yükle (pending_ring_photos/{uni}/{fileName})
        ↓
   RingModerationService.uploadRingPhotoForApproval()
        ↓
   Firestore'a pending_ring_photos koleksiyonuna kaydet
        ↓
   RingNotificationService.notifyAdminPendingPhoto()
        ↓
   Tüm adminleri bildir
        ↓
   Kullanıcıya başarı mesajı göster

2. MODERATION AŞAMASI (Admin Paneli)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Admin → Admin Panel → Ring Modü Sekmesi
        ↓
   Beklemede Tab'ında pending fotoğrafları gör
        ↓
   
   SEÇENEK A: ONAYLA
   └──→ RingModerationService.approvePendingPhoto()
        └──→ pending_ring_photos'tan ulasim_bilgileri'ne taşı
        └──→ Storage dosyası kalıcı olur
        └──→ RingNotificationService.notifyUploaderPhotoApproved()
        └──→ RingNotificationService.notifyUniversityUsersAboutNewRingInfo()
        └──→ Başarı Snackbar

   SEÇENEK B: REDDET
   └──→ Sebep dialog'u açılır
   └──→ RingModerationService.rejectPendingPhoto()
        └──→ Storage dosyasını sil
        └──→ pending_ring_photos'u 'rejected' olarak işaretle
        └──→ RingNotificationService.notifyUploaderPhotoRejected()
        └──→ Moderasyon log'a kaydet

3. KULLANICI GÖRÜNTÜLEME AŞAMASI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Kullanıcı Harita → Üniversite Seç
        ↓
   Ring Sefer Paneli Aç
        ↓
   StreamBuilder → ulasim_bilgileri/{universityName}
        ↓
   Onaylanan fotoğraf gösterilir
        ↓
   Bilgi: "Yükleyen: X, Onaylayan: Y, Tarih: ..."
```

---

## 🧪 Test Senaryoları

### Test 1: Normal Yükleme ve Onay
1. Öğrenci A, İTÜ üniversitesine ring fotoğrafı yükler
2. ✅ Firestore'da `pending_ring_photos` koleksiyonunda görünür
3. Admin Panel'de "Ring Modü" → "Beklemede" tab'ında fotoğraf görünür
4. Admin "Onayla" basarsa:
   - ✅ Fotoğraf `ulasim_bilgileri/ITÜ` belgesine geçer
   - ✅ Öğrenci A'ya onay bildirimi gelir
   - ✅ İTÜ'deki tüm kullanıcılara yeni ring info bildirimi gelir
   - ✅ Ring panelinde fotoğraf anında görünür

### Test 2: Yükleme ve Red
1. Öğrenci B, Boğaziçi üniversitesine kötü kaliteli fotoğraf yükler
2. Admin Panel'de görünür
3. Admin "Reddet" basarsa:
   - ✅ Sebep modal'ı açılır (ex: "Fotoğraf bulanık")
   - ✅ Storage dosyası silinir
   - ✅ Öğrenci B'ye red bildirimi gelir
   - ✅ Moderasyon log'a kaydedilir

### Test 3: Üniversite Kullanıcılarına Bildirim
1. Öğrenci C, Galatasaray Üniversitesine ring fotoğrafı yükler
2. Admin onaylarsa:
   - ✅ Galatasaray üniversitesine kayıtlı **tüm** öğrencilere bildirim gönderilir
   - ✅ Her öğrenci "Ring Sefer Bilgisi Güncellendi" bildirimi alır
   - ✅ Bildirim action URL'i harita uygulamasını açar

---

## 🚀 Deployment Adımları

### 1. Firebase Firestore Rules Dağıt
```
Firebase Console → Firestore → Rules
→ firebase databes rules.txt dosyasının içeriğini kopyala/yapıştır
→ Publish
```

### 2. Firebase Storage Rules Dağıt
```
Firebase Console → Storage → Rules
→ firebase storage rules.txt dosyasının içeriğini kopyala/yapıştır
→ Publish
```

### 3. Uygulamayı Güncelleştir
```bash
flutter clean
flutter pub get
flutter run
```

### 4. Admin Erişimi Ayarla
```
Firestore → kullanicilar koleksiyonu
→ Admin kullanıcısının belgesinde role = 'admin' olduğundan emin ol
```

---

## 🔍 Moderasyon Log Sorgusu

Admin panelinde "Ring Modü" sekmesinde yapılan tüm işlemleri görmek için:

```
Firestore → ring_photo_moderation koleksiyonu
→ Tüm onay/ret işlemlerinin tarihi, admin adı, sebep
→ Audit trail için kullanılır
```

---

## ⚙️ Konfigürasyon Seçenekleri

### Maksimum Dosya Boyutu
`firebase storage rules.txt`'de:
```
request.resource.size < 10 * 1024 * 1024 // 10MB
```
(İhtiyaca göre değiştirilebilir)

### Bildirim Mesaj Şablonları
`ring_notification_service.dart`'de tüm mesaj şablonları tanımlanmıştır, özelleştirilebilir.

### Red Nedenleri
Çöplerinde tanımlı kategoriler: "Kalitesiz", "İlgisiz", "Spam" vb. eklenebilir.

---

## 📋 İçerik Moderation İçin Best Practices

1. **Fotoğraf Kalitesi**
   - En az 720p çözünürlükte fotoğraf talep et
   - Okunaklı olması gerekir

2. **İçerik Doğruluğu**
   - Fotoğrafta ring/servis tarifeleri net bir şekilde görülmeli
   - Eski dönem bilgileri reddet

3. **Spam/İlgisiz İçerik**
   - Unrelated fotoğrafları reddet
   - Red sebebi: "İlgisiz içerik"

4. **Hızlı Moderation**
   - Pending fotoğrafları 24 saat içinde incele
   - Kullanıcıya hızlı geri bildirim ver

---

## 📞 Troubleshooting

### Sorun: Admin panelinde Ring Modü görünmüyor
**Çözüm:** `kullanicilar/{userId}` belgesinde `role: 'admin'` olduğundan emin ol

### Sorun: Fotoğraf yüklenemiyor
**Çözüm:** 
- Dosya boyutunu kontrol et (10MB altında olmalı)
- Storage rules'ını kontrol et
- Internet bağlantısını kontrol et

### Sorun: Bildirim gönderilmiyor
**Çözüm:**
- Firestore rules'ını kontrol et
- Kullanıcı üniversitesi Firestore'daki `university` alanında doğru adla eşleşiyor mu?
- Push notification servislerin etkinleştirilmiş mi?

---

## 📚 İlgili Dosyalar

| Dosya | Amaç | Durum |
|------|------|-------|
| `firebase databes rules.txt` | Firestore güvenlik kuralları | ✅ Güncellendi |
| `firebase storage rules.txt` | Storage güvenlik kuralları | ✅ Güncellenmiş |
| `lib/services/ring_moderation_service.dart` | Fotoğraf moderasyon | ✅ Yeni |
| `lib/services/ring_notification_service.dart` | Bildirim yönetimi | ✅ Yeni |
| `lib/widgets/map/ring_seferleri_sheet.dart` | Ring sefer paneli | ✅ Güncellendi |
| `lib/screens/admin/admin_panel_ekrani.dart` | Admin moderation | ✅ Güncellendi |

---

**Son Güncelleme:** 2025-12-04  
**Geliştirici:** Backend Team  
**Versiyon:** 1.0

