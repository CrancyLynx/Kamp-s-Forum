import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hata Mesajlarını Türkçeleştirme
  String _handleError(Object e) {
    String msg = e.toString();
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password': return 'Hatalı şifre.';
        case 'email-already-in-use': return 'Bu e-posta zaten kullanımda.';
        case 'invalid-email': return 'Geçersiz e-posta formatı.';
        case 'network-request-failed': return 'İnternet bağlantınızı kontrol edin.';
        case 'credential-already-in-use': return 'Bu hesap bilgileri zaten kullanımda.';
        case 'permission-denied': return 'Erişim reddedildi. Yetkiniz yok.';
        case 'weak-password': return 'Şifre çok zayıf. En az 6 karakter olmalı.';
        default: return e.message ?? 'Bilinmeyen bir hata oluştu.';
      }
    }
    return msg;
  }

  // --- GİRİŞ YAPMA ---
  Future<String> signInWithEmail(String email, String password, bool rememberMe) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('saved_email', email);
      } else {
        await prefs.remove('saved_email');
      }

      // Giriş başarılı, 2FA (MFA) kontrolü
      try {
        final userDoc = await _firestore.collection('kullanicilar').doc(cred.user!.uid).get();
        if (userDoc.exists) {
           final isTwoFactorEnabled = userDoc.data()?['isTwoFactorEnabled'] ?? false;
           if (isTwoFactorEnabled) return "mfa_required";
        }
      } catch (_) {}

      return "success";
    } catch (e) {
      return _handleError(e);
    }
  }

  // --- KAYIT OLMA (DÜZELTİLMİŞ & GÜVENLİ VERSİYON) ---
  Future<String?> register({
    required String email,
    required String password,
    required String adSoyad,
    required String takmaAd,
    required String phone,
    required String university,
    required String department,
  }) async {
    User? createdUser;
    try {
      // 1. E-posta uzantısı kontrolü
      final lowerEmail = email.toLowerCase();
      if (!(lowerEmail.endsWith('.edu.tr') || lowerEmail.endsWith('.edu'))) {
        return "Sadece üniversite e-postası (.edu veya .edu.tr) ile kayıt olabilirsiniz.";
      }

      // 2. Takma Ad Kontrolü (Boş değilse)
      if (takmaAd.isNotEmpty) {
        final checkNick = await _firestore.collection('kullanicilar').where('takmaAd', isEqualTo: takmaAd).limit(1).get();
        if (checkNick.docs.isNotEmpty) {
          final random = Random();
          final suggestion1 = '$takmaAd${random.nextInt(100)}';
          final suggestion2 = '$takmaAd${100 + random.nextInt(900)}';
          final suggestion3 = '${takmaAd}_${random.nextInt(10)}';
          return "Bu takma ad alınmış. Şunları deneyebilirsin: $suggestion1, $suggestion2, $suggestion3";
        }
      }

      // 3. Kullanıcı Oluşturma (Firebase Auth)
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      createdUser = cred.user;

      if (createdUser != null) {
        // 4. Veritabanına Yazma (Firestore)
        // DİKKAT: Burada hata olsa bile, PushNotificationService ile çakışmayı önlemek için
        // hemen silmek yerine retry mantığı veya soft fail uygulayacağız.
        try {
          await _createUserDocument(createdUser, adSoyad, takmaAd, phone, email, university, department);
        } catch (dbError) {
          print("Veritabanı oluşturma hatası (Kritik değil): $dbError");
          // Not: Auth kullanıcısı oluştuğu için, veritabanı yazma hatası olsa bile
          // kullanıcıyı silmiyoruz. Uygulama içinde "Profil Tamamla" ekranı ile bu veri sonradan da eklenebilir.
          // Bu, "Giriş ekranına atma" sorununu çözer.
        }
      }
      return null; // Başarılı

    } catch (e) {
      // Sadece Auth oluşturulamazsa hata dönüyoruz.
      return "Kayıt başarısız: ${_handleError(e)}";
    }
  }

  // Kullanıcı Dokümanını Oluşturma
  Future<void> _createUserDocument(User user, String adSoyad, String takmaAd, String phone, String email, String uni, String dept) async {
    final adSoyadParts = adSoyad.trim().split(' ');
    final sadeceAd = adSoyadParts.isNotEmpty ? adSoyadParts.first : adSoyad;
    
    // SetOptions(merge: true) kullanımı veri kayıplarını önler.
    await _firestore.collection('kullanicilar').doc(user.uid).set({
      'email': email,
      'phoneNumber': phone,
      'takmaAd': takmaAd.isNotEmpty ? takmaAd : 'Kullanıcı',
      'ad': sadeceAd,
      'fullName': adSoyad,
      'universite': uni,
      'bolum': dept,
      'submissionData': {
        'university': uni,
        'department': dept,
        'name': sadeceAd,
        'surname': adSoyad.replaceFirst(sadeceAd, '').trim(),
      },
      'kayit_tarihi': FieldValue.serverTimestamp(),
      'verified': false,
      'status': 'Pending', // Onay bekliyor
      'role': 'user',
      'isTwoFactorEnabled': false,
      'followerCount': 0,
      'followingCount': 0,
      'postCount': 0,
      'likeCount': 0, 
      'commentCount': 0, 
      'earnedBadges': [],
      'followers': [],
      'following': [],
      'savedPosts': [],
      'blockedUsers': [], 
      'isOnline': true,
      'avatarUrl': '', 
      'totalUnreadMessages': 0,
      'unreadNotifications': 0,
    }, SetOptions(merge: true)); 
  }

  // --- DİĞER FONKSİYONLAR ---
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_email');
  }

  Future<String?> signInGuest() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } catch (e) { return _handleError(e); }
  }

  Future<void> signOut() async {
    final User? user = _auth.currentUser;
    // Misafir ise çıkışta hesabı sil
    if (user != null && user.isAnonymous) {
      try { await user.delete(); } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) => onError(_handleError(e)),
      codeSent: (id, token) => onCodeSent(id),
      codeAutoRetrievalTimeout: (id) {},
    );
  }
  
  Future<String?> validatePhonePassword(String phone, String password) async {
      try {
        final query = await _firestore.collection('kullanicilar').where('phoneNumber', isEqualTo: phone).limit(1).get();
        if (query.docs.isEmpty) return "Bu numara ile kayıtlı hesap bulunamadı.";
        final email = query.docs.first['email'];
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        return null;
      } catch (e) {
        return _handleError(e);
      }
  }
  
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) { return _handleError(e); }
  }

  Future<String?> toggleMFA(bool enable) async {
    final user = _auth.currentUser;
    if (user == null) return "Giriş yapmalısınız.";
    try {
      await _firestore.collection('kullanicilar').doc(user.uid).update({'isTwoFactorEnabled': enable});
      return null;
    } catch (e) { return _handleError(e); }
  }

  String publicHandleError(Object e) => _handleError(e);
  
  Future<bool> reauthenticateUser(String password) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) { return false; }
  }
}