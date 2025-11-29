// Firebase Functions V2 modüllerini içe aktarın
const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {onCall, HttpsError} =
  require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// --- AYARLAR ---
const ADMIN_UIDS = [
  "oZ2RIhV1JdYVIr0xyqCwhX9fJYq1",
  "VD8MeJIhhRVtbT9iiUdMEaCe3MO2",
];
const REGION = "europe-west1";

// checkAuth fonksiyonu V2'deki HttpsError'ı kullanmak için güncellendi
const checkAuth = (context) => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Giriş yapmalısınız.");
  }
};

/**
 * =================================================================================
 * 1. BİLDİRİM GÖNDERİCİ (FCM TRIGGER) - V2
 * =================================================================================
 */
exports.sendPushNotificationV2 = onDocumentCreated(
  {
    document: "bildirimler/{notificationId}",
    region: REGION,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const notificationData = snap.data();
    const userId = notificationData.userId;

    if (notificationData.senderId === userId) return null;

    try {
      const userDoc = await db.collection("kullanicilar").doc(userId).get();

      if (!userDoc.exists) {
        console.log(`Kullanıcı dokümanı bulunamadı: ${userId}`);
        return null;
      }

      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];

      if (tokens.length === 0) {
        console.log(`Kullanıcının tokenı yok: ${userId}`);
        return null;
      }

      const payload = {
        notification: {
          title: "Kampüs Forum",
          body: notificationData.message || "Yeni bir bildiriminiz var.",
          sound: "default",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: notificationData.type || "general",
          postId: notificationData.postId || "",
          chatId: notificationData.chatId || "",
        },
      };

      const response = await admin.messaging().sendToDevice(tokens, payload);

      const tokensToRemove = [];
      response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
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

      console.log(`Bildirim başarıyla gönderildi: ${userId}`);
      return {success: true};
    } catch (error) {
      console.error("Bildirim gönderme hatası:", error);
      return null;
    }
  }
);

/**
 * =================================================================================
 * onUserAvatarUpdate - V2
 * =================================================================================
 */
exports.onUserAvatarUpdateV2 = onDocumentUpdated(
  {
    document: "kullanicilar/{userId}",
    region: REGION,
  },
  async (event) => {
    const change = event.data;
    if (!change) return null;

    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = event.params.userId;

    if (beforeData.avatarUrl === afterData.avatarUrl) return null;

    const newAvatarUrl = afterData.avatarUrl || "";
    const batch = db.batch();

    const postsSnapshot = await db.collection("gonderiler")
      .where("userId", "==", userId).get();
    postsSnapshot.docs.forEach((doc) => batch.update(doc.ref,
      {avatarUrl: newAvatarUrl}));

    const commentsSnapshot = await db.collectionGroup("yorumlar")
      .where("userId", "==", userId).get();
    commentsSnapshot.docs.forEach((doc) => batch.update(doc.ref,
      {userAvatar: newAvatarUrl}));

    if (postsSnapshot.empty && commentsSnapshot.empty) return null;
    return batch.commit();
  }
);

/**
 * =================================================================================
 * deletePost (HTTPS Callable) - V2
 * =================================================================================
 */
exports.deletePostV2 = onCall(
  {region: REGION},
  async (request) => {
    const data = request.data;
    const context = request;

    checkAuth(context);
    const postId = data.postId;
    const requesterUid = context.auth.uid;

    if (!postId) throw new HttpsError("invalid-argument", "Post ID eksik.");

    const postRef = db.collection("gonderiler").doc(postId);
    const postDoc = await postRef.get();

    if (!postDoc.exists) throw new HttpsError("not-found", "Gönderi bulunamadı.");

    const postData = postDoc.data();
    const authorId = postData.userId;
    const isAdmin = ADMIN_UIDS.includes(requesterUid);

    if (authorId !== requesterUid && !isAdmin) {
      throw new HttpsError("permission-denied", "Yetkisiz işlem.");
    }

    const batch = db.batch();
    const commentsSnapshot = await postRef.collection("yorumlar").get();
    commentsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

    const notifSnapshot = await db.collection("bildirimler")
      .where("postId", "==", postId).get();
    notifSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

    batch.delete(postRef);

    if (authorId) {
      const userRef = db.collection("kullanicilar").doc(authorId);
      batch.update(userRef, {
        postCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    await batch.commit();
    return {success: true};
  }
);

/**
 * =================================================================================
 * deleteUserAccount (HTTPS Callable) - V2
 * =================================================================================
 */
exports.deleteUserAccountV2 = onCall(
  {region: REGION},
  async (request) => {
    const data = request.data;
    const context = request;

    const targetUserId = data.userId || context.auth.uid;
    if (targetUserId !== context.auth.uid &&
        !ADMIN_UIDS.includes(context.auth.uid)) {
      throw new HttpsError("permission-denied", "Yetkiniz yok.");
    }

    const batch = db.batch();

    const postsQuery = await db.collection("gonderiler")
      .where("userId", "==", targetUserId).get();
    postsQuery.docs.forEach((doc) => batch.delete(doc.ref));

    const commentsQuery = await db.collectionGroup("yorumlar")
      .where("userId", "==", targetUserId).get();
    commentsQuery.docs.forEach((doc) => batch.delete(doc.ref));

    const userRef = db.collection("kullanicilar").doc(targetUserId);
    batch.delete(userRef);

    await batch.commit();

    try {
      const bucket = admin.storage().bucket();
      await bucket.file(`profil_resimleri/${targetUserId}.jpg`).delete();
    } catch (e) {
      // Storage silme hatasını görmezden geliyoruz
    }

    try {
      await admin.auth().deleteUser(targetUserId);
      return {success: true};
    } catch (error) {
      return {
        success: true,
        message: "Veriler silindi, Auth silinemedi.",
      };
    }
  }
);

/**
 * =================================================================================
 * onUserCreated (Firestore onCreate) - V2
 * =================================================================================
 */
exports.onUserCreatedV2 = onDocumentCreated(
  {
    document: "kullanicilar/{userId}",
    region: REGION,
  },
  (event) => {
    const snap = event.data;
    if (!snap) return null;

    return snap.ref.set({
      postCount: 0,
      commentCount: 0,
      likeCount: 0,
      followerCount: 0,
      followingCount: 0,
      earnedBadges: [],
      followers: [],
      following: [],
      savedPosts: [],
      isOnline: false,
      status: "Unverified",
      kayit_tarihi: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
);