# 🚀 Ring Sefer Sistemi - Hızlı Başlangıç Rehberi

## Yapılan Değişiklikler Özeti

### ✨ Yeni Özellikler

1. **Ring Sefer Fotoğraf Moderation Sistemi**
   - Öğrenciler ring/servis fotoğrafı yüklediğinde admin onayı gerekir
   - Onaylandıktan sonra otomatik olarak tüm üniversite kullanıcılarına bildirim

2. **Admin Panel - Ring Moderation Tab**
   - Beklemede ve Onaylı olmak üzere 2 alt tab
   - Fotoğraf önizlemesi, yükleyen ve onaylayan bilgisi
   - Hızlı Onayla/Reddet işlemleri

3. **Otomatik Bildirimler**
   - Admin'e: Yeni fotoğraf yüklendi (pending)
   - Uploader'a: Fotoğraf onaylandı ✅ / Reddedildi ❌ (sebep ile)
   - Üniversite kullanıcılarına: Ring sefer güncellenmiş bildirimi 🚌

### 📁 Yeni Dosyalar

```
lib/services/
├── ring_moderation_service.dart      (Fotoğraf onay/ret işlemleri)
└── ring_notification_service.dart    (Bildirim gönderme işlemleri)
```

### 🔧 Güncellenmiş Dosyalar

```
firebase databes rules.txt             (Firestore rules)
firebase storage rules.txt             (Storage rules - zaten kapsamlı)
lib/widgets/map/ring_seferleri_sheet.dart  (Pending upload sistemi)
lib/screens/admin/admin_panel_ekrani.dart  (Ring moderation tab)
```

---

## 🎯 Kullanım Akışı

### Öğrenci Açısından
```
Harita → Üniversite Seç → Ring Sefer Paneli
    ↓
"Güncel Tarifeyi Yükle" Buton
    ↓
Fotoğraf Seç (Galeri)
    ↓
✅ "Fotoğraf yüklendi! Admin incelemesinden sonra herkese görünür olacak"
    ↓
(Admin onaylanız kadar) Bekleyi bildirimi alır
    ↓
(Admin onaylarsa) "✅ Fotoğraf Onaylandı!" bildirimi
```

### Admin Açısından
```
Admin Panel → Ring Modü Sekmesi
    ↓
"Beklemede" Tab'ında yeni fotoğrafları gör
    ↓
Fotoğraf Önizleme + Detayları
    ↓
SEÇENEK 1: "Onayla" Butonu
    ├─ Uploader'a onay bildirimi
    ├─ Üniversite kullanıcılarına 🚌 bildirimi
    └─ Ring panelinde otomatik güncelleme
    
SEÇENEK 2: "Reddet" Butonu
    ├─ Sebep modal'ı açılır
    ├─ Uploader'a ret bildirimi (sebep ile)
    ├─ Storage dosyası silinir
    └─ Moderasyon log'a kaydedilir
```

---

## 📱 Bildirim Örnekleri

### Admin'e Bildirimi
```
Başlık: "📋 Yeni Ring Fotoğrafı İncelemesi Bekleniyor"
Mesaj: "İTÜ için Ahmet Yılmaz tarafından yeni bir ring/servis fotoğrafı yüklendi. Admin panelden inceleyebilirsin."
```

### Uploader'a Onay Bildirimi
```
Başlık: "✅ Fotoğraf Onaylandı"
Mesaj: "Yüklediğin İTÜ ring/servis fotoğrafı onaylandı! Harika iş çıkardın! 🎉"
```

### Uploader'a Red Bildirimi
```
Başlık: "⚠️ Fotoğraf Reddedildi"
Mesaj: "İTÜ için yüklediğin fotoğraf reddedildi. Sebep: Kalitesiz fotoğraf. Lütfen başka bir fotoğraf dene."
```

### Üniversite Kullanıcılarına Bildirimi
```
Başlık: "🚌 Yeni Ring Sefer Bilgisi"
Mesaj: "İTÜ için ring/servis tarifesi güncellendi (Üyeler: Ahmet Yılmaz)"
```

---

## 🔐 Firebase Deployment

### 1. Firestore Rules Güncelle
```
Firebase Console
→ Firestore Database
→ Rules Sekmesi
→ rulesleri_updated_rules.txt (firebase databes rules.txt) içeriğini yapıştır
→ Publish
```

### 2. Storage Rules Güncelle
```
Firebase Console
→ Storage
→ Rules Sekmesi
→ firebase storage rules.txt içeriğini yapıştır
→ Publish
```

### 3. Admin Kullanıcısı Ayarla
```
Firebase Console
→ Firestore Database
→ kullanicilar koleksiyonu
→ Admin kullanıcısı belgesinde:
   role: "admin"  (olmalı)
```

---

## 🧪 Test Kontrol Listesi

- [ ] Öğrenci yeni ring fotoğrafı yükleyebiliyor
- [ ] Admin'e pending foto bildirimi geliyor
- [ ] Admin "Onayla" basabiliyor
- [ ] Uploader'a ✅ bildirimi geliyor
- [ ] Üniversite kullanıcılarına 🚌 bildirimi geliyor
- [ ] Ring panelinde fotoğraf otomatik görünüyor
- [ ] Admin "Reddet" basabiliyor ve sebep girişi yapabiliyor
- [ ] Uploader'a ❌ bildirimi (sebep ile) geliyor
- [ ] Moderasyon log'da işlem kaydediliyor
- [ ] Reddedilen fotoğraf Storage'dan siliniyor

---

## 📊 Firestore Koleksiyon Yapısı

```
Firestore Database
├── pending_ring_photos/{photoId}
│   ├── universityName: "İTÜ"
│   ├── photoUrl: "https://..."
│   ├── storagePath: "pending_ring_photos/..."
│   ├── uploadedBy: "userId"
│   ├── uploaderName: "Ahmet Yılmaz"
│   ├── uploadedAt: Timestamp
│   ├── status: "pending" | "approved" | "rejected"
│   ├── approvedBy: "adminId" | null
│   ├── approvedAt: Timestamp | null
│   └── rejectionReason: "Sebep" | null
│
├── ulasim_bilgileri/{universityName}
│   ├── university: "İTÜ"
│   ├── imageUrl: "https://..."
│   ├── lastUpdated: Timestamp
│   ├── updatedBy: "userId"
│   ├── updaterName: "Ahmet Yılmaz"
│   ├── approvedBy: "adminId"
│   ├── approvedByName: "Admin Adı"
│   └── approvedAt: Timestamp
│
├── ring_photo_moderation/{logId}
│   ├── action: "approved" | "rejected"
│   ├── photoId: "..."
│   ├── universityName: "İTÜ"
│   ├── adminUserId: "..."
│   ├── adminName: "Admin Adı"
│   ├── reason: "Sebep" (rejected için)
│   └── timestamp: Timestamp
│
└── bildirimler/{notificationId}
    ├── userId: "..."
    ├── title: "..."
    ├── body: "..."
    ├── type: "ring_info_update" | "ring_photo_approved" | ...
    ├── createdAt: Timestamp
    ├── isRead: boolean
    └── actionUrl: "map://ring/..."
```

---

## 🎛️ Admin Panel Yeni Tab Detayları

### Ring Modü Sekmesi
- **Ikon:** 🚌 (Otobüs)
- **Alt Tablar:**
  1. **Beklemede** - Onay beklenen fotoğraflar
  2. **Onaylı** - Herkese açık hale getirilmiş fotoğraflar

### Beklemede Tab Özellikleri
- Fotoğraf grid/liste görünümü
- Her fotoğrafta:
  - Önizleme resmi
  - 🏫 Üniversite adı
  - Yükleyen kişinin adı
  - Yüklenme tarihi
  - ✅ "Onayla" Butonu (Yeşil)
  - ❌ "Reddet" Butonu (Kırmızı)

### Onaylı Tab Özellikleri
- Tüm onaylanmış fotoğraflar
- Her fotoğrafta:
  - Önizleme resmi
  - ✅ Üniversite adı
  - Yükleyen kişi adı
  - Onaylayan admin adı
  - Onay tarihi

---

## 🐛 Sık Sorulan Sorunlar

**S: Admin panelinde Ring Modü tab'ı neden görünmüyor?**
A: Kullanıcının `role: "admin"` olduğundan emin ol Firestore'da.

**S: Fotoğraf neden yüklenmiyor?**
A: 
- Dosya boyutu 10MB'den küçük mü?
- Dosya formatı resim mi (jpg, png)?
- Internet bağlantısı var mı?

**S: Bildirim neden gelmiyor?**
A:
- Firestore rules'ları yayımlandı mı?
- Kullanıcının `university` alanında doğru adı var mı?
- FCM token'ı güncel mi?

**S: Reddedilen fotoğraf yeniden yükleyebilir mi?**
A: Evet, öğrenci yeni fotoğraf seçip tekrar "Güncel Tarifeyi Yükle" yapabilir.

---

## 📞 Destek ve İletişim

Sorularınız veya sorunlarınız için lütfen admin panele yazın veya teknik ekiple iletişime geçin.

**Versiyon:** 1.0  
**Son Güncelleme:** 2025-12-04  
**Durum:** ✅ Hazır Dağıtım
