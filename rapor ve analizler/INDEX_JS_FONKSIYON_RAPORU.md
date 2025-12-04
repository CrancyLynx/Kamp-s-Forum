# Firebase Functions - Detaylı Fonksiyon Raporu
**Dosya:** `functions/index.js`  
**Tarih:** 4 Aralık 2025  
**Toplam Fonksiyon:** 32  
**Bölge:** `europe-west1`

---

## 📊 GENEL ÖZET

| Kategori | Sayı |
|----------|------|
| **HTTP Triggers** | 13 |
| **Firestore Triggers** | 11 |
| **Storage Triggers** | 1 |
| **Pub/Sub Triggers** | 2 |
| **Kütüphaneler** | 5 |

---

## 1️⃣ BİLDİRİM SİSTEMİ (Notification System)

### **sendPushNotification** ⭐ KRITIK
- **Trigger:** Firestore `bildirimler/{notificationId}` onCreate
- **Fonksiyon:** Push bildirimleri FCM ile gönderir
- **Güvenlik Kontrolleri:**
  - ✅ Kendi kendine bildirim engeli
  - ✅ Null/undefined kontrol
  - ✅ Engelleme listesi kontrolü
  - ✅ Duplicate kontrol (10 saniye)
  - ✅ **Rate limiting (3/dakika)** ⚠️ OPTIMIZE EDİLDİ
- **Android/iOS Desteği:** Evet
- **Geçersiz Token Temizliği:** Otomatik

**Sorun:** Rate limiting dakikada 3'e düşürüldü (quota tasarrufu)

---

## 2️⃣ KULLANICI YÖNETİMİ (User Management)

### **onUserAvatarUpdate**
- **Trigger:** Firestore `kullanicilar/{userId}` onUpdate
- **Fonksiyon:** Avatar değişimini gönderi ve yorumlara yansıtır
- **İşlem:** Batch update ile tüm içerikleri günceller
- **Quota:** CollectionGroup query kullanıyor

### **onUserCreated**
- **Trigger:** Firestore `kullanicilar/{userId}` onCreate
- **Fonksiyon:** Yeni kullanıcı varsayılan alanlarını oluşturur
- **Başlangıç Değerleri:**
  ```
  postCount: 0
  commentCount: 0
  likeCount: 0
  followerCount: 0
  followingCount: 0
  earnedBadges: []
  followers/following: []
  savedPosts: []
  isOnline: false
  status: "Unverified"
  role: "user"
  kayit_tarihi: serverTimestamp
  ```

### **logUserActivity**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Kullanıcı aktivitelerini loglar
- **Aktivite Türleri:** view_post, create_post, like, comment, vb.
- **Loglar:** `activity_logs` koleksiyonuna kaydedilir
- **İstatistik:** lastActive ve isOnline güncellenir

### **deleteUserAccount**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Hesap silme (Admin veya kendi hesabı)
- **Anonimleştirme:** Tüm gönderi ve yorumlar "Silinmiş Kullanıcı" hale getirilir
- **Storage:** Profil resmi silinir
- **Auth:** Firebase Auth'dan kullanıcı silinir
- **Batch İşlemi:** 500 belge batches

---

## 3️⃣ İÇERİK YÖNETİMİ (Content Management)

### **deletePost**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Gönderi silme (Yazar veya Admin)
- **Siler:**
  - Gönderi belgesini
  - Tüm yorumları
  - İlişkili bildirimleri
- **Günceller:** postCount -1

### **autoModerateContent** ⚠️ MODERASYON
- **Trigger:** Firestore `gonderiler/{postId}` onCreate
- **Kontroller:**
  1. Spam anahtar kelimeler (viagra, casino, bet, vb.)
  2. Kötü kelime (profanity) kontrol
- **Bulunursa:**
  - Gönderi gizlenir (visible: false)
  - Status: "pending_review"
  - **Uyarı mesajı:** Hangi kelimeler bulunduğu gösterilir ✅

### **moderateComment**
- **Trigger:** Firestore `gonderiler/{postId}/yorumlar/{commentId}` onCreate
- **Fonksiyon:** Yorum içeriğini kontrol eder
- **Kontrol:** Profanity check
- **Admin Alarmı:** Uygunsuz yorum algılanırsa

### **moderatePoll**
- **Trigger:** Firestore `anketler/{pollId}` onCreate
- **Kontroller:** Başlık, soru ve seçenekleri kontrol eder
- **Detaylı:** Her seçeneği ayrı ayrı analiz eder

### **moderateForumMessage**
- **Trigger:** Firestore `forumlar/{forumId}/mesajlar/{messageId}` onCreate
- **Fonksiyon:** Forum mesajlarını kontrol eder

---

## 4️⃣ MODERASYON SİSTEMİ (Moderation System)

### **checkAndFixContent**
- **Trigger:** HTTP onCall
- **Fonksiyon:** İçerik gönderilmeden önce kontrol eder
- **Desteklenen Türler:** post, comment, poll, forum_message
- **Döner:**
  ```json
  {
    "success": boolean,
    "message": string,
    "foundWords": [],
    "requiresModeration": boolean,
    "canPublish": boolean
  }
  ```

### **resubmitModeratedContent**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Bayraklanmış içeriği düzeltip yeniden gönderir
- **İşlem:**
  1. Düzeltilmiş metin kontrol edilir
  2. Geçerse yayınlanır
  3. Başarısızsa hata döner

---

## 5️⃣ PROFANITY LİSTESİ (Bad Words Filter) 🔴

### **Türkçe Ciddi Kötü Kelimeler:**
```
orospu, piç, bok, sikeyim, çüğü, şerefsiz, namussuz,
göt, sıç, sapık, pedofil, ensest
```

### **İngilizce Ciddi Kötü Kelimeler:**
```
fuck, shit, cunt, bastard, asshole, whore, bitch,
dick, prick, motherfucker
```

### **Spam Anahtar Kelimeler:**
```
viagra, casino, bet, click here, free money, xxx,
loto, iddia, at yarışı
```

### **Nefret Söylemi & Tehdit:**
```
terörist, öldür, bomba, silah, intihar
```

**ℹ️ Kaldırılan Hafif Kelimeler:**
- ❌ aptal
- ❌ sarışın
- ❌ hain
- ❌ klitoris
- ❌ penis
- ❌ vagina
- ❌ cock
- ❌ cocksucker
- ❌ ölüm

---

## 6️⃣ RESİM MODERASYONU (Image Moderation)

### **analyzeImageWithVision**
- **Teknoloji:** Google Cloud Vision API
- **Analiz:** SAFE_SEARCH_DETECTION
- **Döner:** adult, racy, violence, medical, spoof puanları

### **checkImageSafety**
- **Eşikler:**
  - Adult: 60% → 🚫 RED
  - Racy: 70% → 🚫 RED
  - Violence: 70% → 🚫 RED
  - Medical: 80%

### **moderateUploadedImage** 🖼️
- **Trigger:** Storage object onFinalize
- **Kontroller:**
  1. Dosya tipi (JPEG, PNG, GIF, WebP)
  2. Dosya boyutu (Max 10MB)
  3. Vision API ile güvenlik analizi
- **Uygunsuzsa:** Siler + Admin alarmı
- **Başarılıysa:** İzin verilir

### **analyzeImageBeforeUpload**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Upload öncesi ön kontrolü yapar
- **Kullanıcı Feedback:** Detaylı uyarı mesajı

### **reuploadAfterRejection**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Reddedilen resmi açıklama ile yeniden gönderir
- **İşlem:** Admin incelemesi için kuyruğa alır

---

## 7️⃣ TAKIP SİSTEMİ (Follow System)

### **followUser**
- **Trigger:** HTTP onCall
- **İşlem:**
  - Takip listesi güncellenir
  - Follower sayısı artırılır
  - Bildirim gönderilir
- **Batch:** Atomik işlem

### **unfollowUser**
- **Trigger:** HTTP onCall
- **İşlem:** Takipten çıkar ve sayıları günceller
- **Atomik:** Batch kullanır

---

## 8️⃣ BLOK SİSTEMİ (Block System)

### **blockUser**
- **Trigger:** HTTP onCall
- **İşlem:**
  1. Engelle listesine ekle
  2. Zaten takip ediyorsa takipten çıkar
- **Etki:** Engellenen kullanıcıdan bildirim alamaz

### **unblockUser**
- **Trigger:** HTTP onCall
- **İşlem:** Engel listesinden çıkar

---

## 9️⃣ BEĞEN SİSTEMİ (Like System)

### **likePost**
- **Trigger:** HTTP onCall
- **İşlem:**
  1. Like listesine ekle
  2. likeCount +1
  3. Post sahibine bildirim (kendiyse gönderme)
- **Kullanıcı:** kendi likeCount'u da artırılır

### **unlikePost**
- **Trigger:** HTTP onCall
- **İşlem:** Like kaldırır ve sayıları günceller

---

## 🔟 SINAV TAKVİMİ (Exam Calendar System)

### **scrapeOsymExams**
- **Fonksiyon:** ÖSYM websitesinden sınav tarihlerini çeker
- **Teknoloji:** Axios + Cheerio
- **Yıllar:** 2025, 2026
- **Sınavlar:** KPSS, YKS, ALES, DGS, TUS, DUS, YÖKDİL
- **URL Parsing:** HTML table'lardan veri çıkarır

### **updateExamDates**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Manuel olarak sınav tarihlerini günceller
- **Batch Update:** Firestore'da kaydedilir

### **scheduleExamDatesUpdate** ⏰
- **Trigger:** Pub/Sub (her gün 00:00 Türkiye saati)
- **Fonksiyon:** Otomatik sınav takvimi güncelleme
- **TimeZone:** Europe/Istanbul

---

## 1️⃣1️⃣ BİLDİRİM SAYACI (Notification Counter)

### **onNotificationWrite**
- **Trigger:** Firestore `bildirimler/{notificationId}` onWrite
- **İşlem:** unreadNotifications sayacını günceller
- **Kural:** Sadece okunmayan bildirimler sayılır

### **onChatWrite**
- **Trigger:** Firestore `sohbetler/{chatId}` onWrite
- **İşlem:** Her kullanıcının totalUnreadMessages'ı güncellenir
- **Detay:** unreadCount objesine göre işlem yapar

### **recalculateUserCounters**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Sayaçları yeniden hesaplar (Bakım)
- **Hesaplar:**
  - Okunmamış bildirim sayısı
  - Okunmamış mesaj sayısı
- **Güvenlik:** Sadece kendi counters'ını resetleyebilir

---

## 1️⃣2️⃣ OYUNLAŞTIRMA (Gamification System)

### **addXp** 🎮
- **Trigger:** HTTP onCall
- **XP Dağılımı:**
  - post_created: 10 XP
  - comment_created: 5 XP
  - comment_like: 1 XP
  - badge_unlock: 50 XP
- **Spam Kontrolü:** 5 dakika içinde 10 işlem limit
- **Multiplier:** Ardışık işlemlerde bonus (1.1x - 1.5x)
- **Level Up:** XP 100'e ulaşınca level artırılır
- **Rozet:** Level up'ında badge check edilir

### **checkAndAwardBadges** 🏆
- **Trigger:** HTTP onCall (addXp'den otomatik)
- **Rozet Şartları:** (18 farklı rozet)
  ```
  pioneer: 1+ gönderi
  commentator_rookie: 10+ yorum
  commentator_pro: 50+ yorum
  popular_author: 50+ like
  campus_phenomenon: 250+ like
  veteran: 50+ gönderi
  helper: 100+ yorum
  early_bird: 20+ gönderi
  question_master: 25+ gönderi
  problem_solver: 50+ yorum
  trending_topic: 100+ like
  curious: 100+ yorum
  loyal_member: 75+ yorum
  friendly: 60+ like
  influencer: 150+ like
  perfectionist: 30+ gönderi
  ```

---

## 1️⃣3️⃣ ARAMA VE İNDEKSLEME (Search & Indexing)

### **updateUserSearchIndex**
- **Trigger:** Firestore `kullanicilar/{userId}` onWrite
- **İşlem:**
  1. takmaAd'dan keywords çıkar
  2. ad'dan keywords çıkar
  3. universite'den keywords çıkar
- **Amaç:** Full-text search desteği

---

## 1️⃣4️⃣ İSTATİSTİKLER (Statistics)

### **calculateMonthlyStats** 📊
- **Trigger:** Pub/Sub (ayın 1. günü 00:00)
- **Hesaplar:**
  - Toplam kullanıcı
  - Aktif kullanıcı
  - Toplam gönderi
  - Toplam yorum
  - Toplam like
- **Depolama:** `platform_stats/{YYYY_MM}`

---

## 1️⃣5️⃣ VERI MİGRASYON (Data Migration)

### **migrateUserData**
- **Trigger:** HTTP onCall
- **Fonksiyon:** Eksik alanları tamamlar
- **Kontrol Edilen Alanlar:** (16 alan)
  ```
  postCount, commentCount, likeCount,
  followerCount, followingCount,
  followers, following, earnedBadges,
  savedPosts, isOnline, status,
  lastActive, blockedUsers, fcmTokens,
  unreadNotifications, totalUnreadMessages
  ```
- **Batch:** 100 kullanıcı seferde

---

## 1️⃣6️⃣ PASSİF KULLANICI TEMİZLİĞİ (Cleanup)

### **cleanupInactiveUsers** 🧹
- **Trigger:** Pub/Sub (günde bir kez 03:00)
- **Kural:** 30 gün inaktif kullanıcıları siler
- **Batch:** 100 kullanıcı seferde
- **isOnline:** false işaretlenir

---

## 1️⃣7️⃣ TOPLU E-POSTA (Batch Email)

### **sendBatchEmails**
- **Trigger:** HTTP onCall
- **Güvenlik:** Sadece Admin
- **Filtreler:**
  - isActive
  - universite
- **İşlem:** Sendgrid ile email gönderir (kod eksik)

---

## 1️⃣8️⃣ ÖNERİ ENGİNESİ (Suggestion Engine)

### **generatePersonalizedSuggestions**
- **Trigger:** HTTP onCall
- **Algoritma:**
  1. Takip edilen kullanıcıların takipçilerine öner
  2. Popüler gönderiyi öner (orderBy likeCount)
- **Limit:** 10 öneri

---

## ⚠️ SORUNLAR VE IYILEŞTIRMELER

### **Var Olan Sorunlar:**
1. ✅ **Rate Limit** - DÜŞÜRÜLDÜ (5→3/dakika)
2. ✅ **Hafif Kötü Kelimeler** - KALDIRILAN (aptal, sarışın, vb.)
3. ⚠️ **sendBatchEmails** - Sendgrid kodu eksik
4. ⚠️ **Vision API** - Hata durumunda resmi siliyoruz (katı)
5. ⚠️ **CollectionGroup Query** - postCnt fazla okuma işlemi

### **Yapılan İyileştirmeler:**
- ✅ Rate limiting limit() metodu ile optimize edildi
- ✅ Uyarı mesajları bulunan kelimeyi gösteriyor
- ✅ Profanity listesi sadece ciddi kelimeler içeriyor
- ✅ Batch işlemleri atomik yapılı

---

## 📈 QUOTA VE PERFORMANS

| Operasyon | Quota | Optimize |
|-----------|-------|----------|
| Read | Yüksek | ✅ limit() eklendi |
| Write | Orta | ✅ Batch kullanılıyor |
| Pub/Sub | Düşük | ✅ Sadece 2 trigger |
| Storage | Orta | ✅ Dosya boyutu kontrol |
| Vision API | Pahalı | ⚠️ Her upload kontrol |

---

## 🔐 GÜVENLİK ÖZETİ

✅ **İyi Uygulamalar:**
- Tüm fonksiyonlar checkAuth() ile korunuyor
- Rate limiting uygulanmış
- Batch işlemler atomik
- Spam kontrolü var
- Profanity filter aktif

⚠️ **Dikkat Edilmesi Gerekenler:**
- Vision API maliyeti yüksek (her image)
- Rate limit düşük olabilir (3/dakika)
- CollectionGroup queries pahalı

---

**Son Güncelleme:** 4 Aralık 2025
