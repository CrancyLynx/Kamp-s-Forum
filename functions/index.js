const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");

admin.initializeApp();
const db = admin.firestore();

// --- AYARLAR ---
const REGION = "europe-west1";

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

    // 5. Rate limiting - her kullanıcı en fazla dakikada 5 bildirim
    try {
      const oneMinuteAgo = new Date(Date.now() - 60000);
      const recentNotifs = await db.collection("bildirimler")
        .where("userId", "==", userId)
        .where("timestamp", ">=", oneMinuteAgo)
        .get();

      if (recentNotifs.size >= 5) {
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