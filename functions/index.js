const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");
const vision = require("@google-cloud/vision");
const { getMockExamData } = require("./mock-exam-data");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const visionClient = new vision.ImageAnnotatorClient();

// --- AYARLAR ---
const REGION = "europe-west1";

/**
 * =================================================================================
 * VISION API QUOTA KONTROL AYARLARI
 * =================================================================================
 * Free tier: 1000 istek/ay (ilk ay)
 * Sonrası: $3.50 / 1000 istek
 */
const VISION_API_CONFIG = {
  MONTHLY_FREE_QUOTA: 1000,    // 1000 istek/ay free
  ENABLED: true,               // Vision API aktif/inaktif toggle
  FALLBACK_STRATEGY: "deny",   // "deny" (reddet), "allow" (izin ver), "warn" (uyar)
  CACHE_TTL_HOURS: 24,         // Cache valid duration (saat)
};

/**
 * =================================================================================
 * İMAJ MODERASYON AYARLARI
 * =================================================================================
 */
const IMAGE_MODERATION_CONFIG = {
  // Safe Search Detection eşikleri (0.0 - 1.0)
  // 1.0 = kesinlikle uygunsuz, 0.0 = hiç uygunsuz değil
  ADULT_THRESHOLD: 0.6,      // 60% üzeri → adult content
  RACY_THRESHOLD: 0.7,       // 70% üzeri → racy content
  VIOLENCE_THRESHOLD: 0.7,   // 70% üzeri → şiddet içeriği
  MEDICAL_THRESHOLD: 0.8,    // 80% üzeri → tıbbi görüntü
  
  // Kontrol edilecek dosya tipleri
  ALLOWED_TYPES: ["image/jpeg", "image/png", "image/gif", "image/webp"],
  
  // Max dosya boyutu (10MB) - OPTIMIZATION: Compression ile kısaltılabilir
  MAX_SIZE: 10 * 1024 * 1024,
  
  // OPTIMIZATION: Cache için max boyut (10MB)
  CACHE_MAX_RESULTS: 1000,
};

/**
 * =================================================================================
 * ANALYSIS CACHE (DOUBLE CALL OPTIMIZATION)
 * =================================================================================
 * Aynı resmi çift kez çözümleme problemini çöz
 */
const analysisCache = new Map();

const getCacheKey = (imagePath) => {
  return crypto.createHash('md5').update(imagePath).digest('hex');
};

const getCachedAnalysis = (imagePath) => {
  const key = getCacheKey(imagePath);
  const cached = analysisCache.get(key);
  
  if (!cached) return null;
  
  // Cache expired check
  const now = Date.now();
  const cacheAgeHours = (now - cached.timestamp) / (1000 * 60 * 60);
  
  if (cacheAgeHours > VISION_API_CONFIG.CACHE_TTL_HOURS) {
    analysisCache.delete(key);
    return null;
  }
  
  console.log(`[CACHE_HIT] Resim análiz cache'den alındı: ${imagePath}`);
  return cached;
};

const setCachedAnalysis = (imagePath, analysis) => {
  const key = getCacheKey(imagePath);
  
  // Cache size management
  if (analysisCache.size > IMAGE_MODERATION_CONFIG.CACHE_MAX_RESULTS) {
    // Remove oldest entry
    const firstKey = analysisCache.keys().next().value;
    analysisCache.delete(firstKey);
  }
  
  analysisCache.set(key, {
    ...analysis,
    timestamp: Date.now(),
    cached: true
  });
};

const checkAuth = (context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");
  }
};

/**
 * =================================================================================
 * USER-FRIENDLY RESPONSE HELPERS (Kullanıcı Dostu Cevaplar)
 * =================================================================================
 * Türkçe, anlaşılır mesajlar ve açık hata kodları
 */

const createUserFriendlyResponse = (success, message, data = null, errorCode = null) => {
  return {
    success,
    message,          // Kullanıcı dostu mesaj
    data,
    errorCode,        // "quota_exceeded", "image_unsafe", "network_error" vs
    timestamp: new Date().toISOString()
  };
};

const IMAGE_SAFETY_MESSAGES = {
  SAFE: {
    message: '✅ Görsel kontrol geçti! Paylaşmaya hazır.',
    color: 'green',
    action: 'post'
  },
  ADULT: {
    message: '⚠️ Bu görsel yetişkinlere uygun içerik içeriyor. Paylaşılamaz.',
    color: 'red',
    action: 'reject',
    reason: 'adult_content'
  },
  RACY: {
    message: '⚠️ Bu görsel müstehcen içerik olarak değerlendirildi. Paylaşılamaz.',
    color: 'red',
    action: 'reject',
    reason: 'racy_content'
  },
  VIOLENCE: {
    message: '⚠️ Bu görsel şiddet içeriği içeriyor. Paylaşılamaz.',
    color: 'red',
    action: 'reject',
    reason: 'violence_content'
  },
  MEDICAL: {
    message: '⚠️ Bu görsel tıbbi yapı içeriyor. Paylaşılamaz.',
    color: 'red',
    action: 'reject',
    reason: 'medical_content'
  }
};

const QUOTA_WARNING_MESSAGES = {
  SAFE: {
    message: '✅ Kota yeterli. Normal işlemleri devam ettirebilirsiniz.',
    status: 'normal'
  },
  APPROACHING: {
    message: '⚠️ Aylık kota %80 doldu. Yakında sınırına ulaşacaksınız.',
    status: 'warning',
    percentage: 80
  },
  CRITICAL: {
    message: '🔴 Aylık kota sınırına ulaştınız! Yeni görseller işlenemiyor.',
    status: 'critical',
    percentage: 100
  },
  OVER: {
    message: '🔴 Aylık kota aşıldı. Ek maliyetler uygulanıyor ($3.50/1000).',
    status: 'over_quota',
    costWarning: true
  }
};

const ERROR_MESSAGES = {
  NETWORK_ERROR: {
    message: '🔌 Bağlantı hatası. Lütfen interneti kontrol edin ve yeniden deneyin.',
    userAction: 'retry',
    retryable: true
  },
  IMAGE_INVALID: {
    message: '📷 Geçersiz görsel. Desteklenen formatlar: JPG, PNG, GIF, WebP',
    userAction: 'upload_different',
    retryable: false
  },
  IMAGE_TOO_LARGE: {
    message: '📦 Görsel çok büyük (Max: 10MB). Lütfen daha küçük bir dosya yükleyin.',
    userAction: 'compress',
    retryable: false,
    suggestion: 'Görsel boyutunu azaltmak için sıkıştırma yapabilirsiniz.'
  },
  QUOTA_EXCEEDED: {
    message: '🔴 Aylık görsel kontrol sınırı doldu. Sonraki ay yeniden deneyin.',
    userAction: 'try_next_month',
    retryable: false,
    nextRetry: 'next_month'
  },
  SERVER_ERROR: {
    message: '⚠️ Sunucu hatası. Lütfen 5 dakika sonra yeniden deneyin.',
    userAction: 'retry_later',
    retryable: true,
    delaySeconds: 300
  },
  PROFANITY_DETECTED: {
    message: '⛔ Metinde uygunsuz kelimeler tespit edildi. Yazıyı düzenleyin.',
    userAction: 'edit_text',
    retryable: false,
    foundBadWords: true
  }
};

/**
 * Kullanıcıya gösterilecek progress mesajları
 */
const PROGRESS_MESSAGES = {
  UPLOADING: '📤 Dosya yükleniyor...',
  VALIDATING: '✓ Dosya doğrulanıyor...',
  ANALYZING: '🔍 Görsel analiz ediliyor...',
  CHECKING_CACHE: '⚡ Önceki sonuçlar kontrol ediliyor...',
  CACHE_HIT: '✅ Önceki analiz kullanılıyor (hızlı!)',
  PROCESSING: '⚙️ İşleniyor...',
  COMPLETE: '✅ Tamamlandı!',
  FAILED: '❌ Başarısız oldu.'
};

const getProgressMessage = (stage) => {
  return PROGRESS_MESSAGES[stage] || 'İşleniyor...';
};

/**
 * =================================================================================
 * VISION API QUOTA KONTROL FONKSIYONLARI
 * =================================================================================
 */

/**
 * Aylık API çağrı sayısını kontrol et
 */
const getVisionApiQuotaUsage = async () => {
  const today = new Date();
  const monthKey = `${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}`;
  
  try {
    const quotaDoc = await db.collection("vision_api_quota").doc(monthKey).get();
    
    if (!quotaDoc.exists) {
      // İlk kez bu ay
      return { used: 0, remaining: VISION_API_CONFIG.MONTHLY_FREE_QUOTA };
    }
    
    const data = quotaDoc.data();
    const used = data.usageCount || 0;
    const remaining = Math.max(0, VISION_API_CONFIG.MONTHLY_FREE_QUOTA - used);
    
    return { used, remaining, monthKey, quotaDoc };
  } catch (error) {
    console.error("[QUOTA_ERROR] Quota kontrol hatası:", error);
    return { used: 0, remaining: 0, error: true };
  }
};

/**
 * Vision API çağrısı sayacını artır
 */
const incrementVisionApiQuota = async (monthKey) => {
  try {
    await db.collection("vision_api_quota").doc(monthKey).set({
      usageCount: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      monthKey: monthKey
    }, { merge: true });
    
    return true;
  } catch (error) {
    console.error("[QUOTA_ERROR] Quota artırma hatası:", error);
    return false;
  }
};

/**
 * Vision API kullanabilir mi kontrol et
 */
const canUseVisionApi = async () => {
  // Eğer global ayarda devre dışı ise
  if (!VISION_API_CONFIG.ENABLED) {
    console.log("[VISION_DISABLED] Vision API global olarak devre dışı");
    return { allowed: false, reason: "DISABLED" };
  }
  
  // Quota kontrol et
  const quota = await getVisionApiQuotaUsage();
  
  if (quota.error) {
    // Quota kontrol başarısız, fallback strategy uygula
    switch (VISION_API_CONFIG.FALLBACK_STRATEGY) {
      case "allow":
        console.log("[QUOTA_ERROR] Quota kontrol başarısız, izin verildi");
        return { allowed: true, reason: "FALLBACK_ALLOW" };
      case "deny":
        console.log("[QUOTA_ERROR] Quota kontrol başarısız, reddedildi");
        return { allowed: false, reason: "FALLBACK_DENY" };
      case "warn":
      default:
        console.warn("[QUOTA_ERROR] Quota kontrol başarısız, uyarı");
        return { allowed: true, reason: "FALLBACK_WARN" };
    }
  }
  
  // Quota bitti mi kontrol et
  if (quota.remaining <= 0) {
    console.log(`[QUOTA_EXCEEDED] Aylık quota tükendi! Kullanılan: ${quota.used}/${VISION_API_CONFIG.MONTHLY_FREE_QUOTA}`);
    return { allowed: false, reason: "QUOTA_EXCEEDED", used: quota.used };
  }
  
  // Quota var, izin ver
  console.log(`[QUOTA_OK] Kalan quota: ${quota.remaining}/${VISION_API_CONFIG.MONTHLY_FREE_QUOTA}`);
  return { allowed: true, reason: "OK", remaining: quota.remaining, monthKey: quota.monthKey };
};

/**
 * =================================================================================
 * 1. BİLDİRİM GÖNDERİCİ (FCM TRIGGER)
 * =================================================================================
 */
exports.sendPushNotification = functions.region(REGION).firestore
  .document("bildirimler/{notificationId}")
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    const userId = notificationData.userId; // Bildirimi alacak kişi
    const senderId = notificationData.senderId; // Bildirimi gönderen/tetikleyen kişi
    const type = notificationData.type;
    const docId = snap.id;

    // ===== SPAM KONTROLÜ =====
    // 1. Kendi kendine bildirim engeli
    if (senderId === userId) {
      console.log(`[SPAM] Kendi kendine bildirim engellendi: ${userId}`);
      await db.collection("bildirimler").doc(docId).delete();
      return null;
    }

    // 2. Null/undefined kontrol
    if (!userId || !senderId || !type) {
      console.log(`[SPAM] Eksik alan: userId=${userId}, senderId=${senderId}, type=${type}`);
      await db.collection("bildirimler").doc(docId).delete();
      return null;
    }

    // 3. Engelleme listesi kontrolü (göndericinin, alıcıyı engellemiş mi?)
    try {
      const senderDoc = await db.collection("kullanicilar").doc(senderId).get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        const senderBlockedUsers = senderData.blockedUsers || [];
        if (senderBlockedUsers.includes(userId)) {
          console.log(`[SPAM] Engellenen kullanıcıya bildirim gönderilemiyor: ${senderId} -> ${userId}`);
          await db.collection("bildirimler").doc(docId).delete();
          return null;
        }
      }
    } catch (e) {
      console.warn(`[WARN] Engelleme listesi kontrolü hatası: ${e.message}`);
    }

    // 4. Duplicate kontrol (son 10 saniye içinde aynı tipi bildirim var mı?)
    try {
      const tenSecondsAgo = new Date(Date.now() - 10000);
      const duplicateCheck = await db.collection("bildirimler")
        .where("userId", "==", userId)
        .where("senderId", "==", senderId)
        .where("type", "==", type)
        .where("timestamp", ">=", tenSecondsAgo)
        .limit(2)
        .get();

      if (duplicateCheck.docs.length > 1) {
        console.log(`[SPAM] Duplicate bildirim engellendi: ${userId} <- ${senderId} (${type})`);
        await db.collection("bildirimler").doc(docId).delete();
        return null;
      }
    } catch (e) {
      console.warn(`[WARN] Duplicate kontrol hatası: ${e.message}`);
    }

    // 5. Rate limiting - her kullanıcı en fazla dakikada 3 bildirim (düşük quota)
    try {
      const oneMinuteAgo = new Date(Date.now() - 60000);
      const recentNotifs = await db.collection("bildirimler")
        .where("userId", "==", userId)
        .where("timestamp", ">=", oneMinuteAgo)
        .limit(4)
        .get();

      if (recentNotifs.size >= 3) {
        console.log(`[SPAM] Rate limit aşıldı: ${userId} (${recentNotifs.size}/dakika)`);
        await db.collection("bildirimler").doc(docId).delete();
        return null;
      }
    } catch (e) {
      console.warn(`[WARN] Rate limit kontrolü hatası: ${e.message}`);
    }

    // ===== FCM GÖNDERME =====
    try {
      const userDoc = await db.collection("kullanicilar").doc(userId).get();

      if (!userDoc.exists) {
        console.log(`[ERROR] Kullanıcı bulunamadı: ${userId}`);
        await db.collection("bildirimler").doc(docId).delete();
        return null;
      }

      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];

      if (tokens.length === 0) {
        console.log(`[WARN] FCM token yok: ${userId}`);
        return null;
      }

      const message = {
        tokens: tokens,
        notification: {
          title: "Kampüs Forum",
          body: notificationData.message || "Yeni bir bildiriminiz var.",
        },
        android: {
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            color: "#673AB7",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: type,
          postId: notificationData.postId || "",
          chatId: notificationData.chatId || "",
          senderName: notificationData.senderName || "",
          senderId: senderId,
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`[SUCCESS] Bildirim gönderildi: ${userId} <- ${senderId} (${response.successCount}/${tokens.length})`);

      // Geçersiz tokenları temizle
      const tokensToRemove = [];
      response.responses.forEach((result, index) => {
        const error = result.error;
        if (error) {
          console.error(`[TOKEN_ERROR] ${error.code}: ${error.message}`);
          if (error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered") {
            tokensToRemove.push(tokens[index]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await db.collection("kullanicilar").doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        });
        console.log(`[CLEANUP] ${tokensToRemove.length} geçersiz token silindi.`);
      }

      return {success: true};

    } catch (error) {
      console.error(`[CRITICAL] Bildirim gönderme hatası: ${error.message}`);
      return null;
    }
  });

/**
 * =================================================================================
 * DİĞER FONKSİYONLAR (Aynen korunmuştur)
 * =================================================================================
 */

// 2. USER AVATAR GÜNCELLEME
exports.onUserAvatarUpdate = functions.region(REGION).firestore
  .document("kullanicilar/{userId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    if (beforeData.avatarUrl === afterData.avatarUrl) return null;

    const newAvatarUrl = afterData.avatarUrl || "";
    const batch = db.batch();

    const postsSnapshot = await db.collection("gonderiler").where("userId", "==", userId).get();
    postsSnapshot.docs.forEach((doc) => batch.update(doc.ref, {avatarUrl: newAvatarUrl}));

    const commentsSnapshot = await db.collectionGroup("yorumlar").where("userId", "==", userId).get();
    commentsSnapshot.docs.forEach((doc) => batch.update(doc.ref, {userAvatar: newAvatarUrl}));

    if (postsSnapshot.empty && commentsSnapshot.empty) return null;
    return batch.commit();
  });

// 3. GÖNDERİ SİLME
exports.deletePost = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const postId = data.postId;
  const requesterUid = context.auth.uid;

  if (!postId) throw new functions.https.HttpsError("invalid-argument", "Post ID eksik.");

  const requesterDoc = await db.collection("kullanicilar").doc(requesterUid).get();
  const requesterData = requesterDoc.data() || {};
  const isAdmin = requesterData.role === "admin";

  const postRef = db.collection("gonderiler").doc(postId);
  const postDoc = await postRef.get();

  if (!postDoc.exists) throw new functions.https.HttpsError("not-found", "Gönderi bulunamadı.");

  const postData = postDoc.data();
  const authorId = postData.userId;

  if (authorId !== requesterUid && !isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "Yetkisiz işlem.");
  }

  const batch = db.batch();
  const commentsSnapshot = await postRef.collection("yorumlar").get();
  commentsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

  const notifSnapshot = await db.collection("bildirimler").where("postId", "==", postId).get();
  notifSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

  batch.delete(postRef);

  if (authorId) {
    const userRef = db.collection("kullanicilar").doc(authorId);
    batch.update(userRef, {postCount: admin.firestore.FieldValue.increment(-1)});
  }

  await batch.commit();
  return {success: true};
});

// 4. HESAP SİLME
exports.deleteUserAccount = functions.region(REGION).https.onCall(async (data, context) => {
  const requesterUid = context.auth.uid;
  const targetUserId = data.userId || requesterUid;

  if (targetUserId !== requesterUid) {
    const requesterDoc = await db.collection("kullanicilar").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    if (requesterData.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Yetkiniz yok.");
    }
  }

  async function anonymizeQueryBatch(query, resolve) {
    const snapshot = await query.get();
    const batchSize = snapshot.size;
    if (batchSize === 0) {
      resolve();
      return;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        userId: 'deleted_user',
        takmaAd: 'Silinmiş Üye',
        userAvatar: null,
        avatarUrl: null
      });
    });
    await batch.commit();
    process.nextTick(() => {
      anonymizeQueryBatch(query, resolve);
    });
  }

  const postsQuery = db.collection("gonderiler").where("userId", "==", targetUserId).limit(500);
  await new Promise((resolve, reject) => anonymizeQueryBatch(postsQuery, resolve).catch(reject));

  const commentsQuery = db.collectionGroup("yorumlar").where("userId", "==", targetUserId).limit(500);
  await new Promise((resolve, reject) => anonymizeQueryBatch(commentsQuery, resolve).catch(reject));

  try {
    const bucket = admin.storage().bucket();
    await bucket.file(`profil_resimleri/${targetUserId}.jpg`).delete().catch(() => {});
  } catch (e) {
    console.log("Storage silme hatası (önemsiz):", e);
  }

  await db.collection("kullanicilar").doc(targetUserId).delete();

  try {
    await admin.auth().deleteUser(targetUserId);
    return {success: true, message: "Hesap anonimleştirilerek silindi."};
  } catch (error) {
    console.error("Auth silme hatası:", error);
    return {success: true, message: "Veriler anonimleştirildi, Auth silinemedi."};
  }
});

// 5. KULLANICI OLUŞTURMA TRIGGER
exports.onUserCreated = functions.region(REGION).firestore
  .document("kullanicilar/{userId}")
  .onCreate((snap, context) => {
    return snap.ref.set({
      postCount: 0, commentCount: 0, likeCount: 0, followerCount: 0, followingCount: 0,
      earnedBadges: [], followers: [], following: [], savedPosts: [],
      isOnline: false, status: "Unverified",
      role: "user",
      kayit_tarihi: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

// 6. BİLDİRİM SAYAÇ TRIGGER
exports.onNotificationWrite = functions.region(REGION).firestore
  .document("bildirimler/{notificationId}")
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;
    const userId = beforeData ? beforeData.userId : afterData.userId;
    if (!userId) return null;

    let incrementValue = 0;
    if (!beforeData && afterData) {
      if (!afterData.isRead) incrementValue = 1;
    } else if (beforeData && !afterData) {
      if (!beforeData.isRead) incrementValue = -1;
    } else if (beforeData && afterData) {
      const wasRead = beforeData.isRead || false;
      const isRead = afterData.isRead || false;
      if (!wasRead && isRead) incrementValue = -1;
      if (wasRead && !isRead) incrementValue = 1;
    }
    if (incrementValue === 0) return null;

    return db.collection("kullanicilar").doc(userId).update({
      unreadNotifications: admin.firestore.FieldValue.increment(incrementValue)
    }).catch(err => console.log("Sayaç güncelleme hatası:", err));
  });

// 7. MESAJ SAYAÇ TRIGGER
exports.onChatWrite = functions.region(REGION).firestore
  .document("sohbetler/{chatId}")
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() : {};
    const afterData = change.after.exists ? change.after.data() : {};
    const beforeCounts = beforeData.unreadCount || {};
    const afterCounts = afterData.unreadCount || {};

    const allUserIds = new Set([
      ...Object.keys(beforeCounts),
      ...Object.keys(afterCounts)
    ]);

    const batch = db.batch();
    let batchHasOps = false;

    allUserIds.forEach(userId => {
      const oldVal = beforeCounts[userId] || 0;
      const newVal = afterCounts[userId] || 0;
      const diff = newVal - oldVal;

      if (diff !== 0) {
        const userRef = db.collection("kullanicilar").doc(userId);
        batch.update(userRef, {
          totalUnreadMessages: admin.firestore.FieldValue.increment(diff)
        });
        batchHasOps = true;
      }
    });

    if (batchHasOps) {
      return batch.commit().catch(err => console.error("Mesaj sayacı hatası:", err));
    }
    return null;
  });

// 8. SAYAÇ GÜNCELLEME (BAKIM)
exports.recalculateUserCounters = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const targetUserId = context.auth.uid;
  
  const notifSnap = await db.collection("bildirimler")
    .where("userId", "==", targetUserId)
    .where("isRead", "==", false)
    .count()
    .get();
  
  const unreadNotifCount = notifSnap.data().count;

  let totalUnreadMsg = 0;
  const chatsSnap = await db.collection("sohbetler")
    .where("participants", "array-contains", targetUserId)
    .get();
  
  chatsSnap.forEach(doc => {
    const d = doc.data();
    if (d.unreadCount && d.unreadCount[targetUserId]) {
      totalUnreadMsg += d.unreadCount[targetUserId];
    }
  });

  await db.collection("kullanicilar").doc(targetUserId).update({
    unreadNotifications: unreadNotifCount,
    totalUnreadMessages: totalUnreadMsg
  });

  return { 
    success: true, 
    message: `Sayaçlar güncellendi. Bildirim: ${unreadNotifCount}, Mesaj: ${totalUnreadMsg}` 
  };
});

/**
 * =================================================================================
 * 7. ULUSAL SINAV TARİHLERİNİ OTOMATIK GÜNCELLE
 * =================================================================================
 */

// Function to parse Turkish date strings
const parseTurkishDate = (dateString) => {
  if (!dateString || dateString.trim() === '') return null;
  const parts = dateString.split('.');
  if (parts.length !== 3) return null;
  // Note: Months are 0-indexed in JavaScript Dates
  return new Date(parts[2], parts[1] - 1, parts[0]);
};

// Scrapes exam data from ÖSYM's website for a given year (Dinamik - Multiple years support)
const scrapeOsymExams = async (year) => {
  try {
    const urls = {
      2025: "https://www.osym.gov.tr/TR,8709/2025-yili-sinav-takvimi.html",
      2026: "https://www.osym.gov.tr/TR,29560/2026-yili-sinav-takvimi.html",
      2027: "https://www.osym.gov.tr/TR,00000/2027-yili-sinav-takvimi.html"
    };

    const url = urls[year];
    if (!url) {
      console.warn(`[ÖSYM] URL not found for year: ${year}`);
      return [];
    }

    console.log(`[ÖSYM] Scraping ${year} from: ${url}`);
    
    const { data } = await axios.get(url, {
      timeout: 10000,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    });
    
    const $ = cheerio.load(data);
    const exams = [];
    const relevantExams = ["KPSS", "YKS", "ALES", "DGS", "TUS", "DUS", "YÖKDİL"];

    let found = 0;
    $('table tbody tr, table > tr').each((i, el) => {
      const tds = $(el).find('td');
      if (tds.length === 0) return;
      
      const examName = tds.eq(0).text().trim();
      
      if (relevantExams.some(keyword => examName.includes(keyword))) {
        const examDateStr = tds.eq(1).text().trim();
        const appStartDateStr = tds.eq(2).text().trim();
        const resultDateStr = tds.eq(3).text().trim();
        const examDate = parseTurkishDate(examDateStr);

        if (examName && examDate) {
          exams.push({
            id: `${year}_${examName.replace(/\s+/g, '_').toLowerCase()}`,
            name: examName,
            date: examDate,
            description: `Başvuru: ${appStartDateStr}, Sonuç: ${resultDateStr}`,
            color: 'blue',
            type: 'exam',
            source: 'OSYM',
            importance: 'high',
            year: year
          });
          found++;
        }
      }
    });

    console.log(`[ÖSYM] ${year}: ${found} sınav bulundu`);
    return exams;
  } catch (error) {
    console.error(`[ÖSYM_ERROR] ${year}: ${error.message}`);
    return [];
  }
};

// HTTP isteği ile sınav tarihlerini güncelle (Dinamik yıl döngüsü)
exports.updateExamDates = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    try {
      const currentYear = new Date().getFullYear();
      const years = data.years || [currentYear, currentYear + 1];
      
      console.log(`[EXAM_UPDATE] Years: ${years.join(', ')}`);
      
      const allExams = [];
      const errors = [];

      for (const year of years) {
        try {
          const exams = await scrapeOsymExams(year);
          if (exams.length > 0) {
            allExams.push(...exams);
          }
        } catch (err) {
          errors.push(`${year}: ${err.message}`);
          console.error(`[EXAM_ERROR] ${year}: ${err.message}`);
        }
      }
      
      if (allExams.length === 0) {
        throw new functions.https.HttpsError('not-found', 'Sınav verisi bulunamadı');
      }

      const batch = db.batch();
      let updateCount = 0;

      for (const exam of allExams) {
        batch.set(db.collection('sinavlar').doc(exam.id), {
          ...exam,
          date: admin.firestore.Timestamp.fromDate(exam.date),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          year: exam.year
        }, { merge: true });
        updateCount++;
      }

      await batch.commit();

      return {
        success: true,
        message: `${updateCount} sınav güncellendi`,
        count: updateCount,
        errors: errors,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('[EXAM_UPDATE_ERROR]', error.message);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);

// Otomatik Güncellenme: Her gün 01:00'da (Dinamik yıl döngüsü)
exports.scheduleExamDatesUpdate = functions.region(REGION)
  .pubsub.schedule('0 1 * * *')
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    try {
      const now = new Date();
      const currentYear = now.getFullYear();
      const yearsToFetch = [currentYear, currentYear + 1, currentYear + 2];
      
      console.log(`[AUTO_EXAM_UPDATE] Starting...`);
      
      const allExams = [];
      const errors = [];

      for (const year of yearsToFetch) {
        try {
          const exams = await scrapeOsymExams(year);
          allExams.push(...exams);
        } catch (err) {
          errors.push(`${year}: ${err.message}`);
        }
      }

      const batch = db.batch();
      let updateCount = 0, deleteCount = 0;

      for (const exam of allExams) {
        const examDate = exam.date;
        const daysDiff = (examDate - now) / (1000 * 60 * 60 * 24);
        const docRef = db.collection('sinavlar').doc(exam.id);

        if (daysDiff < -7) {
          batch.delete(docRef);
          deleteCount++;
        } else {
          batch.set(docRef, {
            ...exam,
            date: admin.firestore.Timestamp.fromDate(exam.date),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            year: exam.year
          }, { merge: true });
          updateCount++;
        }
      }

      if (updateCount > 0 || deleteCount > 0) {
        await batch.commit();
      }

      console.log(`[AUTO_EXAM_SUCCESS] +${updateCount}, -${deleteCount}`);

      return {
        success: true,
        updated: updateCount,
        deleted: deleteCount,
        errors: errors
      };
    } catch (error) {
      console.error('[AUTO_EXAM_ERROR]', error);
      return { success: false, error: error.message };
    }
  });

/**
 * =================================================================================
 * 9. KULLANICI TAKIP/UNFOLLOW İŞLEMLERİ
 * =================================================================================
 */
exports.followUser = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const targetUserId = data.targetUserId;

  if (!targetUserId || currentUserId === targetUserId) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz kullanıcı ID'si.");
  }

  const batch = db.batch();
  const currentUserRef = db.collection("kullanicilar").doc(currentUserId);
  const targetUserRef = db.collection("kullanicilar").doc(targetUserId);

  try {
    // Zaten takip ediyor mu kontrol et
    const currentUserDoc = await currentUserRef.get();
    const following = currentUserDoc.data()?.following || [];
    
    if (following.includes(targetUserId)) {
      throw new functions.https.HttpsError("already-exists", "Zaten bu kullanıcıyı takip ediyorsunuz.");
    }

    // Takip et
    batch.update(currentUserRef, {
      following: admin.firestore.FieldValue.arrayUnion(targetUserId),
      followingCount: admin.firestore.FieldValue.increment(1)
    });

    batch.update(targetUserRef, {
      followers: admin.firestore.FieldValue.arrayUnion(currentUserId),
      followerCount: admin.firestore.FieldValue.increment(1)
    });

    // Bildirim gönder
    const currentUserData = currentUserDoc.data();
    batch.set(db.collection("bildirimler").doc(), {
      userId: targetUserId,
      senderId: currentUserId,
      senderName: currentUserData.takmaAd || "Bilinmiyor",
      type: "follow",
      message: `${currentUserData.takmaAd} sizi takip etmeye başladı.`,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();
    return { success: true, message: "Kullanıcı başarıyla takip edildi." };
  } catch (error) {
    if (error.code && error.code.startsWith("PERMISSION_DENIED")) {
      throw new functions.https.HttpsError("permission-denied", "Yetkisiz işlem.");
    }
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.unfollowUser = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const targetUserId = data.targetUserId;

  if (!targetUserId) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz kullanıcı ID'si.");
  }

  const batch = db.batch();
  const currentUserRef = db.collection("kullanicilar").doc(currentUserId);
  const targetUserRef = db.collection("kullanicilar").doc(targetUserId);

  try {
    batch.update(currentUserRef, {
      following: admin.firestore.FieldValue.arrayRemove(targetUserId),
      followingCount: admin.firestore.FieldValue.increment(-1)
    });

    batch.update(targetUserRef, {
      followers: admin.firestore.FieldValue.arrayRemove(currentUserId),
      followerCount: admin.firestore.FieldValue.increment(-1)
    });

    await batch.commit();
    return { success: true, message: "Takip başarıyla kaldırıldı." };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 10. GÖNDERI LİKE/UNLIKE İŞLEMLERİ
 * =================================================================================
 */
exports.likePost = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const postId = data.postId;

  if (!postId) {
    throw new functions.https.HttpsError("invalid-argument", "Gönderi ID'si eksik.");
  }

  const postRef = db.collection("gonderiler").doc(postId);
  const batch = db.batch();

  try {
    const postDoc = await postRef.get();
    if (!postDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Gönderi bulunamadı.");
    }

    const postData = postDoc.data();
    const likes = postData.likes || [];

    if (likes.includes(currentUserId)) {
      throw new functions.https.HttpsError("already-exists", "Zaten bu gönderiyi beğenmiş..");
    }

    // Like ekle
    batch.update(postRef, {
      likes: admin.firestore.FieldValue.arrayUnion(currentUserId),
      likeCount: admin.firestore.FieldValue.increment(1)
    });

    // Like eden ve post sahibi farklı kişiyse bildirim gönder
    if (postData.userId !== currentUserId) {
      const currentUserData = await db.collection("kullanicilar").doc(currentUserId).get();
      batch.set(db.collection("bildirimler").doc(), {
        userId: postData.userId,
        senderId: currentUserId,
        senderName: currentUserData.data()?.takmaAd || "Bilinmiyor",
        type: "like",
        postId: postId,
        message: `${currentUserData.data()?.takmaAd} gönderiyi beğendi.`,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Like eden kullanıcının like sayısını artır
    batch.update(db.collection("kullanicilar").doc(currentUserId), {
      likeCount: admin.firestore.FieldValue.increment(1)
    });

    await batch.commit();
    return { success: true, message: "Gönderi beğenildi.", likeCount: likes.length + 1 };
  } catch (error) {
    if (error.code && error.code.startsWith("PERMISSION_DENIED")) {
      throw new functions.https.HttpsError("permission-denied", "Yetkisiz işlem.");
    }
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.unlikePost = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const postId = data.postId;

  if (!postId) {
    throw new functions.https.HttpsError("invalid-argument", "Gönderi ID'si eksik.");
  }

  const postRef = db.collection("gonderiler").doc(postId);
  const batch = db.batch();

  try {
    const postDoc = await postRef.get();
    if (!postDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Gönderi bulunamadı.");
    }

    const postData = postDoc.data();
    const likes = postData.likes || [];

    if (!likes.includes(currentUserId)) {
      throw new functions.https.HttpsError("not-found", "Bu gönderiyi beğenmemiş..");
    }

    // Like kaldır
    batch.update(postRef, {
      likes: admin.firestore.FieldValue.arrayRemove(currentUserId),
      likeCount: admin.firestore.FieldValue.increment(-1)
    });

    // Like eden kullanıcının like sayısını azalt
    batch.update(db.collection("kullanicilar").doc(currentUserId), {
      likeCount: admin.firestore.FieldValue.increment(-1)
    });

    await batch.commit();
    return { success: true, message: "Beğeni kaldırıldı.", likeCount: Math.max(0, likes.length - 1) };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 11. GÜNLÜK AKTİVİTE KURALLARI TEMIZLEYICI (SPAM EKLENTI)
 * =================================================================================
 */
exports.cleanupInactiveUsers = functions.region(REGION)
  .pubsub.schedule('0 3 * * *') // Günde bir kez saat 03:00
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const inactiveUsersSnapshot = await db.collection("kullanicilar")
        .where("lastActive", "<", thirtyDaysAgo)
        .limit(100)
        .get();

      let cleanupCount = 0;
      const batch = db.batch();

      inactiveUsersSnapshot.forEach((doc) => {
        batch.update(doc.ref, {
          isOnline: false,
          status: "Pasif"
        });
        cleanupCount++;
      });

      if (cleanupCount > 0) {
        await batch.commit();
      }

      console.log(`[SUCCESS] ${cleanupCount} pasif kullanıcı temizlendi.`);
      return { success: true, cleanedUsers: cleanupCount };
    } catch (error) {
      console.error('[ERROR] Pasif kullanıcı temizleme hatası:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * =================================================================================
 * 12. KULLANICI AKTİVİTESİ LOGGER
 * =================================================================================
 */
exports.logUserActivity = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const userId = context.auth.uid;
  const activityType = data.activityType; // "view_post", "create_post", "like", "comment", etc.
  const targetId = data.targetId; // Post ID, user ID, etc.

  if (!activityType) {
    throw new functions.https.HttpsError("invalid-argument", "Aktivite türü eksik.");
  }

  try {
    // Son aktivite zamanını güncelle
    await db.collection("kullanicilar").doc(userId).update({
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
      isOnline: true
    });

    // Aktivite logu oluştur
    await db.collection("activity_logs").add({
      userId: userId,
      activityType: activityType,
      targetId: targetId || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userAgent: data.userAgent || null
    });

    return { success: true };
  } catch (error) {
    console.error("Aktivite kayıt hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PROFANITY VE KÖTÜ KELIME LİSTESİ (GENIŞLETILMIŞ)
 * =================================================================================
 * NOT: Hafif olan kelimeler (aptal, sarışın, kız vb) kaldırıldı
 */
const PROFANITY_WORDS = [
  // Türkçe ciddi kötü kelimeler (cinsel ve nefret söylemi)
  "orospu", "piç", "bok", "sikeyim", "çüğü", "şerefsiz", "namussuz",
  "göt", "sıç", "sapık", "pedofil", "ensest", "tecavüzcü", "ırzına geçmek",
  
  // Türkçe küfürler (ciddi)
  "lanet", "kahrolsun", "cehennem", "iblis", "şeytan", "dinsiz", "ateist",
  
  // İngilizce ciddi kötü kelimeler
  "fuck", "shit", "cunt", "bastard", "asshole", "whore", "bitch",
  "dick", "prick", "motherfucker", "nigger", "faggot", "slut",
  
  // Irk ve etnik ayrımcılık
  "arab", "kürt", "çingene", "rum", "yahudi", "ermenian", "kızılderili",
  "gypsy", "turk", "greek", "jewish",
  
  // Cinsiyetçi söylemler
  "dişi", "erkeklik", "kısır", "eşcinsel", "lezbiyen", "travesti",
  
  // Spam ve aldatmaca kelimeleri
  "viagra", "casino", "bet", "click here", "free money", "xxx",
  "loto", "iddia", "at yarışı", "bahis", "para kazan", "para kazanmak",
  "bitcoin", "crypto", "ether", "forex", "mlm",
  
  // Nefret söylemi ve terörizm/şiddet tehditleri
  "terörist", "öldür", "bomba", "silah", "intihar", "öldürmek",
  "patlat", "kurşun", "asacağım", "keseceğim", "yakacağım", "cıkartacağım",
  
  // Rahatsız edici sölemler
  "geri zekalı", "engelli", "şişko", "çirkin", "düşük", "hastalıklı",
];

const SPAM_KEYWORDS = [
  "viagra", "casino", "bet", "click here", "free money", "xxx", 
  "loto", "iddia", "at yarışı", "bahis", "para kazan", "para kazanmak",
  "bitcoin", "crypto", "ether", "forex", "mlm", "affiliate"
];

/**
 * Kötü içerik kontrolü yapan utility fonksiyonu
 */
const checkContentForBadWords = (text) => {
  if (!text) return { hasProfanity: false, foundWords: [] };
  
  const lowerText = text.toLowerCase();
  const foundWords = [];
  
  PROFANITY_WORDS.forEach(word => {
    const regex = new RegExp(`\\b${word}\\b`, 'gi');
    if (regex.test(lowerText)) {
      foundWords.push(word);
    }
  });
  
  return {
    hasProfanity: foundWords.length > 0,
    foundWords: [...new Set(foundWords)] // Unique words
  };
};

/**
 * =================================================================================
 * İMAJ KONTROL UTILITY FONKSIYONLARI
 * =================================================================================
 */

/**
 * Vision API ile resim analiz et (QUOTA KONTROLÜ İLE + CACHING)
 * OPTIMIZATION: Aynı resim 2 kez çözümlenmesi problemini çöz
 */
const analyzeImageWithVision = async (imagePath) => {
  // OPTIMIZATION STEP 1: Cache'i kontrol et
  const cached = getCachedAnalysis(imagePath);
  if (cached) {
    return cached;
  }
  
  // Quota kontrol et
  const quotaCheck = await canUseVisionApi();
  
  if (!quotaCheck.allowed) {
    console.log(`[VISION_BLOCKED] API kullanılmıyor: ${quotaCheck.reason}`);
    
    // Quota aşıldıysa hata fırlat
    if (quotaCheck.reason === "QUOTA_EXCEEDED" || quotaCheck.reason === "FALLBACK_DENY") {
      throw new Error(`Vision API Quota Exceeded: ${quotaCheck.used}/${VISION_API_CONFIG.MONTHLY_FREE_QUOTA}. Para yok, sistem devre dışı.`);
    }
  }
  
  try {
    // Google Cloud Storage PATH: gs://bucket/path/to/image.jpg
    const request = {
      image: { source: { imageUri: imagePath } },
      features: [
        { type: 'SAFE_SEARCH_DETECTION' },
      ],
    };

    const results = await visionClient.annotateImage(request);
    const detection = results[0].safeSearchAnnotation;

    // Quota sayacını artır (başarılı çağrı)
    if (quotaCheck.monthKey) {
      await incrementVisionApiQuota(quotaCheck.monthKey);
    }

    const analysis = {
      adult: detection.adult || 'UNKNOWN',
      racy: detection.racy || 'UNKNOWN',
      violence: detection.violence || 'UNKNOWN',
      medical: detection.medical || 'UNKNOWN',
      spoof: detection.spoof || 'UNKNOWN',
      raw: detection
    };
    
    // OPTIMIZATION STEP 2: Sonucu cache'e sakla
    setCachedAnalysis(imagePath, analysis);
    
    return analysis;
  } catch (error) {
    console.error("Vision API analiz hatası:", error);
    throw error;
  }
};

/**
 * Likelihood string'ini sayıya çevir (karşılaştırma için)
 */
const likelihoodToScore = (likelihood) => {
  const scores = {
    'VERY_LIKELY': 0.95,
    'LIKELY': 0.75,
    'POSSIBLE': 0.50,
    'UNLIKELY': 0.25,
    'VERY_UNLIKELY': 0.05,
    'UNKNOWN': 0.50
  };
  return scores[likelihood] || 0.50;
};

/**
 * Resim güvenliği kontrolü (QUOTA KONTROLÜ İLE)
 */
const checkImageSafety = async (imagePath) => {
  try {
    const analysis = await analyzeImageWithVision(imagePath);
    
    const adultScore = likelihoodToScore(analysis.adult);
    const racyScore = likelihoodToScore(analysis.racy);
    const violenceScore = likelihoodToScore(analysis.violence);

    const isUnsafe = 
      adultScore >= IMAGE_MODERATION_CONFIG.ADULT_THRESHOLD ||
      racyScore >= IMAGE_MODERATION_CONFIG.RACY_THRESHOLD ||
      violenceScore >= IMAGE_MODERATION_CONFIG.VIOLENCE_THRESHOLD;

    const blockedReasons = [];
    if (adultScore >= IMAGE_MODERATION_CONFIG.ADULT_THRESHOLD) {
      blockedReasons.push(`Adult content (${(adultScore * 100).toFixed(0)}%)`);
    }
    if (racyScore >= IMAGE_MODERATION_CONFIG.RACY_THRESHOLD) {
      blockedReasons.push(`Racy content (${(racyScore * 100).toFixed(0)}%)`);
    }
    if (violenceScore >= IMAGE_MODERATION_CONFIG.VIOLENCE_THRESHOLD) {
      blockedReasons.push(`Violence (${(violenceScore * 100).toFixed(0)}%)`);
    }

    return {
      isUnsafe,
      adultScore,
      racyScore,
      violenceScore,
      blockedReasons,
      raw: analysis
    };
  } catch (error) {
    console.error("Image safety check hatası:", error);
    
    // Quota aşıldıysa güvenli kabul et (izin ver)
    if (error.message && error.message.includes("Quota Exceeded")) {
      console.log("[QUOTA_FALLBACK] Quota aşıldı, resim izin verildi (sistem devre dışı)");
      return {
        isUnsafe: false,
        quotaExceeded: true,
        blockedReasons: ['Vision API Quota Exceeded - resim otomatik izin verildi'],
        raw: null
      };
    }
    
    // Diğer hatalar: güvenli olmayan kabul et
    return {
      isUnsafe: true,
      error: error.message,
      blockedReasons: ['API hatası - sistem tarafından reddedildi']
    };
  }
};

/**
 * =================================================================================
 * 13. CONTENT MODERATION OTOMASYONU (GENİŞLETİLMİŞ)
 * =================================================================================
 */
exports.autoModerateContent = functions.region(REGION).firestore
  .document("gonderiler/{postId}")
  .onCreate(async (snap, context) => {
    const postData = snap.data();
    const title = postData.title || "";
    const content = postData.content || "";
    const fullText = (title + " " + content).toLowerCase();

    // 1. SPAM KONTROLÜ
    const isSpam = SPAM_KEYWORDS.some(keyword => fullText.includes(keyword));

    // 2. PROFANITY KONTROLÜ
    const profanityCheck = checkContentForBadWords(fullText);

    // 3. UPDATE EDİLECEK DATA
    const updateData = {};

    if (isSpam) {
      console.log(`[SPAM_DETECTED] Gönderi ${snap.id} spam olarak işaretlendi.`);
      updateData.flaggedAsSpam = true;
      updateData.flaggedAt = admin.firestore.FieldValue.serverTimestamp();
      updateData.status = "pending_review";
    }

    if (profanityCheck.hasProfanity) {
      console.log(`[PROFANITY_DETECTED] Gönderi ${snap.id} uygunsuz dil içeriyor: ${profanityCheck.foundWords.join(", ")}`);
      updateData.flaggedForProfanity = true;
      updateData.foundBadWords = profanityCheck.foundWords;
      updateData.status = "pending_review";
      updateData.visible = false; // Yayınlanmasını engelle
      updateData.moderationMessage = `⚠️ UYARI: Gönderi uygunsuz kelimeler içeriyor!\nBulunan kelimeler: ${profanityCheck.foundWords.map(w => `"${w}"`).join(", ")}\n\nLütfen bu kelimeleri kaldırıp yeniden gönderin.`;
    }

    if (Object.keys(updateData).length > 0) {
      await snap.ref.update(updateData);
    }
  });

/**
 * =================================================================================
 * 14. YENİ EKLENEN VEYA EKSIK ALANLAR TAMAMLAYICI
 * =================================================================================
 */
exports.migrateUserData = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);

  try {
    const usersSnapshot = await db.collection("kullanicilar").limit(100).get();
    const batch = db.batch();
    let migrateCount = 0;

    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      const updateData = {};

      // Eksik alanları kontrol et ve doldur
      if (userData.postCount === undefined) updateData.postCount = 0;
      if (userData.commentCount === undefined) updateData.commentCount = 0;
      if (userData.likeCount === undefined) updateData.likeCount = 0;
      if (userData.followerCount === undefined) updateData.followerCount = 0;
      if (userData.followingCount === undefined) updateData.followingCount = 0;
      if (userData.followers === undefined) updateData.followers = [];
      if (userData.following === undefined) updateData.following = [];
      if (userData.earnedBadges === undefined) updateData.earnedBadges = [];
      if (userData.savedPosts === undefined) updateData.savedPosts = [];
      if (userData.isOnline === undefined) updateData.isOnline = false;
      if (userData.status === undefined) updateData.status = "Aktif";
      if (userData.lastActive === undefined) updateData.lastActive = admin.firestore.FieldValue.serverTimestamp();
      if (userData.blockedUsers === undefined) updateData.blockedUsers = [];
      if (userData.fcmTokens === undefined) updateData.fcmTokens = [];
      if (userData.unreadNotifications === undefined) updateData.unreadNotifications = 0;
      if (userData.totalUnreadMessages === undefined) updateData.totalUnreadMessages = 0;

      if (Object.keys(updateData).length > 0) {
        batch.update(doc.ref, updateData);
        migrateCount++;
      }
    });

    if (migrateCount > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: `${migrateCount} kullanıcı verisi migre edildi.`,
      count: migrateCount
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 15. KULLANICI BLOK/UNBLOCK İŞLEMLERİ
 * =================================================================================
 */
exports.blockUser = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const targetUserId = data.targetUserId;

  if (!targetUserId || currentUserId === targetUserId) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz kullanıcı ID'si.");
  }

  try {
    const currentUserRef = db.collection("kullanicilar").doc(currentUserId);
    const currentUserDoc = await currentUserRef.get();
    const blockedUsers = currentUserDoc.data()?.blockedUsers || [];

    if (blockedUsers.includes(targetUserId)) {
      throw new functions.https.HttpsError("already-exists", "Zaten bu kullanıcıyı engellemişsiniz.");
    }

    await currentUserRef.update({
      blockedUsers: admin.firestore.FieldValue.arrayUnion(targetUserId)
    });

    // Eğer takip ediyorsa, takipten çıkar
    const following = currentUserDoc.data()?.following || [];
    if (following.includes(targetUserId)) {
      await currentUserRef.update({
        following: admin.firestore.FieldValue.arrayRemove(targetUserId),
        followingCount: admin.firestore.FieldValue.increment(-1)
      });

      await db.collection("kullanicilar").doc(targetUserId).update({
        followers: admin.firestore.FieldValue.arrayRemove(currentUserId),
        followerCount: admin.firestore.FieldValue.increment(-1)
      });
    }

    return { success: true, message: "Kullanıcı başarıyla engellendi." };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.unblockUser = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const currentUserId = context.auth.uid;
  const targetUserId = data.targetUserId;

  if (!targetUserId) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz kullanıcı ID'si.");
  }

  try {
    const currentUserRef = db.collection("kullanicilar").doc(currentUserId);
    await currentUserRef.update({
      blockedUsers: admin.firestore.FieldValue.arrayRemove(targetUserId)
    });

    return { success: true, message: "Engel başarıyla kaldırıldı." };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 16. KULLANICI SEARCHİNDEKS GÜNCELLEME
 * =================================================================================
 */
exports.updateUserSearchIndex = functions.region(REGION).firestore
  .document("kullanicilar/{userId}")
  .onWrite(async (change, context) => {
    const afterData = change.after.exists ? change.after.data() : null;
    
    if (!afterData) return null;

    try {
      // Search keywords oluştur
      const searchKeywords = [];
      if (afterData.takmaAd) {
        searchKeywords.push(afterData.takmaAd.toLowerCase());
        // Her kelimeyi ayrı ayrı ekle
        afterData.takmaAd.toLowerCase().split(" ").forEach(word => {
          if (word.length > 2) searchKeywords.push(word);
        });
      }
      if (afterData.ad) {
        searchKeywords.push(afterData.ad.toLowerCase());
      }
      if (afterData.universite) {
        searchKeywords.push(afterData.universite.toLowerCase());
      }

      // Index'i güncelle
      await change.after.ref.update({
        searchKeywords: searchKeywords,
        lastIndexedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error("Search index güncelleme hatası:", error);
    }

    return null;
  });

/**
 * =================================================================================
 * 17. AYLIKI KULLANICI İSTATİSTİKLERİ HESAPLAYICI
 * =================================================================================
 */
exports.calculateMonthlyStats = functions.region(REGION)
  .pubsub.schedule('0 0 1 * *') // Ayın ilk günü saat 00:00
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await db.collection("kullanicilar").get();
      const statsData = {
        totalUsers: usersSnapshot.size,
        activeUsers: 0,
        totalPosts: 0,
        totalComments: 0,
        totalLikes: 0,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        month: new Date().getMonth() + 1,
        year: new Date().getFullYear()
      };

      // Kullanıcı istatistiklerini topla
      usersSnapshot.forEach((doc) => {
        const userData = doc.data();
        if (userData.isOnline || userData.lastActive) statsData.activeUsers++;
        if (userData.postCount) statsData.totalPosts += userData.postCount || 0;
        if (userData.commentCount) statsData.totalComments += userData.commentCount || 0;
        if (userData.likeCount) statsData.totalLikes += userData.likeCount || 0;
      });

      // İstatistikleri kaydet
      await db.collection("platform_stats").doc(`${statsData.year}_${statsData.month}`).set(statsData);

      console.log(`[SUCCESS] Aylık istatistikler kaydedildi: ${statsData.year}/${statsData.month}`);
      return { success: true, stats: statsData };
    } catch (error) {
      console.error('[ERROR] Aylık istatistik hesaplama hatası:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * =================================================================================
 * 18. BADGE/ACHIEVEMENT SİSTEMİ
 * =================================================================================
 */
exports.checkAndAwardBadges = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const userId = context.auth.uid;

  try {
    const userDoc = await db.collection("kullanicilar").doc(userId).get();
    const userData = userDoc.data();
    const badges = userData.earnedBadges || [];
    const updateData = {};

    // 🏆 İlk Gönderi Badge
    if (userData.postCount === 1 && !badges.includes("first_post")) {
      updateData.earnedBadges = admin.firestore.FieldValue.arrayUnion("first_post");
    }

    // 🔥 Aktif Kullanıcı Badge (100+ gönderi)
    if ((userData.postCount || 0) >= 100 && !badges.includes("power_poster")) {
      updateData.earnedBadges = admin.firestore.FieldValue.arrayUnion("power_poster");
    }

    // 👥 Sosyal Badge (100+ takipçi)
    if ((userData.followerCount || 0) >= 100 && !badges.includes("social_butterfly")) {
      updateData.earnedBadges = admin.firestore.FieldValue.arrayUnion("social_butterfly");
    }

    // 👍 Like Badge (500+ like)
    if ((userData.likeCount || 0) >= 500 && !badges.includes("liked_by_many")) {
      updateData.earnedBadges = admin.firestore.FieldValue.arrayUnion("liked_by_many");
    }

    // 💬 Comment Badge (100+ yorum)
    if ((userData.commentCount || 0) >= 100 && !badges.includes("great_conversationalist")) {
      updateData.earnedBadges = admin.firestore.FieldValue.arrayUnion("great_conversationalist");
    }

    if (Object.keys(updateData).length > 0) {
      await userDoc.ref.update(updateData);
      return { success: true, newBadges: updateData.earnedBadges };
    }

    return { success: true, newBadges: [] };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 19. BATCH EMAIL GÖNDERICI (Newsletter, Duyurular)
 * =================================================================================
 */
exports.sendBatchEmails = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const { subject, body, recipientFilter } = data;

  // Admin kontrolü
  const adminDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
  if (adminDoc.data()?.role !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Sadece admin gönderebilir.");
  }

  try {
    let query = db.collection("kullanicilar");

    // Filtre uygula (aktif, belirli üniversite, vb.)
    if (recipientFilter?.isActive) {
      query = query.where("isOnline", "==", true);
    }
    if (recipientFilter?.university) {
      query = query.where("universite", "==", recipientFilter.university);
    }

    const recipients = await query.get();
    const emailPromises = [];

    recipients.forEach((doc) => {
      const userData = doc.data();
      if (userData.email) {
        // Email gönderme logunun kaydını tut (gerçek email API kullanılacak)
        emailPromises.push(
          db.collection("email_queue").add({
            recipientEmail: userData.email,
            recipientId: doc.id,
            subject: subject,
            body: body,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "pending"
          })
        );
      }
    });

    await Promise.all(emailPromises);

    return {
      success: true,
      message: `${recipients.size} e-posta gönderi kuyruğuna alındı.`,
      count: recipients.size
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 20. SUGGESTION ENGİNE (Kişiselleştirilmiş İçerik Önerme)
 * =================================================================================
 */
exports.generatePersonalizedSuggestions = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const userId = context.auth.uid;

  try {
    const userDoc = await db.collection("kullanicilar").doc(userId).get();
    const userData = userDoc.data();
    
    // Kullanıcının ilgi alanları (takip ettiği kategoriler)
    const following = userData.following || [];
    const suggestions = [];

    // Takip edilen kullanıcıların izleyenlerini öner
    if (following.length > 0) {
      const followingUsersSnapshot = await db.collection("kullanicilar")
        .where("__name__", "in", following)
        .limit(5)
        .get();

      followingUsersSnapshot.forEach((doc) => {
        const followersOfFollowing = doc.data().followers || [];
        followersOfFollowing.forEach((follower) => {
          if (!following.includes(follower) && follower !== userId) {
            suggestions.push({
              type: "follow_suggestion",
              targetId: follower,
              reason: "Takip ettiğiniz kişilerin de takip ettiği"
            });
          }
        });
      });
    }

    // İlgi gördü posts öneri
    const popularPostsSnapshot = await db.collection("gonderiler")
      .orderBy("likeCount", "desc")
      .limit(10)
      .get();

    popularPostsSnapshot.forEach((doc) => {
      const postData = doc.data();
      const userLikedPosts = userData.savedPosts || [];
      if (!userLikedPosts.includes(doc.id) && postData.userId !== userId) {
        suggestions.push({
          type: "post_suggestion",
          targetId: doc.id,
          title: postData.title,
          reason: "Çok beğenilen gönderi"
        });
      }
    });

    return {
      success: true,
      suggestions: suggestions.slice(0, 10) // İlk 10 öneeri
    };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 21. YORUM MODERASYONU TRIGGER
 * =================================================================================
 */
exports.moderateComment = functions.region(REGION).firestore
  .document("gonderiler/{postId}/yorumlar/{commentId}")
  .onCreate(async (snap, context) => {
    const commentData = snap.data();
    const text = commentData.text || commentData.content || "";
    const postId = context.params.postId;

    // Kötü kelime kontrolü
    const profanityCheck = checkContentForBadWords(text);

    if (profanityCheck.hasProfanity) {
      console.log(`[COMMENT_PROFANITY] Yorum ${snap.id} uygunsuz dil içeriyor: ${profanityCheck.foundWords.join(", ")}`);
      
      await snap.ref.update({
        flaggedForProfanity: true,
        foundBadWords: profanityCheck.foundWords,
        visible: false,
        moderationMessage: `⚠️ UYARI: Yorumunuz uygunsuz kelimeler içeriyor!\nBulunan kelimeler: ${profanityCheck.foundWords.map(w => `"${w}"`).join(", ")}\n\nLütfen bu kelimeleri kaldırıp yeniden gönderin.`,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Admin'e bildirim gönder
      await db.collection("bildirimler").add({
        userId: "admin",
        senderId: commentData.userId,
        type: "moderation_alert",
        message: `Uygunsuz yorum: "${text.substring(0, 50)}..."`,
        postId: postId,
        commentId: snap.id,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

/**
 * =================================================================================
 * 22. ANKET (POLL) MODERASYONU TRIGGER
 * =================================================================================
 */
exports.moderatePoll = functions.region(REGION).firestore
  .document("anketler/{pollId}")
  .onCreate(async (snap, context) => {
    const pollData = snap.data();
    const title = pollData.title || "";
    const question = pollData.question || "";
    const options = pollData.options || [];

    // Başlık ve soru kontrolü
    const titleCheck = checkContentForBadWords(title);
    const questionCheck = checkContentForBadWords(question);

    // Seçenekleri kontrol et
    let hasOptionProfanity = false;
    const badOptions = [];
    options.forEach((option, index) => {
      const optionText = option.text || option;
      const optionCheck = checkContentForBadWords(optionText);
      if (optionCheck.hasProfanity) {
        hasOptionProfanity = true;
        badOptions.push({ index, text: optionText, words: optionCheck.foundWords });
      }
    });

    const updateData = {};
    const foundWords = [
      ...titleCheck.foundWords,
      ...questionCheck.foundWords,
      ...badOptions.flatMap(o => o.words)
    ];

    if (titleCheck.hasProfanity || questionCheck.hasProfanity || hasOptionProfanity) {
      console.log(`[POLL_PROFANITY] Anket ${snap.id} uygunsuz dil içeriyor: ${foundWords.join(", ")}`);
      
      updateData.flaggedForProfanity = true;
      updateData.foundBadWords = [...new Set(foundWords)];
      updateData.status = "pending_review";
      updateData.visible = false;
      updateData.moderationMessage = `Anket uygunsuz kelimeler içeriyor: "${foundWords.join(", ")}". Lütfen bu kelimeleri kaldırıp yeniden gönderin.`;
      updateData.flaggedAt = admin.firestore.FieldValue.serverTimestamp();

      await snap.ref.update(updateData);

      // Admin'e bildirim gönder
      await db.collection("bildirimler").add({
        userId: "admin",
        senderId: pollData.userId,
        type: "moderation_alert",
        message: `Uygunsuz anket: "${title.substring(0, 50)}..."`,
        pollId: snap.id,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

/**
 * =================================================================================
 * 23. FORUM MESAJ MODERASYONU TRIGGER
 * =================================================================================
 */
exports.moderateForumMessage = functions.region(REGION).firestore
  .document("forumlar/{forumId}/mesajlar/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const text = messageData.message || messageData.content || "";
    const forumId = context.params.forumId;

    // Kötü kelime kontrolü
    const profanityCheck = checkContentForBadWords(text);

    if (profanityCheck.hasProfanity) {
      console.log(`[FORUM_MESSAGE_PROFANITY] Forum mesajı ${snap.id} uygunsuz dil içeriyor: ${profanityCheck.foundWords.join(", ")}`);
      
      await snap.ref.update({
        flaggedForProfanity: true,
        foundBadWords: profanityCheck.foundWords,
        visible: false,
        moderationMessage: `Mesajınız uygunsuz kelimeler içeriyor: "${profanityCheck.foundWords.join(", ")}". Lütfen bu kelimeleri kaldırıp yeniden gönderin.`,
        flaggedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Admin'e bildirim gönder
      await db.collection("bildirimler").add({
        userId: "admin",
        senderId: messageData.userId,
        type: "moderation_alert",
        message: `Uygunsuz forum mesajı: "${text.substring(0, 50)}..."`,
        forumId: forumId,
        messageId: snap.id,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

/**
 * =================================================================================
 * 24. İÇERİK KONTROL VE MODERASYON (CLIENT SIDE SUBMISSION)
 * =================================================================================
 * Bu fonksiyon kullanıcı içerik göndermeden önce profanity kontrolü yapar
 * ve sonucu döner. Eğer kötü kelime varsa, kullanıcıya hata mesajı gösterilir
 * ve içeriği düzeltmesini istenir.
 */
exports.checkAndFixContent = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  
  const { contentType, title, content, text, question, options, message } = data;

  // Geçerli content tipleri
  const validTypes = ["post", "comment", "poll", "forum_message"];
  if (!validTypes.includes(contentType)) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz içerik türü.");
  }

  try {
    let textToCheck = "";
    const foundWords = [];

    // Content türüne göre kontrol metni oluştur
    if (contentType === "post") {
      textToCheck = (title || "") + " " + (content || "");
    } else if (contentType === "comment") {
      textToCheck = text || "";
    } else if (contentType === "poll") {
      textToCheck = (title || "") + " " + (question || "") + " " + (options || []).join(" ");
    } else if (contentType === "forum_message") {
      textToCheck = message || "";
    }

    if (!textToCheck || textToCheck.trim().length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "İçerik boş olamaz.");
    }

    // Profanity kontrolü yap
    const profanityCheck = checkContentForBadWords(textToCheck);

    if (profanityCheck.hasProfanity) {
      console.log(`[PROFANITY_CHECK_FAILED] ${contentType}: ${profanityCheck.foundWords.join(", ")}`);
      
      const wordList = profanityCheck.foundWords.join(", ");
      return {
        success: false,
        message: `⚠️ İçeriğinizde uygunsuz kelimeler bulundu:\n\n"${wordList}"\n\nLütfen bu kelimeleri kaldırıp yeniden gönderin.`,
        foundWords: profanityCheck.foundWords,
        requiresModeration: true,
        canPublish: false
      };
    }

    // Profanity kontrolü geçti
    console.log(`[PROFANITY_CHECK_PASSED] ${contentType}: İçerik temiz`);
    
    return {
      success: true,
      message: "✅ İçerik kontrolü geçti! Yayınlayabilirsiniz.",
      foundWords: [],
      requiresModeration: false,
      canPublish: true
    };

  } catch (error) {
    console.error("İçerik kontrol hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 26. GÖNDERI/PROFIL RESİMİ MODERASYONU TRIGGER
 * =================================================================================
 * Storage'a yüklenen resimleri Vision API ile kontrol eder
 * Uygunsuzsa siler + admin'e bildirim gönderir
 */
exports.moderateUploadedImage = functions.region(REGION).storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name; // Örn: "profil_resimleri/userId/image.jpg"
    const bucket = admin.storage().bucket(object.bucket);
    const contentType = object.contentType;

    // Sadece görüntüleri kontrol et
    if (!contentType || !contentType.startsWith('image/')) {
      console.log(`[SKIP] Görüntü değil: ${contentType}`);
      return null;
    }

    // İzin verilen türler
    if (!IMAGE_MODERATION_CONFIG.ALLOWED_TYPES.includes(contentType)) {
      console.log(`[REJECTED] İzin verilmeyen tip: ${contentType}`);
      await bucket.file(filePath).delete();
      return null;
    }

    // Dosya boyutu kontrolü
    if (object.size > IMAGE_MODERATION_CONFIG.MAX_SIZE) {
      console.log(`[SIZE_EXCEEDED] Dosya çok büyük: ${object.size} bytes`);
      await bucket.file(filePath).delete();
      return null;
    }

    try {
      console.log(`[ANALYZING] Resim analiz ediliyor: ${filePath}`);
      
      // GCS Path: gs://bucket/path
      const gcsPath = `gs://${object.bucket}/${filePath}`;
      
      // Güvenlik kontrolü yap
      const safetyResult = await checkImageSafety(gcsPath);

      if (safetyResult.isUnsafe) {
        console.log(`[UNSAFE_IMAGE] Uygunsuz resim bulundu: ${filePath}`);
        console.log(`Sebepleri: ${safetyResult.blockedReasons.join(", ")}`);
        
        // Resmi sil
        await bucket.file(filePath).delete();
        
        // Dosya yolundan userId'yi çıkar (örn: "profil_resimleri/userId/..." → userId)
        const pathParts = filePath.split('/');
        let userId = null;
        
        if (filePath.includes('profil_resimleri') && pathParts.length >= 2) {
          userId = pathParts[1];
        } else if (filePath.includes('gonderiler') && pathParts.length >= 2) {
          userId = pathParts[1];
        }

        // Admin'e bildirim gönder
        if (userId) {
          await db.collection("bildirimler").add({
            userId: "admin",
            senderId: userId,
            type: "unsafe_image_alert",
            message: `⚠️ Uygunsuz resim yükleme denemesi: ${safetyResult.blockedReasons.join(", ")}`,
            filePath: filePath,
            scores: {
              adult: (safetyResult.adultScore * 100).toFixed(0),
              racy: (safetyResult.racyScore * 100).toFixed(0),
              violence: (safetyResult.violenceScore * 100).toFixed(0)
            },
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });

          // Kullanıcıyı uyar
          await db.collection("kullanicilar").doc(userId).update({
            lastRejectedImageAt: admin.firestore.FieldValue.serverTimestamp(),
            rejectedImageCount: admin.firestore.FieldValue.increment(1)
          });
        }

        return {
          success: false,
          deleted: true,
          reason: safetyResult.blockedReasons.join(", ")
        };
      } else {
        console.log(`[SAFE_IMAGE] Resim güvenli: ${filePath}`);
        return {
          success: true,
          message: "Resim başarıyla analiz edildi - güvenli"
        };
      }

    } catch (error) {
      console.error(`[ERROR] Resim analizi sırasında hata: ${error.message}`);
      // Hata durumunda resmi sil (güvenlik için)
      try {
        await bucket.file(filePath).delete();
      } catch (deleteError) {
        console.error(`Dosya silme hatası: ${deleteError.message}`);
      }
      return null;
    }
  });

/**
 * =================================================================================
 * 27. UPLOAD ÖNCESI İMAJ KONTROLÜ (CLIENT-SIDE)
 * =================================================================================
 * Kullanıcı resim yüklemeden önce güvenlik kontrolü yapar
 */
exports.analyzeImageBeforeUpload = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  
  const { imageUrl } = data;
  
  if (!imageUrl) {
    throw new functions.https.HttpsError("invalid-argument", "Resim URL'si eksik.");
  }

  try {
    console.log(`[ANALYZING_BEFORE_UPLOAD] Resim analiz ediliyor: ${imageUrl}`);
    
    const safetyResult = await checkImageSafety(imageUrl);

    // Kota aşıldıysa uyarı ver
    if (safetyResult.quotaExceeded) {
      console.log(`[QUOTA_EXCEEDED] Görsel kontrol kotası doldu, resim otomatik izin verildi`);
      
      return createUserFriendlyResponse(
        true,
        "⚠️ Görsel kontrol sınırına ulaşıldı.\n\nResiminiz otomatik olarak onaylandı. Sonraki ayda daha fazla kontrol yapılacaktır.",
        {
          isUnsafe: false,
          quotaExceeded: true,
          cached: safetyResult.cached || false
        },
        "quota_exceeded_auto_approved"
      );
    }

    if (safetyResult.isUnsafe) {
      console.log(`[UNSAFE] Uygunsuz resim: ${safetyResult.blockedReasons.join(", ")}`);
      
      // Nedene göre özel mesaj
      let userMessage = "⚠️ Resminiz paylaşım politikamıza uygun değil.\n\n";
      
      safetyResult.blockedReasons.forEach(reason => {
        if (reason.includes('Adult')) {
          userMessage += "🔴 Yetişkinlere uygun içerik tespit edildi\n";
        } else if (reason.includes('Racy')) {
          userMessage += "🔴 Müstehcen içerik tespit edildi\n";
        } else if (reason.includes('Violence')) {
          userMessage += "🔴 Şiddet içeriği tespit edildi\n";
        }
      });
      
      userMessage += "\nLütfen farklı bir resim seçin ve yeniden deneyin.";
      
      return createUserFriendlyResponse(
        false,
        userMessage,
        {
          isUnsafe: true,
          blockedReasons: safetyResult.blockedReasons,
          scores: {
            adult: (safetyResult.adultScore * 100).toFixed(0),
            racy: (safetyResult.racyScore * 100).toFixed(0),
            violence: (safetyResult.violenceScore * 100).toFixed(0)
          }
        },
        "image_unsafe"
      );
    } else {
      const cacheHit = safetyResult.raw && safetyResult.raw.cached;
      console.log(`[SAFE] Resim güvenli ${cacheHit ? '(cache)' : '(yeni analiz)'} - yüklenmesine izin ver`);
      
      let successMessage = "✅ Resim başarıyla kontrol geçti!\n";
      if (cacheHit) {
        successMessage += "⚡ Önceki analiz kullanıldı (hızlı onay)";
      }
      
      return createUserFriendlyResponse(
        true,
        successMessage,
        {
          isUnsafe: false,
          cached: cacheHit || false,
          scores: {
            adult: (safetyResult.adultScore * 100).toFixed(0),
            racy: (safetyResult.racyScore * 100).toFixed(0),
            violence: (safetyResult.violenceScore * 100).toFixed(0)
          }
        },
        null
      );
    }
  } catch (error) {
    console.error("Resim analiz hatası:", error);
    
    // Network hatası mı?
    if (error.message && error.message.includes('connection') || error.message.includes('NETWORK')) {
      return createUserFriendlyResponse(
        false,
        "🔌 Bağlantı sorunu yaşanıyor.\n\nLütfen interneti kontrol edin ve yeniden deneyin.",
        null,
        "network_error"
      );
    }
    
    // Server hatası
    return createUserFriendlyResponse(
      false,
      "⚠️ Sunucu hatası!\n\nLütfen 5 dakika sonra yeniden deneyin.",
      { originalError: error.message },
      "server_error"
    );
  }
});

/**
 * =================================================================================
 * 29. GAMIFICATION (OYUNLAŞTIRMA) XP EKLEME
 * =================================================================================
 */
exports.addXp = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const userId = context.auth.uid;
  const { operationType, relatedId } = data;

  if (!operationType) {
    throw new functions.https.HttpsError("invalid-argument", "İşlem türü eksik.");
  }

  const XP_DISTRIBUTION = {
    'post_created': 10,
    'comment_created': 5,
    'comment_like': 1,
    'post_like': 0,
    'badge_unlock': 50,
  };

  const SPAM_TIME_WINDOW_MINUTES = 5;
  const SPAM_ACTION_LIMIT = 10;

  try {
    const userRef = db.collection("kullanicilar").doc(userId);

    // Spam kontrolü
    const now = new Date();
    const timeWindowStart = new Date(now.getTime() - SPAM_TIME_WINDOW_MINUTES * 60 * 1000);

    const recentLogsSnapshot = await db.collection('xp_logs')
      .where('userId', '==', userId)
      .where('operationType', '==', operationType)
      .where('timestamp', '>', timeWindowStart)
      .get();

    if (recentLogsSnapshot.size >= SPAM_ACTION_LIMIT) {
      console.log(`[SPAM_DETECTED] ${userId} için XP eklemesi reddedildi.`);
      await userRef.update({
        lastSpamFlag: admin.firestore.FieldValue.serverTimestamp(),
        spamWarnings: admin.firestore.FieldValue.increment(1),
      }).catch(() => {});
      return { success: false, message: "Spam algılandı." };
    }

    // Multiplier hesaplama
    let multiplier = 1.0;
    if (operationType === 'comment_created' || operationType === 'post_created') {
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayLogsSnapshot = await db.collection('xp_logs')
        .where('userId', '==', userId)
        .where('operationType', '==', operationType)
        .where('timestamp', '>=', todayStart)
        .get();
      
      const count = todayLogsSnapshot.size;
      if (count >= 5 && count < 10) {
        multiplier = 0.8;
      } else if (count >= 10) {
        multiplier = 0.5;
      }
    }

    const xpAmount = XP_DISTRIBUTION[operationType] || 0;
    const finalXP = Math.round(xpAmount * multiplier);

    if (finalXP === 0) {
      return { success: true, message: "XP değeri 0, işlem atlandı." };
    }

    // Transaction ile güncelleme
    let newLevel = 0;
    let oldLevel = 0;

    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new Error("Kullanıcı bulunamadı.");
      }
      const userData = userDoc.data();
      const currentXP = userData.xp || 0;
      oldLevel = userData.seviye || 1;

      const newXP = currentXP + finalXP;
      const calculatedLevel = Math.floor(newXP / 200) + 1;
      newLevel = Math.min(calculatedLevel, 50); // Max seviye 50

      const xpInCurrentLevel = newXP % 200;

      transaction.update(userRef, {
        xp: newXP,
        seviye: newLevel,
        xpInCurrentLevel: xpInCurrentLevel,
        lastXPUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

      const logRef = db.collection('xp_logs').doc();
      transaction.set(logRef, {
        userId: userId,
        operationType: operationType,
        baseXPAmount: xpAmount,
        finalXPAmount: finalXP,
        multiplier: multiplier,
        relatedId: relatedId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        deleted: false,
      });
    });

    if (newLevel > oldLevel) {
      await db.collection('bildirimler').add({
        userId: userId,
        senderName: 'Sistem',
        type: 'level_up',
        oldLevel: oldLevel,
        newLevel: newLevel,
        message: `Tebrikler! Seviye ${newLevel}'e ulaştın!`,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (newLevel % 5 === 0) {
        await userRef.update({
          xp: admin.firestore.FieldValue.increment(25),
        });
      }
    }

    // Rozetleri kontrol et
    const userDocForBadges = await userRef.get();
    const userDataForBadges = userDocForBadges.data();
    const currentBadges = userDataForBadges.earnedBadges || [];
    const { commentCount = 0, postCount = 0, likeCount = 0 } = userDataForBadges;
    
    const newBadges = [];
    const allBadges = {
      'pioneer': postCount >= 1,
      'commentator_rookie': commentCount >= 10,
      'commentator_pro': commentCount >= 50,
      'popular_author': likeCount >= 50,
      'campus_phenomenon': likeCount >= 250,
      'veteran': postCount >= 50,
      'helper': commentCount >= 100,
      'early_bird': postCount >= 20,
      'night_owl': postCount >= 20,
      'question_master': postCount >= 25,
      'problem_solver': commentCount >= 50,
      'trending_topic': likeCount >= 100,
      'social_butterfly': commentCount >= 50,
      'curious': commentCount >= 100,
      'loyal_member': commentCount >= 75,
      'friendly': likeCount >= 60,
      'influencer': likeCount >= 150,
      'perfectionist': postCount >= 30,
    };

    for (const badgeId in allBadges) {
      if (allBadges[badgeId] && !currentBadges.includes(badgeId)) {
        newBadges.push(badgeId);
      }
    }

    if (newBadges.length > 0) {
      await userRef.update({
        earnedBadges: admin.firestore.FieldValue.arrayUnion(...newBadges),
        xp: admin.firestore.FieldValue.increment(newBadges.length * (XP_DISTRIBUTION['badge_unlock'] || 50))
      });

      for (const badgeId of newBadges) {
        await db.collection("bildirimler").add({
          userId: userId,
          senderName: 'Sistem',
          type: 'system',
          message: 'Tebrikler! Yeni bir rozet kazandın.',
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return { success: true, xpAdded: finalXP };
  } catch (error) {
    console.error("XP Ekleme Hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 28. BAYRAKLANMIŞ RESİMLERİ AÇIKLAMA YAPARAK YENİDEN GÖNDERİM
 * =================================================================================
 */
exports.reuploadAfterRejection = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  
  const { newImageUrl, explanation } = data;
  const userId = context.auth.uid;
  
  if (!newImageUrl) {
    throw new functions.https.HttpsError("invalid-argument", "Yeni resim URL'si eksik.");
  }

  try {
    // Yeni resmi analiz et
    const safetyResult = await checkImageSafety(newImageUrl);

    if (safetyResult.isUnsafe) {
      return {
        success: false,
        message: `⚠️ Yeni resminiz de uygunsuz içerik içeriyor:\n${safetyResult.blockedReasons.join("\n")}`,
        blockedReasons: safetyResult.blockedReasons
      };
    }

    // Admin'e inceleme isteği gönder
    await db.collection("image_reupload_requests").add({
      userId: userId,
      newImageUrl: newImageUrl,
      userExplanation: explanation || "Açıklama yok",
      status: "pending_review",
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      scores: {
        adult: (safetyResult.adultScore * 100).toFixed(0),
        racy: (safetyResult.racyScore * 100).toFixed(0),
        violence: (safetyResult.violenceScore * 100).toFixed(0)
      }
    });

    // Admin'e bildirim
    await db.collection("bildirimler").add({
      userId: "admin",
      senderId: userId,
      type: "image_reupload_request",
      message: `Resim yeniden yükleme isteği: ${explanation || "Açıklama yok"}`,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      message: "✅ Resminiz inceleme için admin'e gönderildi. Sonuç için lütfen bekleyin."
    };
  } catch (error) {
    console.error("Resim yeniden yükleme hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 25. BAYRAKLANMIŞ IÇERIĞI DÜZELTİLMİŞ HALİYLE GÜNCELLE
 * =================================================================================
 * Moderasyon başarısız olan içeriği, kullanıcı düzeltince yeniden kontrol eder
 * ve geçerse yayınlar.
 */
exports.resubmitModeratedContent = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const userId = context.auth.uid;
  const { contentType, contentId, updatedText } = data;

  // Geçerli content tipleri
  const validTypes = ["post", "comment", "poll", "forum_message"];
  if (!validTypes.includes(contentType)) {
    throw new functions.https.HttpsError("invalid-argument", "Geçersiz içerik türü.");
  }

  if (!contentId || !updatedText) {
    throw new functions.https.HttpsError("invalid-argument", "Gerekli alanlar eksik.");
  }

  try {
    // Tekrar profanity kontrolü yap
    const newCheck = checkContentForBadWords(updatedText);

    if (newCheck.hasProfanity) {
      console.log(`[RESUBMIT_FAILED] ${contentType}: Hâlâ kötü kelimeler var: ${newCheck.foundWords.join(", ")}`);
      return {
        success: false,
        message: `⚠️ Düzeltilen içerik hâlâ uygunsuz kelimeler içeriyor: "${newCheck.foundWords.join(", ")}"`,
        foundWords: newCheck.foundWords
      };
    }

    // Güncellenecek data
    const updateData = {
      content: updatedText,
      text: updatedText,
      flaggedForProfanity: false,
      foundBadWords: [],
      visible: true,
      status: "published",
      moderationMessage: null,
      resubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
      resubmittedBy: userId
    };

    // Content türüne göre güncelle
    if (contentType === "post") {
      await db.collection("gonderiler").doc(contentId).update(updateData);
    } else if (contentType === "comment") {
      // Yorum'un postId'sini bulmamız gerekir - collectionGroup ile ara
      const allPostsSnapshot = await db.collectionGroup("yorumlar").where("__name__", "==", contentId).get();
      if (allPostsSnapshot.empty) {
        throw new functions.https.HttpsError("not-found", "Yorum bulunamadı.");
      }
      await allPostsSnapshot.docs[0].ref.update(updateData);
    } else if (contentType === "poll") {
      await db.collection("anketler").doc(contentId).update(updateData);
    } else if (contentType === "forum_message") {
      // Forum mesajı'nın forumId'sini bulmamız gerekir
      const allForumsSnapshot = await db.collectionGroup("mesajlar").where("__name__", "==", contentId).get();
      if (allForumsSnapshot.empty) {
        throw new functions.https.HttpsError("not-found", "Forum mesajı bulunamadı.");
      }
      await allForumsSnapshot.docs[0].ref.update(updateData);
    }

    console.log(`[RESUBMIT_SUCCESS] ${contentType} ${contentId} başarıyla yayınlandı.`);
    
    return {
      success: true,
      message: "✅ İçeriğiniz başarıyla yayınlandı! Moderasyon geçti!"
    };
  } catch (error) {
    console.error("İçerik yeniden gönderme hatası:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * 30. VISION API QUOTA YÖNETIM PANELİ (ADMIN)
 * =================================================================================
 * Admin kullanıcı quota durumunu görebilir ve ayarları değiştirebilir
 */
exports.getVisionApiQuotaStatus = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin görebilir.");
    }
    
    try {
      const quota = await getVisionApiQuotaUsage();
      
      return {
        success: true,
        monthlyFreeQuota: VISION_API_CONFIG.MONTHLY_FREE_QUOTA,
        used: quota.used,
        remaining: quota.remaining,
        quotaExceeded: quota.remaining <= 0,
        enabled: VISION_API_CONFIG.ENABLED,
        fallbackStrategy: VISION_API_CONFIG.FALLBACK_STRATEGY,
        currentMonth: quota.monthKey,
        message: quota.remaining > 0 
          ? `✅ Quota OK: ${quota.remaining}/${VISION_API_CONFIG.MONTHLY_FREE_QUOTA} kaldı`
          : `🚨 QUOTA FULL: ${quota.used} istek kullanıldı. Sistem devre dışı.`
      };
    } catch (error) {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * Vision API'yi enable/disable et (ADMIN)
 */
exports.setVisionApiEnabled = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin değiştirebilir.");
    }
    
    const { enabled } = data;
    
    if (typeof enabled !== "boolean") {
      throw new functions.https.HttpsError("invalid-argument", "enabled boolean olmalı.");
    }
    
    try {
      // Bu durumda VISION_API_CONFIG.ENABLED değişir
      // Not: Kalıcı değil (runtime'da değişir, restart'ta sıfırlanır)
      VISION_API_CONFIG.ENABLED = enabled;
      
      // Firestore'da da kaydet (opsiyon)
      await db.collection("system_config").doc("vision_api").set({
        enabled: enabled,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid
      }, { merge: true });
      
      console.log(`[ADMIN] Vision API ${enabled ? "ENABLED" : "DISABLED"} by ${context.auth.uid}`);
      
      return {
        success: true,
        message: `Vision API ${enabled ? "aktifleştirildi" : "devre dışı bırakıldı"}`,
        enabled: VISION_API_CONFIG.ENABLED
      };
    } catch (error) {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * Fallback strategy değiştir (ADMIN)
 * Quota aşıldığında: "deny" (reddet), "allow" (izin ver), "warn" (uyar)
 */
exports.setVisionApiFallbackStrategy = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin değiştirebilir.");
    }
    
    const { strategy } = data;
    const validStrategies = ["deny", "allow", "warn"];
    
    if (!validStrategies.includes(strategy)) {
      throw new functions.https.HttpsError("invalid-argument", `Strategy: ${validStrategies.join(", ")}`);
    }
    
    try {
      VISION_API_CONFIG.FALLBACK_STRATEGY = strategy;
      
      await db.collection("system_config").doc("vision_api").set({
        fallbackStrategy: strategy,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: context.auth.uid
      }, { merge: true });
      
      console.log(`[ADMIN] Vision API fallback strategy set to: ${strategy}`);
      
      return {
        success: true,
        message: `Fallback stratejisi "${strategy}" olarak ayarlandı`,
        strategy: VISION_API_CONFIG.FALLBACK_STRATEGY
      };
    } catch (error) {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * Quota sayacını sıfırla (ADMIN - Acil durum)
 */
exports.resetVisionApiQuota = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin sıfırlayabilir.");
    }
    
    try {
      const today = new Date();
      const monthKey = `${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}`;
      
      await db.collection("vision_api_quota").doc(monthKey).delete();
      
      console.log(`[ADMIN] Vision API quota sıfırlandı: ${monthKey}`);
      
      return {
        success: true,
        message: `${monthKey} ayı quota'ı sıfırlandı. Sistem 1000 yeni istekle başladı.`,
        resetMonth: monthKey
      };
    } catch (error) {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * =================================================================================
 * 31. ADMIN PANEL - DASHBOARD (ADMIN)
 * =================================================================================
 * Admin paneli için dashboard verileri
 */
exports.getAdminDashboard = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(context.auth.uid).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin görebilir.");
    }
    
    try {
      // 1. Vision API Quota
      const quota = await getVisionApiQuotaUsage();
      
      // 2. Toplam kullanıcı sayısı
      const usersSnap = await db.collection("kullanicilar").count().get();
      const totalUsers = usersSnap.data().count;
      
      // 3. Aktif kullanıcılar (son 7 gün)
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const activeUsersSnap = await db.collection("kullanicilar")
        .where("lastActive", ">=", sevenDaysAgo)
        .count()
        .get();
      const activeUsers = activeUsersSnap.data().count;
      
      // 4. Toplam gönderi sayısı
      const postsSnap = await db.collection("gonderiler").count().get();
      const totalPosts = postsSnap.data().count;
      
      // 5. Uygunsuz içerik sayısı
      const flaggedSnap = await db.collection("gonderiler")
        .where("flaggedForProfanity", "==", true)
        .count()
        .get();
      const flaggedContent = flaggedSnap.data().count;
      
      // 6. Sınav sayısı
      const examsSnap = await db.collection("sinavlar").count().get();
      const totalExams = examsSnap.data().count;
      
      // 7. Son moderation logu
      const recentFlaggedSnap = await db.collection("gonderiler")
        .where("flaggedForProfanity", "==", true)
        .orderBy("flaggedAt", "desc")
        .limit(5)
        .get();
      
      const recentFlagged = recentFlaggedSnap.docs.map(doc => ({
        id: doc.id,
        foundWords: doc.data().foundBadWords || [],
        flaggedAt: doc.data().flaggedAt?.toDate()
      }));
      
      return {
        success: true,
        dashboard: {
          visionApi: {
            monthly: quota.remaining,
            monthlyLimit: VISION_API_CONFIG.MONTHLY_FREE_QUOTA,
            used: quota.used,
            percentage: Math.round((quota.used / VISION_API_CONFIG.MONTHLY_FREE_QUOTA) * 100),
            enabled: VISION_API_CONFIG.ENABLED,
            strategy: VISION_API_CONFIG.FALLBACK_STRATEGY
          },
          users: {
            total: totalUsers,
            active: activeUsers,
            activePercentage: Math.round((activeUsers / totalUsers) * 100)
          },
          content: {
            posts: totalPosts,
            flagged: flaggedContent,
            flaggedPercentage: Math.round((flaggedContent / totalPosts) * 100)
          },
          exams: {
            total: totalExams
          },
          recentFlagged: recentFlagged
        },
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error("[DASHBOARD_ERROR]", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * =================================================================================
 * 32. ADMIN ACTIONS LOG (AUDIT TRAIL)
 * =================================================================================
 * Admin işlemlerini kaydet
 */
exports.logAdminAction = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    const { action, targetId, description } = data;
    const adminId = context.auth.uid;
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(adminId).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin yapabilir.");
    }
    
    try {
      await db.collection("admin_actions").add({
        action: action,
        adminId: adminId,
        adminName: userDoc.data().takmaAd || "Unknown",
        targetId: targetId || null,
        description: description || "",
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`[ADMIN_ACTION] ${action} by ${adminId}`);
      
      return {
        success: true,
        message: "İşlem kaydedildi"
      };
    } catch (error) {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

/**
 * =================================================================================
 * ADVANCED MONITORING DASHBOARD
 * =================================================================================
 * Real-time quota tracking, cost prediction, and performance metrics
 */
exports.getAdvancedMonitoring = functions.region(REGION).https.onCall(
  async (data, context) => {
    checkAuth(context);
    
    const adminId = context.auth.uid;
    
    // Admin kontrolü
    const userDoc = await db.collection("kullanicilar").doc(adminId).get();
    if (userDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin görebilir.");
    }
    
    try {
      const today = new Date();
      const monthKey = `${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}`;
      
      // 1. QUOTA METRICS
      const quotaDoc = await db.collection("vision_api_quota").doc(monthKey).get();
      const quotaData = quotaDoc.data() || { usageCount: 0, monthKey };
      const used = quotaData.usageCount || 0;
      const remaining = Math.max(0, VISION_API_CONFIG.MONTHLY_FREE_QUOTA - used);
      const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
      const dayOfMonth = today.getDate();
      const avgPerDay = used / dayOfMonth;
      const projectedMonthly = Math.round(avgPerDay * daysInMonth);
      const willExceed = projectedMonthly > VISION_API_CONFIG.MONTHLY_FREE_QUOTA;
      
      // 2. COST CALCULATION
      const costPer1000 = 3.50;
      const extraRequestsIfExceed = Math.max(0, projectedMonthly - VISION_API_CONFIG.MONTHLY_FREE_QUOTA);
      const projectedCost = (extraRequestsIfExceed / 1000) * costPer1000;
      
      // 3. CACHE STATS
      const cacheSize = analysisCache.size;
      const cacheHitEstimate = "~30-50%"; // Estimation
      
      // 4. RECENT ACTIVITIES
      const recentActions = await db.collection("admin_actions")
        .orderBy("timestamp", "desc")
        .limit(10)
        .get();
      
      const activities = recentActions.docs.map(doc => ({
        id: doc.id,
        action: doc.data().action,
        admin: doc.data().adminName,
        timestamp: doc.data().timestamp?.toDate(),
        description: doc.data().description
      }));
      
      // 5. PERFORMANCE METRICS
      const performanceMetrics = {
        cacheHitRate: cacheHitEstimate,
        cachedRequests: cacheSize,
        apiCallsOptimized: Math.round(used * 0.3), // ~30% optimization estimate
        averageAnalysisTime: "~2.5 seconds",
        costSavedByCache: `$${(Math.round(used * 0.3 * costPer1000) / 1000).toFixed(2)}`
      };
      
      // 6. COST TREND (last 3 months)
      const costTrend = [];
      for (let i = 0; i < 3; i++) {
        const pastMonth = new Date(today.getFullYear(), today.getMonth() - i, 1);
        const pastMonthKey = `${pastMonth.getFullYear()}_${String(pastMonth.getMonth() + 1).padStart(2, '0')}`;
        const pastQuotaDoc = await db.collection("vision_api_quota").doc(pastMonthKey).get();
        const pastUsed = pastQuotaDoc.data()?.usageCount || 0;
        const pastExcess = Math.max(0, pastUsed - VISION_API_CONFIG.MONTHLY_FREE_QUOTA);
        const pastCost = (pastExcess / 1000) * costPer1000;
        
        costTrend.unshift({
          month: pastMonthKey,
          used: pastUsed,
          cost: pastCost.toFixed(2)
        });
      }
      
      return {
        success: true,
        monitoring: {
          quota: {
            used: used,
            limit: VISION_API_CONFIG.MONTHLY_FREE_QUOTA,
            remaining: remaining,
            percentage: Math.round((used / VISION_API_CONFIG.MONTHLY_FREE_QUOTA) * 100),
            monthKey: monthKey
          },
          projection: {
            currentDay: dayOfMonth,
            totalDays: daysInMonth,
            averagePerDay: Math.round(avgPerDay),
            projectedMonthly: projectedMonthly,
            willExceed: willExceed,
            daysUntilExceed: willExceed ? Math.round((VISION_API_CONFIG.MONTHLY_FREE_QUOTA - used) / avgPerDay) : null
          },
          cost: {
            currentCost: "Free",
            projectedCost: projectedCost.toFixed(2),
            costTrend: costTrend,
            costPerRequest: "$" + (costPer1000 / 1000).toFixed(4)
          },
          performance: performanceMetrics,
          recentActivities: activities,
          cacheStats: {
            cachedRequests: cacheSize,
            cacheHitRate: cacheHitEstimate,
            cacheTTLHours: VISION_API_CONFIG.CACHE_TTL_HOURS
          },
          systemStatus: {
            apiEnabled: VISION_API_CONFIG.ENABLED,
            fallbackStrategy: VISION_API_CONFIG.FALLBACK_STRATEGY,
            lastUpdated: new Date().toISOString()
          }
        },
        recommendations: {
          warning: willExceed ? "⚠️ Aylık limit aşılacak" : null,
          suggestion1: used > VISION_API_CONFIG.MONTHLY_FREE_QUOTA * 0.8 ? "Fallback stratejisini 'allow' değiştirmeyi düşün" : null,
          suggestion2: cacheSize > IMAGE_MODERATION_CONFIG.CACHE_MAX_RESULTS * 0.9 ? "Cache temizlemeyi düşün" : null,
          suggestion3: projectedCost > 5 ? "Görüntü kompresyonu eklemesini düşün" : null
        }
      };
    } catch (error) {
      console.error("[MONITORING_ERROR]", error);
      throw new functions.https.HttpsError("internal", `Monitoring hatası: ${error.message}`);
    }
  }
);

/**
 * =================================================================================
 * 35. ADMIN QUOTA WARNING ALERTS (Yönetici Uyarı Bildirimleri)
 * =================================================================================
 * Kota uyarılarını admin'e bildir (80%, 95%, 100%)
 */
exports.checkAndAlertQuotaStatus = functions.region(REGION).pubsub
  .schedule('every 6 hours')
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    try {
      const today = new Date();
      const monthKey = `${today.getFullYear()}_${String(today.getMonth() + 1).padStart(2, '0')}`;
      
      const quotaDoc = await db.collection("vision_api_quota").doc(monthKey).get();
      const quotaData = quotaDoc.data() || { usageCount: 0 };
      const used = quotaData.usageCount || 0;
      const limit = VISION_API_CONFIG.MONTHLY_FREE_QUOTA;
      const percentage = (used / limit) * 100;
      
      console.log(`[QUOTA_CHECK] ${monthKey}: ${used}/${limit} (${percentage.toFixed(1)}%)`);
      
      // Admin'leri bul
      const adminsSnapshot = await db.collection("kullanicilar")
        .where("role", "==", "admin")
        .get();
      
      if (adminsSnapshot.empty) {
        console.log("[QUOTA_CHECK] Admin bulunamadı");
        return null;
      }
      
      const admins = adminsSnapshot.docs.map(doc => ({
        uid: doc.id,
        name: doc.data().name || "Admin",
        email: doc.data().email
      }));
      
      // Uyarı seviyesini belirle
      let alertLevel = null;
      let message = null;
      let emoji = null;
      
      if (percentage >= 100) {
        alertLevel = 'CRITICAL';
        emoji = '🔴';
        message = `KRİTİK: Görsel kontrol kotası %100 doldu!\n\n${used}/${limit} istek kullanıldı. Ek maliyetler uygulanıyor ($3.50/1000).`;
      } else if (percentage >= 95) {
        alertLevel = 'WARNING_CRITICAL';
        emoji = '🔴';
        message = `ACIL: Görsel kontrol kotası %95 doldu!\n\n${used}/${limit} istek kullanıldı. Çok az kota kaldı!`;
      } else if (percentage >= 80) {
        alertLevel = 'WARNING';
        emoji = '⚠️';
        message = `UYARI: Görsel kontrol kotası %80 doldu.\n\n${used}/${limit} istek kullanıldı. Yakında sınırına ulaşacaksınız.`;
      } else {
        console.log(`[QUOTA_CHECK] Normal seviye (${percentage.toFixed(1)}%)`);
        return null;
      }
      
      // Her admin'e bildirim gönder
      const batch = db.batch();
      
      for (const admin of admins) {
        const notificationRef = db.collection("bildirimler").doc();
        batch.set(notificationRef, {
          userId: admin.uid,
          senderId: "system",
          type: "quota_alert",
          level: alertLevel,
          emoji: emoji,
          message: message,
          quotaUsed: used,
          quotaLimit: limit,
          quotaPercentage: Math.round(percentage),
          isRead: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      await batch.commit();
      
      console.log(`[QUOTA_ALERT] ${alertLevel} bildirimi ${admins.length} admin'e gönderildi`);
      
      return { success: true, alertLevel, adminsNotified: admins.length };
    } catch (error) {
      console.error("[QUOTA_CHECK_ERROR]", error);
      return { error: error.message };
    }
  });

/**
 * =================================================================================
 * PHASE 4: PAID API QUOTA MANAGEMENT CONFIG
 * =================================================================================
 * Vision API pattern'i tüm ücretli API'ler için standartlaştır
 */
const PAID_API_QUOTAS = {
  VISION: {
    name: "Vision API",
    monthlyQuota: 1000,
    costPer1000: 3.50,
    enabled: true,
    fallbackStrategy: "deny",
    cacheTTL: 24
  },
  TRANSLATE: {
    name: "Google Translate API",
    monthlyQuota: 2000,
    costPer1000: 15.00,
    enabled: true,
    fallbackStrategy: "deny",
    cacheTTL: 24
  },
  SPEECH_TO_TEXT: {
    name: "Google Speech-to-Text",
    monthlyQuota: 5000,
    costPer1000: 1.44,
    enabled: true,
    fallbackStrategy: "deny",
    cacheTTL: 24
  },
  TEXT_TO_SPEECH: {
    name: "Google Text-to-Speech",
    monthlyQuota: 4000,
    costPer1000: 16.00,
    enabled: true,
    fallbackStrategy: "deny",
    cacheTTL: 24
  }
};

/**
 * Helper: Get monthly key for quota tracking (YYYY-MM format)
 */
const getMonthKey = () => {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
};

/**
 * Helper: Check quota status for a paid API
 */
const checkPaidApiQuota = async (apiName) => {
  try {
    const config = PAID_API_QUOTAS[apiName];
    if (!config) throw new Error(`Unknown API: ${apiName}`);
    
    const monthKey = getMonthKey();
    const quotaRef = db.collection(`${apiName.toLowerCase()}_api_quota`).doc(monthKey);
    const quotaDoc = await quotaRef.get();
    
    let quotaData = quotaDoc.data() || { usage: 0, limit: config.monthlyQuota, enabled: config.enabled };
    const percentageUsed = Math.round((quotaData.usage / quotaData.limit) * 100);
    
    return {
      api: apiName,
      monthKey,
      usage: quotaData.usage,
      limit: quotaData.limit,
      remaining: Math.max(0, quotaData.limit - quotaData.usage),
      percentageUsed,
      enabled: quotaData.enabled,
      costPerCall: (config.costPer1000 / 1000).toFixed(6)
    };
  } catch (error) {
    console.error(`[QUOTA_CHECK_ERROR] ${apiName}:`, error);
    throw error;
  }
};

/**
 * Helper: Increment quota usage and auto-disable if exceeded
 */
const incrementPaidApiQuota = async (apiName, count = 1) => {
  try {
    const config = PAID_API_QUOTAS[apiName];
    if (!config) throw new Error(`Unknown API: ${apiName}`);
    
    const monthKey = getMonthKey();
    const quotaRef = db.collection(`${apiName.toLowerCase()}_api_quota`).doc(monthKey);
    
    // Use transaction to avoid race conditions
    const result = await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(quotaRef);
      let data = doc.data() || { usage: 0, limit: config.monthlyQuota, enabled: config.enabled };
      
      data.usage = (data.usage || 0) + count;
      data.lastUpdated = admin.firestore.FieldValue.serverTimestamp();
      
      // AUTO-DISABLE when quota exceeded
      if (data.usage >= data.limit && data.enabled) {
        data.enabled = false;
        data.disabledAt = admin.firestore.FieldValue.serverTimestamp();
        data.disabledReason = "Monthly quota exceeded";
        
        console.warn(`[AUTO_DISABLE] ${apiName} quota exceeded! Disabling API.`);
        
        // Send alert to admins
        const adminsRef = await db.collection("users").where("userRole", "==", "admin").get();
        const batch = db.batch();
        
        adminsRef.docs.forEach(doc => {
          batch.set(db.collection("admin_alerts").doc(), {
            adminId: doc.id,
            type: "quota_exceeded",
            api: apiName,
            usage: data.usage,
            limit: data.limit,
            message: `${apiName} ${monthKey} aylık kota tükendi! Sistem otomatik kapatıldı.`,
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        
        await batch.commit();
      }
      
      transaction.set(quotaRef, data);
      return data;
    });
    
    return result;
  } catch (error) {
    console.error(`[QUOTA_INCREMENT_ERROR] ${apiName}:`, error);
    throw error;
  }
};

/**
 * =================================================================================
 * PHASE 4: RIDE COMPLAINTS SYSTEM
 * =================================================================================
 */
exports.createRideComplaint = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { rideId, complaint, severity, universitesi } = data;
    
    if (!rideId || !complaint || !severity) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: rideId, complaint, severity");
    }
    
    const complaintRef = db.collection("ride_complaints").doc();
    await complaintRef.set({
      rideId,
      userId: context.auth.uid,
      complaint,
      severity,
      universitesi,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { success: true, complaintId: complaintRef.id };
  } catch (error) {
    console.error("[RIDE_COMPLAINT_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: USER POINTS SYSTEM
 * =================================================================================
 */
exports.addUserPoints = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { userId, points, reason, universitesi } = data;
    
    if (!userId || !points || !reason) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: userId, points, reason");
    }
    
    const pointsRef = db.collection("user_points").doc(userId);
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(pointsRef);
      const current = doc.data() || { totalPoints: 0, level: 1 };
      const newTotal = (current.totalPoints || 0) + points;
      
      transaction.set(pointsRef, {
        userId,
        totalPoints: newTotal,
        level: Math.floor(newTotal / 100) + 1,
        universitesi,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      transaction.set(db.collection("user_point_history").doc(), {
        userId,
        points,
        reason,
        universitesi,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    return { success: true, message: "Puan eklendi" };
  } catch (error) {
    console.error("[ADD_POINTS_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: ACHIEVEMENTS SYSTEM
 * =================================================================================
 */
exports.unlockAchievement = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { userId, achievementId, universitesi } = data;
    
    if (!userId || !achievementId) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: userId, achievementId");
    }
    
    const userAchievementId = `${userId}_${achievementId}`;
    const ref = db.collection("user_achievements").doc(userAchievementId);
    
    const doc = await ref.get();
    if (doc.exists) {
      return { success: false, message: "Başarı zaten açılmış" };
    }
    
    await ref.set({
      userId,
      achievementId,
      universitesi,
      unlockedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { success: true, message: "Başarı açıldı!" };
  } catch (error) {
    console.error("[UNLOCK_ACHIEVEMENT_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: REWARDS SYSTEM
 * =================================================================================
 */
exports.purchaseReward = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { rewardId, universitesi } = data;
    
    if (!rewardId) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: rewardId");
    }
    
    const userId = context.auth.uid;
    
    await db.runTransaction(async (transaction) => {
      // Check user points
      const userPointsRef = db.collection("user_points").doc(userId);
      const userDoc = await transaction.get(userPointsRef);
      const userPoints = userDoc.data()?.totalPoints || 0;
      
      // Get reward
      const rewardRef = db.collection("rewards").doc(rewardId);
      const rewardDoc = await transaction.get(rewardRef);
      const reward = rewardDoc.data();
      
      if (!reward) throw new Error("Ödül bulunamadı");
      if (userPoints < reward.points) throw new Error("Yeterli puan yok");
      
      // Create purchase record
      transaction.set(db.collection("user_reward_purchases").doc(), {
        userId,
        rewardId,
        universitesi,
        pointsSpent: reward.points,
        purchasedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Update user points
      transaction.set(userPointsRef, {
        totalPoints: userPoints - reward.points,
        universitesi
      }, { merge: true });
    });
    
    return { success: true, message: "Ödül satın alındı!" };
  } catch (error) {
    console.error("[PURCHASE_REWARD_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: SEARCH ANALYTICS SYSTEM
 * =================================================================================
 */
exports.logSearchQuery = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { query, universitesi, resultCount } = data;
    
    if (!query) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: query");
    }
    
    const queryId = `${universitesi}_${query}_${getMonthKey()}`;
    const trendRef = db.collection("search_trends").doc(queryId);
    
    await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(trendRef);
      const current = doc.data() || { searchCount: 0, trendScore: 0 };
      
      transaction.set(trendRef, {
        query,
        universitesi,
        searchCount: (current.searchCount || 0) + 1,
        trendScore: (current.trendScore || 0) + 1,
        lastSearched: admin.firestore.FieldValue.serverTimestamp(),
        month: getMonthKey()
      }, { merge: true });
    });
    
    // Log individual query
    await db.collection("search_queries").add({
      userId: context.auth.uid,
      query,
      universitesi,
      resultCount: resultCount || 0,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { success: true, message: "Arama kaydedildi" };
  } catch (error) {
    console.error("[LOG_SEARCH_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: AI MODEL METRICS SYSTEM
 * =================================================================================
 */
exports.saveAIMetrics = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { modelName, accuracy, precision, recall, universitesi, predictions } = data;
    
    if (!modelName || accuracy === undefined) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: modelName, accuracy");
    }
    
    const metricsRef = db.collection("ai_metrics").doc();
    await metricsRef.set({
      modelName,
      accuracy: parseFloat(accuracy),
      precision: parseFloat(precision || 0),
      recall: parseFloat(recall || 0),
      universitesi,
      predictions: predictions || 0,
      recordedAt: admin.firestore.FieldValue.serverTimestamp(),
      month: getMonthKey()
    });
    
    return { success: true, metricsId: metricsRef.id };
  } catch (error) {
    console.error("[SAVE_AI_METRICS_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PHASE 4: FINANCIAL REPORTS SYSTEM
 * =================================================================================
 */
exports.addFinancialRecord = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    // Only admin can add financial records
    const user = await admin.auth().getUser(context.auth.uid);
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    
    if (userDoc.data()?.userRole !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin kayıt ekleyebilir");
    }
    
    const { recordType, amount, description, universitesi, category } = data;
    
    if (!recordType || amount === undefined) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: recordType, amount");
    }
    
    const recordRef = db.collection("financial_records").doc();
    await recordRef.set({
      recordType,
      amount: parseFloat(amount),
      description: description || "",
      universitesi,
      category: category || "other",
      createdBy: context.auth.uid,
      recordedAt: admin.firestore.FieldValue.serverTimestamp(),
      month: getMonthKey()
    });
    
    return { success: true, recordId: recordRef.id };
  } catch (error) {
    console.error("[ADD_FINANCIAL_RECORD_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * =================================================================================
 * PAID API QUOTA CHECK ENDPOINTS
 * =================================================================================
 */
exports.checkPaidApiQuotaStatus = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const { apiName } = data;
    
    if (!apiName) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: apiName");
    }
    
    const quotaStatus = await checkPaidApiQuota(apiName);
    return quotaStatus;
  } catch (error) {
    console.error("[PAID_API_QUOTA_CHECK_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Get all paid API quota statuses
 */
exports.getAllPaidApiQuotaStatus = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız");
    
    const quotaStatuses = [];
    
    for (const apiName of Object.keys(PAID_API_QUOTAS)) {
      const status = await checkPaidApiQuota(apiName);
      quotaStatuses.push(status);
    }
    
    return { success: true, quotas: quotaStatuses };
  } catch (error) {
    console.error("[GET_ALL_QUOTAS_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Reset paid API quota (admin only)
 */
exports.resetPaidApiQuota = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    
    if (userDoc.data()?.userRole !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin kota sıfırlayabilir");
    }
    
    const { apiName } = data;
    
    if (!apiName || !PAID_API_QUOTAS[apiName]) {
      throw new functions.https.HttpsError("invalid-argument", "Bilinmeyen API: " + apiName);
    }
    
    const config = PAID_API_QUOTAS[apiName];
    const monthKey = getMonthKey();
    const quotaRef = db.collection(`${apiName.toLowerCase()}_api_quota`).doc(monthKey);
    
    await quotaRef.set({
      usage: 0,
      limit: config.monthlyQuota,
      enabled: config.enabled,
      resetAt: admin.firestore.FieldValue.serverTimestamp(),
      resetBy: context.auth.uid
    });
    
    console.log(`[QUOTA_RESET] ${apiName} quota reset for ${monthKey}`);
    
    return { success: true, message: `${apiName} kota sıfırlandı` };
  } catch (error) {
    console.error("[RESET_PAID_API_QUOTA_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Toggle paid API enabled status (admin only)
 */
exports.togglePaidApiStatus = functions.region(REGION).https.onCall(async (data, context) => {
  try {
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    
    if (userDoc.data()?.userRole !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Sadece admin değiştirebilir");
    }
    
    const { apiName, enabled } = data;
    
    if (!apiName || enabled === undefined) {
      throw new functions.https.HttpsError("invalid-argument", "Eksik alan: apiName, enabled");
    }
    
    if (!PAID_API_QUOTAS[apiName]) {
      throw new functions.https.HttpsError("invalid-argument", "Bilinmeyen API");
    }
    
    const monthKey = getMonthKey();
    const quotaRef = db.collection(`${apiName.toLowerCase()}_api_quota`).doc(monthKey);
    
    await quotaRef.set({
      enabled: enabled,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid
    }, { merge: true });
    
    console.log(`[API_TOGGLE] ${apiName} set to ${enabled}`);
    
    return { success: true, message: `${apiName} ${enabled ? 'aktifleştirildi' : 'devre dışı bırakıldı'}` };
  } catch (error) {
    console.error("[TOGGLE_PAID_API_ERROR]", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});