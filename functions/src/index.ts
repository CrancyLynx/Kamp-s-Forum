// DİKKAT: Buradaki "/v1" ibaresi hatayı çözen kısımdır.
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * =================================================================================
 * 1. GÖNDERİ SİLME FONKSİYONU
 * =================================================================================
 */
export const deletePost = functions
  .region("europe-west1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    // 1. Yetkilendirme Kontrolü
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Bu işlemi yapmak için giriş yapmalısınız."
      );
    }
    
    const requesterUid = context.auth.uid;
    const postId = data.postId;

    // 2. Parametre Kontrolü
    if (!postId || typeof postId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "Geçerli bir 'postId' sağlanmadı."
      );
    }

    // 3. Gönderi ve Yetki Kontrolü
    const postRef = db.collection("gonderiler").doc(postId);
    const postDoc = await postRef.get();

    if (!postDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found", 
        "Silinecek gönderi bulunamadı."
      );
    }

    const postData = postDoc.data();
    const authorId = postData ? postData.userId : null;
    
    // Admin UID'nizi buraya string olarak ekleyin
    const admins = ["VD8MeJIhhRVtbT9iiUdMEaCe3MO2"];
    const isAdmin = admins.includes(requesterUid);

    if (requesterUid !== authorId && !isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied", 
        "Bu gönderiyi silme yetkiniz yok."
      );
    }

    // 4. Toplu Silme İşlemi
    const batch = db.batch();

    const commentsRef = postRef.collection("yorumlar");
    const notificationsRef = db.collection("bildirimler").where("postId", "==", postId);
    const reportsRef = db.collection("sikayetler").where("postId", "==", postId);

    const [comments, notifications, reports] = await Promise.all([
      commentsRef.get(),
      notificationsRef.get(),
      reportsRef.get(),
    ]);

    comments.docs.forEach((doc) => batch.delete(doc.ref));
    notifications.docs.forEach((doc) => batch.delete(doc.ref));
    reports.docs.forEach((doc) => batch.delete(doc.ref));

    batch.delete(postRef);

    if (authorId) {
      const userRef = db.collection("kullanicilar").doc(authorId);
      batch.update(userRef, {
        postCount: admin.firestore.FieldValue.increment(-1),
      });
    }

    await batch.commit();
    return { success: true, message: "Gönderi ve ilgili tüm veriler silindi." };
  });

/**
 * =================================================================================
 * 2. KULLANICI AVATARINI GÜNCELLEME FONKSİYONU
 * =================================================================================
 */
export const onUserAvatarUpdate = functions
  .region("europe-west1")
  .firestore.document("kullanicilar/{userId}")
  .onUpdate(async (change: functions.Change<functions.firestore.QueryDocumentSnapshot>, context: functions.EventContext) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    if (beforeData.avatarUrl === afterData.avatarUrl || !afterData.avatarUrl) {
      return null;
    }

    const newAvatarUrl = afterData.avatarUrl;
    const batch = db.batch();

    // A. Gönderiler
    const postsQuery = db.collection("gonderiler").where("userId", "==", userId);
    const postsSnapshot = await postsQuery.get();
    postsSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { avatarUrl: newAvatarUrl });
    });

    // B. Yorumlar
    const commentsQuery = db.collectionGroup("yorumlar").where("userId", "==", userId);
    const commentsSnapshot = await commentsQuery.get();
    commentsSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { userAvatar: newAvatarUrl });
    });
    
    if (postsSnapshot.empty && commentsSnapshot.empty) {
        return null;
    }

    return batch.commit();
  });

/**
 * =================================================================================
 * 3. KULLANICI HESABINI SİLME FONKSİYONU
 * =================================================================================
 */
export const deleteUserAccount = functions
  .region("europe-west1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", 
        "Bu işlemi yapmak için giriş yapmalısınız."
      );
    }

    const uid = context.auth.uid;
    const batch = db.batch();

    // 1. Verileri topla
    const postsQuery = db.collection("gonderiler").where("userId", "==", uid);
    const commentsQuery = db.collectionGroup("yorumlar").where("userId", "==", uid);
    const reportsQuery = db.collection("sikayetler").where("reporterId", "==", uid);

    const [posts, comments, reports] = await Promise.all([
      postsQuery.get(),
      commentsQuery.get(),
      reportsQuery.get(),
    ]);

    posts.docs.forEach((doc) => batch.delete(doc.ref));
    comments.docs.forEach((doc) => batch.delete(doc.ref));
    reports.docs.forEach((doc) => batch.delete(doc.ref));

    // 2. Takip edilenlerden çıkar
    const followersSnapshot = await db.collection("kullanicilar").where("following", "array-contains", uid).get();
    followersSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { 
        following: admin.firestore.FieldValue.arrayRemove(uid)
      });
    });

    // 3. Takipçilerden çıkar
    const followingSnapshot = await db.collection("kullanicilar").where("followers", "array-contains", uid).get();
    followingSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, { 
        followers: admin.firestore.FieldValue.arrayRemove(uid)
      });
    });

    // 4. Profil belgesini sil
    const userRef = db.collection("kullanicilar").doc(uid);
    batch.delete(userRef);

    await batch.commit();

    // 5. Auth sil
    try {
      await admin.auth().deleteUser(uid);
      return { success: true, message: "Hesabınız başarıyla silindi." };
    } catch (error) {
      console.error(`Auth kullanıcısı silinemedi (UID: ${uid}):`, error);
      return { success: true, message: "Veriler silindi ancak Auth kaydı silinemedi." };
    }
  });