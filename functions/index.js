const functions = require("firebase-functions");
const admin = require("firebase-admin");

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
    const userId = notificationData.userId;

    // Kendi kendine bildirim gönderme
    if (notificationData.senderId === userId) return null;

    try {
      const userDoc = await db.collection("kullanicilar").doc(userId).get();

      if (!userDoc.exists) return null;

      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];

      if (tokens.length === 0) return null;

      const message = {
        tokens: tokens,
        notification: {
          title: "Kampüs Forum",
          body: notificationData.message || "Yeni bir bildiriminiz var.",
        },
        android: {
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: notificationData.type || "general",
          postId: notificationData.postId || "",
          chatId: notificationData.chatId || "",
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      const tokensToRemove = [];
      response.responses.forEach((result, index) => {
        const error = result.error;
        if (error) {
          console.error("FCM Hatası:", error.code, error.message);
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
        console.log(`${tokensToRemove.length} geçersiz token silindi.`);
      }

      return {success: true};
    } catch (error) {
      console.error("Bildirim gönderme hatası:", error);
      return null;
    }
  });

/**
 * =================================================================================
 * 2. USER AVATAR GÜNCELLEME (TRIGGER)
 * =================================================================================
 */
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

/**
 * =================================================================================
 * 3. GÖNDERİ SİLME (CALLABLE - GÜNCELLENDİ)
 * Artık veritabanındaki 'role' alanını kontrol ediyor.
 * =================================================================================
 */
exports.deletePost = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const postId = data.postId;
  const requesterUid = context.auth.uid;

  if (!postId) throw new functions.https.HttpsError("invalid-argument", "Post ID eksik.");

  // İstek yapan kullanıcının verilerini çek (Admin mi?)
  const requesterDoc = await db.collection("kullanicilar").doc(requesterUid).get();
  const requesterData = requesterDoc.data() || {};
  const isAdmin = requesterData.role === "admin";

  const postRef = db.collection("gonderiler").doc(postId);
  const postDoc = await postRef.get();

  if (!postDoc.exists) throw new functions.https.HttpsError("not-found", "Gönderi bulunamadı.");

  const postData = postDoc.data();
  const authorId = postData.userId;

  // Sadece sahibi veya Admin silebilir
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

/**
 * =================================================================================
 * 4. HESAP SİLME (ANONİMLEŞTİRME / SOFT DELETE)
 * Kullanıcının verilerini silmek yerine ismini "Silinmiş Üye" yapar.
 * Forum bütünlüğü korunur, kişisel veriler (resim, isim) yok edilir.
 * =================================================================================
 */
exports.deleteUserAccount = functions.region(REGION).https.onCall(async (data, context) => {
  const requesterUid = context.auth.uid;
  // Hedef kullanıcı ID'si gelmezse, isteği yapan kişi kendi hesabını siliyordur.
  const targetUserId = data.userId || requesterUid;

  // Yetki Kontrolü
  if (targetUserId !== requesterUid) {
    const requesterDoc = await db.collection("kullanicilar").doc(requesterUid).get();
    const requesterData = requesterDoc.data() || {};
    if (requesterData.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "Yetkiniz yok.");
    }
  }

  // YARDIMCI FONKSİYON: Batch ile toplu güncelleme (Chunking)
  async function anonymizeQueryBatch(query, resolve) {
    const snapshot = await query.get();
    const batchSize = snapshot.size;
    if (batchSize === 0) {
      resolve();
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      // Belgeyi silmiyoruz, anonimleştiriyoruz
      batch.update(doc.ref, {
        userId: 'deleted_user',      // Artık bu gönderi kimseye ait değil
        takmaAd: 'Silinmiş Üye',     // İsim gizlendi
        userAvatar: null,            // (Yorumlar için) Avatar kaldırıldı
        avatarUrl: null              // (Gönderiler için) Avatar kaldırıldı
      });
    });
    await batch.commit();

    process.nextTick(() => {
      anonymizeQueryBatch(query, resolve);
    });
  }

  // 1. Gönderileri Anonimleştir
  const postsQuery = db.collection("gonderiler").where("userId", "==", targetUserId).limit(500);
  await new Promise((resolve, reject) => anonymizeQueryBatch(postsQuery, resolve).catch(reject));

  // 2. Yorumları Anonimleştir
  const commentsQuery = db.collectionGroup("yorumlar").where("userId", "==", targetUserId).limit(500);
  await new Promise((resolve, reject) => anonymizeQueryBatch(commentsQuery, resolve).catch(reject));

  // 3. Profil Resmini Storage'dan SİL (Bu kişisel veridir, kesin silinmeli)
  try {
    const bucket = admin.storage().bucket();
    await bucket.file(`profil_resimleri/${targetUserId}.jpg`).delete().catch(() => {});
  } catch (e) {
    console.log("Storage silme hatası (önemsiz):", e);
  }

  // 4. Sohbetlerdeki Durum (Opsiyonel ama önerilir)
  // Sohbet geçmişi kalsın ama katılımcı listesinden çıksın veya ismi değişsin istenebilir.
  // Şimdilik sohbetlere dokunmuyoruz, kullanıcı Auth'dan silinince zaten giriş yapamaz.

  // 5. Kullanıcı Dokümanını Tamamen SİL
  // Artık giriş yapamayacağı için profil verisine gerek yok.
  await db.collection("kullanicilar").doc(targetUserId).delete();

  // 6. Auth Kaydını Sil
  try {
    await admin.auth().deleteUser(targetUserId);
    return {success: true, message: "Hesap anonimleştirilerek silindi."};
  } catch (error) {
    console.error("Auth silme hatası:", error);
    return {success: true, message: "Veriler anonimleştirildi, Auth silinemedi."};
  }
});

/**
 * =================================================================================
 * 5. KULLANICI OLUŞTURULDUĞUNDA (TRIGGER - GÜNCELLENDİ)
 * Otomatik olarak 'role: user' ekliyoruz.
 * =================================================================================
 */
exports.onUserCreated = functions.region(REGION).firestore
  .document("kullanicilar/{userId}")
  .onCreate((snap, context) => {
    return snap.ref.set({
      postCount: 0, commentCount: 0, likeCount: 0, followerCount: 0, followingCount: 0,
      earnedBadges: [], followers: [], following: [], savedPosts: [],
      isOnline: false, status: "Unverified",
      role: "user", // VARSAYILAN ROL
      kayit_tarihi: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    

  });
  
  /**
 * =================================================================================
 * 6. SAYAÇ YÖNETİMİ: BİLDİRİMLER (YENİ)
 * Bildirim eklenince, silinince veya okununca sayacı günceller.
 * =================================================================================
 */
exports.onNotificationWrite = functions.region(REGION).firestore
  .document("bildirimler/{notificationId}")
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() : null;
    const afterData = change.after.exists ? change.after.data() : null;

    // İşlem yapılan kullanıcı ID'si (Silindiyse eskiden al, eklendiyse yeniden al)
    const userId = beforeData ? beforeData.userId : afterData.userId;
    if (!userId) return null;

    let incrementValue = 0;

    // 1. Yeni Bildirim Eklendi (Okunmamışsa artır)
    if (!beforeData && afterData) {
      if (!afterData.isRead) incrementValue = 1;
    }
    // 2. Bildirim Silindi (Okunmamışsa azalt)
    else if (beforeData && !afterData) {
      if (!beforeData.isRead) incrementValue = -1;
    }
    // 3. Bildirim Güncellendi (Okundu durumu değiştiyse)
    else if (beforeData && afterData) {
      const wasRead = beforeData.isRead || false;
      const isRead = afterData.isRead || false;

      if (!wasRead && isRead) incrementValue = -1; // Okundu işaretlendi -> Azalt
      if (wasRead && !isRead) incrementValue = 1;  // Okunmadı işaretlendi -> Artır
    }

    if (incrementValue === 0) return null;

    return db.collection("kullanicilar").doc(userId).update({
      unreadNotifications: admin.firestore.FieldValue.increment(incrementValue)
    }).catch(err => console.log("Sayaç güncelleme hatası (önemsiz):", err));
  });
  /**
 * =================================================================================
 * 7. SAYAÇ YÖNETİMİ: MESAJLAR (YENİ)
 * Sohbetlerdeki 'unreadCount' haritası değiştiğinde toplam sayıyı günceller.
 * =================================================================================
 */
exports.onChatWrite = functions.region(REGION).firestore
  .document("sohbetler/{chatId}")
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() : {};
    const afterData = change.after.exists ? change.after.data() : {};

    const beforeCounts = beforeData.unreadCount || {};
    const afterCounts = afterData.unreadCount || {};

    // Sohbetin tüm katılımcılarını bul (Hem eski hem yeni listeyi birleştir)
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
        // Toplam sayıyı güncelle
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

  /**
 * =================================================================================
 * 8. BAKIM MODU: SAYAÇLARI SIFIRDAN HESAPLA (YENİ - CALLABLE)
 * Mevcut kullanıcıların sayaçları yanlışsa veya null ise bunu çalıştırıp düzeltebilirsin.
 * =================================================================================
 */

  exports.recalculateUserCounters = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const targetUserId = context.auth.uid; // Sadece kendi sayacını düzeltebilir

  // 1. Okunmamış Bildirimleri Say
  const notifSnap = await db.collection("bildirimler")
    .where("userId", "==", targetUserId)
    .where("isRead", "==", false)
    .count()
    .get();
  
  const unreadNotifCount = notifSnap.data().count;

  // 2. Okunmamış Mesajları Say (Burası biraz daha maliyetli ama tek seferlik)
  // Not: count() fonksiyonu map içindeki değerleri toplayamaz, mecburen dökümanları çekeceğiz.
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

  // 3. Kullanıcıyı Güncelle
  await db.collection("kullanicilar").doc(targetUserId).update({
    unreadNotifications: unreadNotifCount,
    totalUnreadMessages: totalUnreadMsg
  });

  return { 
    success: true, 
    message: `Sayaçlar güncellendi. Bildirim: ${unreadNotifCount}, Mesaj: ${totalUnreadMsg}` 
  };
  });