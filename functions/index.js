const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// --- AYARLAR ---
const ADMIN_UIDS = ["oZ2RIhV1JdYVIr0xyqCwhX9fJYq1", "VD8MeJIhhRVtbT9iiUdMEaCe3MO2"];
const REGION = "europe-west1";

const checkAuth = (context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Giriş yapmalısınız.");
  }
};

/**
 * =================================================================================
 * 1. BİLDİRİM GÖNDERİCİ (FCM TRIGGER)
 * GÜNCELLEME: Firebase Admin SDK v13+ uyumlu "sendEachForMulticast" kullanıldı.
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

      // YENİ API YAPISI (Multicast)
      const message = {
        tokens: tokens,
        notification: {
          title: "Kampüs Forum",
          body: notificationData.message || "Yeni bir bildiriminiz var.",
        },
        // Android ve iOS için ses ayarları ve data payload
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

      // Eski sendToDevice yerine sendEachForMulticast kullanıyoruz
      const response = await admin.messaging().sendEachForMulticast(message);

      const tokensToRemove = [];
      
      // Yanıt yapısı da değişti: response.results yerine response.responses
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

      console.log(`Bildirim başarıyla gönderildi: ${userId}, Başarılı: ${response.successCount}, Başarısız: ${response.failureCount}`);
      return {success: true};
    } catch (error) {
      console.error("Bildirim gönderme hatası:", error);
      return null;
    }
  });

// --- DİĞER MEVCUT FONKSİYONLAR ---

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

exports.deletePost = functions.region(REGION).https.onCall(async (data, context) => {
  checkAuth(context);
  const postId = data.postId;
  const requesterUid = context.auth.uid;

  if (!postId) throw new functions.https.HttpsError("invalid-argument", "Post ID eksik.");

  const postRef = db.collection("gonderiler").doc(postId);
  const postDoc = await postRef.get();

  if (!postDoc.exists) throw new functions.https.HttpsError("not-found", "Gönderi bulunamadı.");

  const postData = postDoc.data();
  const authorId = postData.userId;
  const isAdmin = ADMIN_UIDS.includes(requesterUid);

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

exports.deleteUserAccount = functions.region(REGION).https.onCall(async (data, context) => {
  const targetUserId = data.userId || context.auth.uid;
  if (targetUserId !== context.auth.uid && !ADMIN_UIDS.includes(context.auth.uid)) {
    throw new functions.https.HttpsError("permission-denied", "Yetkiniz yok.");
  }

  const batch = db.batch();

  const postsQuery = await db.collection("gonderiler").where("userId", "==", targetUserId).get();
  postsQuery.docs.forEach((doc) => batch.delete(doc.ref));

  const commentsQuery = await db.collectionGroup("yorumlar").where("userId", "==", targetUserId).get();
  commentsQuery.docs.forEach((doc) => batch.delete(doc.ref));

  const userRef = db.collection("kullanicilar").doc(targetUserId);
  batch.delete(userRef);

  await batch.commit();

  try {
    const bucket = admin.storage().bucket();
    // Dosya yoksa hata vermemesi için try-catch içinde
    await bucket.file(`profil_resimleri/${targetUserId}.jpg`).delete().catch(() => {});
  } catch (e) {
    console.log("Storage silme hatası (önemsiz):", e);
  }

  try {
    await admin.auth().deleteUser(targetUserId);
    return {success: true};
  } catch (error) {
    console.error("Auth silme hatası:", error);
    return {success: true, message: "Veriler silindi, Auth silinemedi veya kullanıcı yok."};
  }
});

exports.onUserCreated = functions.region(REGION).firestore
  .document("kullanicilar/{userId}")
  .onCreate((snap, context) => {
    return snap.ref.set({
      postCount: 0, commentCount: 0, likeCount: 0, followerCount: 0, followingCount: 0,
      earnedBadges: [], followers: [], following: [], savedPosts: [],
      isOnline: false, status: "Unverified",
      kayit_tarihi: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });