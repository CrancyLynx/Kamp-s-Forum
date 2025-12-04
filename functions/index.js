const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");
const vision = require("@google-cloud/vision");

admin.initializeApp();
const db = admin.firestore();
const visionClient = new vision.ImageAnnotatorClient();

// --- AYARLAR ---
const REGION = "europe-west1";

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
  
  // Max dosya boyutu (10MB)
  MAX_SIZE: 10 * 1024 * 1024,
};

const checkAuth = (context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");
  }
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

// Scrapes exam data from ÖSYM's website for a given year
const scrapeOsymExams = async (year) => {
  try {
    const urls = {
      2025: "https://www.osym.gov.tr/TR,8709/2025-yili-sinav-takvimi.html",
      2026: "https://www.osym.gov.tr/TR,29560/2026-yili-sinav-takvimi.html"
    };

    const url = urls[year];
    if (!url) {
      console.error(`No URL found for year: ${year}`);
      return [];
    }

    const { data } = await axios.get(url);
    const $ = cheerio.load(data);
    const exams = [];
    const relevantExams = ["KPSS", "YKS", "ALES", "DGS", "TUS", "DUS", "YÖKDİL"];

    $('table.table > tbody > tr').each((i, el) => {
      const examName = $(el).find('td:nth-child(1)').text().trim();
      
      if (relevantExams.some(keyword => examName.includes(keyword))) {
        const examDateStr = $(el).find('td:nth-child(2)').text().trim();
        const appStartDateStr = $(el).find('td:nth-child(3)').text().trim();
        const resultDateStr = $(el).find('td:nth-child(4)').text().trim();

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
            importance: 'high'
          });
        }
      }
    });

    return exams;
  } catch (error) {
    console.error(`Error scraping ÖSYM website for year ${year}:`, error);
    return []; // Return an empty array on error
  }
};

// HTTP isteği ile sınav tarihlerini güncelle (manuel tetikleme)
exports.updateExamDates = functions.region(REGION).https.onCall(
  async (data, context) => {
    try {
      const exams2025 = await scrapeOsymExams(2025);
      const exams2026 = await scrapeOsymExams(2026);
      const examDates = [...exams2025, ...exams2026];
      
      const batch = db.batch();
      let updateCount = 0;

      for (const exam of examDates) {
        const docRef = db.collection('sinavlar').doc(exam.id);
        batch.set(docRef, {
          ...exam,
          date: admin.firestore.Timestamp.fromDate(exam.date),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          source: exam.source || 'OSYM'
        }, { merge: true });
        updateCount++;
      }

      await batch.commit();

      return {
        success: true,
        message: `${updateCount} sınav tarihi başarıyla güncellendi`,
        count: updateCount,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('Sınav tarihleri güncelleme hatası:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Sınav tarihleri güncellenemedi: ' + error.message
      );
    }
  }
);

// Firestore Trigger: Her gün saat 00:00'da otomatik kontrol et
exports.scheduleExamDatesUpdate = functions.region(REGION)
  .pubsub.schedule('0 0 * * *') // Her gün saat 00:00
  .timeZone('Europe/Istanbul')
  .onRun(async (context) => {
    try {
      const exams2025 = await scrapeOsymExams(2025);
      const exams2026 = await scrapeOsymExams(2026);
      const examDates = [...exams2025, ...exams2026];
      const batch = db.batch();
      let updateCount = 0;
      const now = new Date();

      for (const exam of examDates) {
        // Geçmiş sınavları silme (1 haftadan daha eski)
        const examDate = exam.date;
        const daysDiff = (examDate - now) / (1000 * 60 * 60 * 24);

        const docRef = db.collection('sinavlar').doc(exam.id);

        if (daysDiff < -7) {
          // Geçmiş sınavları sil
          batch.delete(docRef);
          console.log(`[DELETE] ${exam.name} silindi (${daysDiff.toFixed(0)} gün önce)`);
        } else {
          // Mevcut sınavları güncelle veya ekle
          batch.set(docRef, {
            ...exam,
            date: admin.firestore.Timestamp.fromDate(exam.date),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: exam.source || 'OSYM'
          }, { merge: true });
          updateCount++;
        }
      }

      await batch.commit();

      console.log(`[SUCCESS] Sınav takvimi otomatik güncelleme tamamlandı. ${updateCount} sınav aktif.`);

      return {
        success: true,
        message: 'Sınav takvimi başarıyla güncellendi',
        updatedCount: updateCount,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('[ERROR] Sınav tarihleri otomatik güncelleme hatası:', error);
      return {
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
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
 * PROFANITY VE KÖTÜ KELIME LİSTESİ (CİDDİ OLANLAR SADECE)
 * =================================================================================
 * NOT: Hafif olan kelimeler (aptal, sarışın, kız vb) kaldırıldı
 */
const PROFANITY_WORDS = [
  // Türkçe ciddi kötü kelimeler (cinsel ve nefret söylemi)
  "orospu", "piç", "bok", "sikeyim", "çüğü", "şerefsiz", "namussuz",
  "göt", "sıç", "sapık", "pedofil", "ensest",
  
  // İngilizce ciddi kötü kelimeler
  "fuck", "shit", "cunt", "bastard", "asshole", "whore", "bitch",
  "dick", "prick", "motherfucker",
  
  // Spam ve aldatmaca kelimeleri
  "viagra", "casino", "bet", "click here", "free money", "xxx",
  "loto", "iddia", "at yarışı",
  
  // Nefret söylemi ve terörizm/şiddet tehditleri
  "terörist", "öldür", "bomba", "silah", "intihar",
];

const SPAM_KEYWORDS = ["viagra", "casino", "bet", "click here", "free money", "xxx", "loto", "iddia"];

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
 * Vision API ile resim analiz et
 */
const analyzeImageWithVision = async (imagePath) => {
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

    return {
      adult: detection.adult || 'UNKNOWN',
      racy: detection.racy || 'UNKNOWN',
      violence: detection.violence || 'UNKNOWN',
      medical: detection.medical || 'UNKNOWN',
      spoof: detection.spoof || 'UNKNOWN',
      raw: detection
    };
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
 * Resim güvenliği kontrolü
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
    // Hata durumunda güvenli olmayan kabul et
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

    if (safetyResult.isUnsafe) {
      console.log(`[UNSAFE] Uygunsuz resim: ${safetyResult.blockedReasons.join(", ")}`);
      
      return {
        success: false,
        isUnsafe: true,
        message: `⚠️ Resminiz uygunsuz içerik içeriyor:\n${safetyResult.blockedReasons.join("\n")}\n\nLütfen başka bir resim seçin.`,
        blockedReasons: safetyResult.blockedReasons,
        scores: {
          adult: (safetyResult.adultScore * 100).toFixed(0),
          racy: (safetyResult.racyScore * 100).toFixed(0),
          violence: (safetyResult.violenceScore * 100).toFixed(0)
        }
      };
    } else {
      console.log(`[SAFE] Resim güvenli - yüklenmesine izin ver`);
      
      return {
        success: true,
        isUnsafe: false,
        message: "✅ Resim güvenlik kontrolünü geçti! Yükleyebilirsiniz.",
        scores: {
          adult: (safetyResult.adultScore * 100).toFixed(0),
          racy: (safetyResult.racyScore * 100).toFixed(0),
          violence: (safetyResult.violenceScore * 100).toFixed(0)
        }
      };
    }
  } catch (error) {
    console.error("Resim analiz hatası:", error);
    throw new functions.https.HttpsError("internal", `Resim analizi başarısız: ${error.message}`);
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